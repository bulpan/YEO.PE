const express = require('express');
const router = express.Router();
const { authenticateAdmin } = require('../middleware/adminAuth');
const { generateAdminToken } = require('../config/auth');
const { AuthenticationError } = require('../utils/errors');
const { pool } = require('../config/database');
const fs = require('fs');
const path = require('path');

// --- Auth ---

/**
 * Admin Login
 * POST /api/admin/login
 */
router.post('/login', (req, res, next) => {
    try {
        const { password } = req.body;
        const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin1234';

        if (password !== ADMIN_PASSWORD) {
            throw new AuthenticationError('비밀번호가 일치하지 않습니다.');
        }

        const token = generateAdminToken();
        res.json({ token });
    } catch (error) {
        next(error);
    }
});

// --- Protected Routes ---
router.use(authenticateAdmin);

/**
 * Dashboard Stats
 * GET /api/admin/stats
 */
router.get('/stats', async (req, res, next) => {
    try {
        const io = req.app.get('io');

        // 1. Active Users (Socket)
        const activeUsers = io.engine.clientsCount;

        // 2. Room Counts (DB)
        const roomCountQuery = await pool.query('SELECT COUNT(*) FROM yeope_schema.rooms');
        const totalRooms = parseInt(roomCountQuery.rows[0].count);

        // 3. User Counts (DB)
        const userCountQuery = await pool.query('SELECT COUNT(*) FROM yeope_schema.users');
        const totalUsers = parseInt(userCountQuery.rows[0].count);

        // 4. Message Counts (Last 24h)
        const messageCountQuery = await pool.query(`
      SELECT COUNT(*) FROM yeope_schema.messages 
      WHERE created_at > NOW() - INTERVAL '24 hours'
    `);
        const messages24h = parseInt(messageCountQuery.rows[0].count);

        res.json({
            activeUsers,
            totalRooms,
            totalUsers,
            messages24h
        });
    } catch (error) {
        next(error);
    }
});

/**
 * Room List
 * GET /api/admin/rooms
 */
router.get('/rooms', async (req, res, next) => {
    try {
        const result = await pool.query(`
      SELECT 
        r.id, r.room_id, r.name, r.member_count, r.created_at, r.expires_at,
        u.nickname as creator_nickname
      FROM yeope_schema.rooms r
      LEFT JOIN yeope_schema.users u ON r.creator_id = u.id
      ORDER BY r.created_at DESC
      LIMIT 100
    `);
        res.json(result.rows);
    } catch (error) {
        next(error);
    }
});

/**
 * Room Detail
 * GET /api/admin/rooms/:id
 */
router.get('/rooms/:id', async (req, res, next) => {
    try {
        const { id } = req.params;

        // Check if input is a valid UUID
        const isUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id);

        let queryText = `
      SELECT r.*, u.nickname as creator_nickname
      FROM yeope_schema.rooms r
      LEFT JOIN yeope_schema.users u ON r.creator_id = u.id
      WHERE r.room_id = $1::text
    `;

        if (isUUID) {
            queryText += ` OR r.id = $1::uuid`;
        }

        const roomQuery = await pool.query(queryText, [id]);

        if (roomQuery.rows.length === 0) {
            return res.status(404).json({ error: 'Room not found' });
        }

        const room = roomQuery.rows[0];

        // Messages (Last 50)
        const messagesQuery = await pool.query(`
      SELECT m.*, u.nickname
      FROM yeope_schema.messages m
      LEFT JOIN yeope_schema.users u ON m.user_id = u.id
      WHERE m.room_id = $1
      ORDER BY m.created_at DESC
      LIMIT 50
    `, [room.id]);

        res.json({
            room,
            messages: messagesQuery.rows
        });
    } catch (error) {
        next(error);
    }
});

/**
 * Delete Room
 * DELETE /api/admin/rooms/:id
 */
router.delete('/rooms/:id', async (req, res, next) => {
    try {
        const { id } = req.params;
        const isUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id);

        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            let roomUuid;

            if (isUUID) {
                // Check by UUID (id column)
                const roomRes = await client.query('SELECT id FROM yeope_schema.rooms WHERE id = $1', [id]);
                if (roomRes.rows.length > 0) {
                    roomUuid = roomRes.rows[0].id;
                } else {
                    // Fallback: Check by room_id (varchar) even if input looks like UUID
                    // Explicitly cast strict text to avoid ambiguity
                    const roomRes2 = await client.query('SELECT id FROM yeope_schema.rooms WHERE room_id = $1::text', [id]);
                    if (roomRes2.rows.length > 0) {
                        roomUuid = roomRes2.rows[0].id;
                    } else {
                        await client.query('ROLLBACK');
                        return res.status(404).json({ error: 'Room not found' });
                    }
                }
            } else {
                // Not a UUID, must be a room_id string (legacy support if any non-UUID room_ids exist, which shouldn't happen but safe to check)
                const roomRes = await client.query('SELECT id FROM yeope_schema.rooms WHERE room_id = $1', [id]);
                if (roomRes.rows.length === 0) {
                    await client.query('ROLLBACK');
                    return res.status(404).json({ error: 'Room not found' });
                }
                roomUuid = roomRes.rows[0].id;
            }

            console.log(`[Admin] Deleting Room UUID: ${roomUuid}`);

            // 1. Delete Dependencies (Manual Cascade)
            await client.query('DELETE FROM yeope_schema.messages WHERE room_id = $1', [roomUuid]);
            await client.query('DELETE FROM yeope_schema.room_members WHERE room_id = $1', [roomUuid]);

            // 2. Delete Room
            await client.query('DELETE FROM yeope_schema.rooms WHERE id = $1', [roomUuid]);

            await client.query('COMMIT');

            // 3. Force disconnect socket room
            const io = req.app.get('io');
            io.to(roomUuid).emit('room_deleted', { message: 'Admin deleted this room' });

            res.json({ success: true, deletedId: roomUuid });
        } catch (err) {
            await client.query('ROLLBACK');
            console.error('[Admin] Room Delete Error:', err);
            throw err;
        } finally {
            client.release();
        }
    } catch (error) {
        next(error);
    }
});

/**
 * Report List
 * GET /api/admin/reports
 */
router.get('/reports', async (req, res, next) => {
    try {
        const result = await pool.query(`
      SELECT r.*, u.nickname as reporter_nickname, t.nickname as reported_nickname
      FROM yeope_schema.reports r
      LEFT JOIN yeope_schema.users u ON r.reporter_id = u.id
      LEFT JOIN yeope_schema.users t ON r.reported_id = t.id
      ORDER BY r.created_at DESC
      LIMIT 100
    `);
        res.json(result.rows);
    } catch (error) {
        next(error);
    }
});

/**
 * Ban User
 * POST /api/admin/users/:id/ban
 */
router.post('/users/:id/ban', async (req, res, next) => {
    try {
        const { id } = req.params;
        await pool.query('UPDATE yeope_schema.users SET is_active = false WHERE id = $1', [id]);
        res.json({ success: true, message: 'User banned' });
    } catch (error) {
        next(error);
    }
});

/**
 * Unban User
 * POST /api/admin/users/:id/unblock
 */
router.post('/users/:id/unblock', async (req, res, next) => {
    try {
        const { id } = req.params;
        await pool.query('UPDATE yeope_schema.users SET is_active = true WHERE id = $1', [id]);
        res.json({ success: true, message: 'User unbanned' });
    } catch (error) {
        next(error);
    }
});

/**
 * User List
 * GET /api/admin/users
 */
router.get('/users', async (req, res, next) => {
    try {
        const result = await pool.query(`
      SELECT id, email, nickname, nickname_mask, created_at, last_login_at, is_active
      FROM yeope_schema.users
      ORDER BY created_at DESC
      LIMIT 50
    `);
        res.json(result.rows);
    } catch (error) {
        next(error);
    }
});

/**
 * Server Logs (Tail)
 * GET /api/admin/logs
 */
router.get('/logs', (req, res, next) => {
    try {
        // Assuming logs are in logs/combined.log or similar from Winston
        // Adjust path based on where logger saves files
        const logDir = path.join(__dirname, '../../logs');
        const logFile = path.join(logDir, 'combined.log'); // or error.log

        console.log(`[Debug] Log Path Check: ${logFile}, Exists: ${fs.existsSync(logFile)}`);


        if (!fs.existsSync(logFile)) {
            return res.json({ logs: [] });
        }

        // Read last 10KB or so
        const stats = fs.statSync(logFile);
        const size = stats.size;
        const start = Math.max(0, size - 20000); // Last 20KB

        const stream = fs.createReadStream(logFile, { start, encoding: 'utf8' });
        let data = '';
        stream.on('data', chunk => data += chunk);
        stream.on('end', () => {
            const rawLines = data.split('\n').filter(Boolean).reverse();

            // Parse lines as JSON but return string for frontend compatibility
            const parsedLogs = rawLines.map(line => {
                try {
                    const obj = JSON.parse(line);
                    const msg = typeof obj.message === 'object' ? JSON.stringify(obj.message) : obj.message;
                    return `${obj.timestamp} [${obj.level}]: ${msg}`;
                } catch (e) {
                    return line;
                }
            });

            // Optional: Filter by query
            const filter = req.query.filter;
            if (filter) {
                // SPECIAL HANDLING: If frontend asks for 'PushSummary', search for 'Push' to include all worker logs
                let search = filter;
                if (filter === 'PushSummary') {
                    search = 'Push';
                }
                const filtered = parsedLogs.filter(logStr => logStr.includes(search));
                res.json({ logs: filtered });
            } else {
                res.json({ logs: parsedLogs });
            }
        });
    } catch (error) {
        next(error);
    }
});

module.exports = router;
