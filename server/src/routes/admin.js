const express = require('express');
const router = express.Router();
const { authenticateAdmin } = require('../middleware/adminAuth');
const { generateAdminToken } = require('../config/auth');
const { AuthenticationError } = require('../utils/errors');
const { pool } = require('../config/database');
const userService = require('../services/userService');
const inquiryService = require('../services/inquiryService'); // Import inquiryService
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

        // 5. Suspended Users Count
        const suspendedCountQuery = await pool.query("SELECT COUNT(*) FROM yeope_schema.users WHERE status = 'suspended'");
        const suspendedUsers = parseInt(suspendedCountQuery.rows[0].count);

        res.json({
            activeUsers,
            totalRooms,
            totalUsers,
            messages24h,
            suspendedUsers
        });
    } catch (error) {
        next(error);
    }
});

/**
 * Traffic Stats (User Connections)
 * GET /api/admin/stats/traffic
 * query: period (day/week/month/3months), os (all/ios/android)
 */
router.get('/stats/traffic', async (req, res, next) => {
    try {
        const { period = 'week', os = 'all' } = req.query;
        let interval = '7 days';

        if (period === 'day') interval = '24 hours';
        else if (period === 'month') interval = '30 days';
        else if (period === '3months') interval = '90 days';

        let osFilter = '';
        const params = [];
        if (os !== 'all') {
            osFilter = 'AND platform = $1';
            params.push(os);
        }

        const query = `
            SELECT 
                TO_CHAR(login_at, 'YYYY-MM-DD') as date,
                COUNT(DISTINCT user_id) as count
            FROM yeope_schema.login_logs
            WHERE login_at > NOW() - INTERVAL '${interval}'
            ${osFilter}
            GROUP BY date
            ORDER BY date ASC
        `;

        const result = await pool.query(query, params);
        res.json({ period, os, data: result.rows });
    } catch (error) {
        next(error);
    }
});

/**
 * New Users Stats (App Installs Proxy)
 * GET /api/admin/stats/users
 * query: period (day/week/month/3months)
 */
router.get('/stats/users', async (req, res, next) => {
    try {
        const { period = 'week' } = req.query;
        let interval = '7 days';

        if (period === 'day') interval = '24 hours';
        else if (period === 'month') interval = '30 days';
        else if (period === '3months') interval = '90 days';

        const query = `
            SELECT 
                TO_CHAR(created_at, 'YYYY-MM-DD') as date,
                COUNT(id) as count
            FROM yeope_schema.users
            WHERE created_at > NOW() - INTERVAL '${interval}'
            GROUP BY date
            ORDER BY date ASC
        `;

        const result = await pool.query(query);
        res.json({ period, data: result.rows });
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
 * Ban User (Deactivate)
 * POST /api/admin/users/:id/ban
 */
router.post('/users/:id/ban', async (req, res, next) => {
    try {
        const { id } = req.params;
        const { reason } = req.body;
        await userService.banUser(id, reason);
        res.json({ success: true, message: 'User banned' });
    } catch (error) {
        next(error);
    }
});

/**
 * Unban User (Activate)
 * POST /api/admin/users/:id/unblock
 */
router.post('/users/:id/unblock', async (req, res, next) => {
    try {
        const { id } = req.params;
        await userService.unbanUser(id);
        res.json({ success: true, message: 'User unbanned' });
    } catch (error) {
        next(error);
    }
});

/**
 * Suspend User (Temporary)
 * POST /api/admin/users/:id/suspend
 */
router.post('/users/:id/suspend', async (req, res, next) => {
    try {
        const { id } = req.params;
        const { hours, reason } = req.body;
        await userService.suspendUser(id, hours || 24, reason);
        res.json({ success: true, message: `User suspended for ${hours}h` });
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

        // Robust discovery: Find the most recently modified combined log file
        let logFiles = [];
        try {
            if (fs.existsSync(logDir)) {
                logFiles = fs.readdirSync(logDir)
                    .filter(f => f.startsWith('combined') && f.endsWith('.log'))
                    .map(f => ({
                        name: f,
                        path: path.join(logDir, f),
                        mtime: fs.statSync(path.join(logDir, f)).mtime
                    }))
                    .sort((a, b) => b.mtime - a.mtime);
            }
        } catch (e) {
            console.error('[AdminLogs] Error reading log directory:', e);
        }

        let logFile = logFiles.length > 0 ? logFiles[0].path : path.join(logDir, 'combined.log');

        if (!fs.existsSync(logFile)) {
            return res.json({ logs: [] });
        }

        // Read last 200KB to ensure we catch recent events
        const stats = fs.statSync(logFile);
        const size = stats.size;
        const start = Math.max(0, size - 200000); // Last 200KB (increased from 20KB)

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
            const search = filter;

            if (filter) {
                if (filter === 'PushSummary') {
                    // Match 'Push', 'FCM', or 'Worker' for push-related logs
                    const filtered = parsedLogs.filter(logStr =>
                        /Push|FCM|Worker/i.test(logStr)
                    );
                    res.json({ logs: filtered });
                } else {
                    const filtered = parsedLogs.filter(logStr => logStr.toLowerCase().includes(search.toLowerCase()));
                    res.json({ logs: filtered });
                }
            } else {
                res.json({ logs: parsedLogs });
            }
        });
    } catch (error) {
        next(error);
    }
});

/**
 * Blocked Users List
 * GET /api/admin/blocks
 */
router.get('/blocks', async (req, res, next) => {
    try {
        const result = await pool.query(`
      SELECT 
        b.blocker_id, b.blocked_id, b.created_at,
        u1.nickname as blocker_nickname, u1.email as blocker_email, u1.nickname_mask as blocker_mask,
        u2.nickname as blocked_nickname, u2.email as blocked_email, u2.nickname_mask as blocked_mask
      FROM yeope_schema.blocked_users b
      LEFT JOIN yeope_schema.users u1 ON b.blocker_id = u1.id
      LEFT JOIN yeope_schema.users u2 ON b.blocked_id = u2.id
      ORDER BY b.created_at DESC
      LIMIT 100
    `);
        res.json(result.rows);
    } catch (error) {
        next(error);
    }
});

/**
 * Unblock User (Admin Override)
 * POST /api/admin/blocks/unblock
 */
router.post('/blocks/unblock', async (req, res, next) => {
    try {
        const { blockerId, blockedId } = req.body;

        if (!blockerId || !blockedId) {
            throw new AuthenticationError('Blocker ID and Blocked ID are required');
        }

        await pool.query(
            'DELETE FROM yeope_schema.blocked_users WHERE blocker_id = $1 AND blocked_id = $2',
            [blockerId, blockedId]
        );

        res.json({ success: true, message: 'User unblocked successfully' });
    } catch (error) {
        next(error);
    }
});

router.post('/users/:id/unsuspend', async (req, res, next) => {
    try {
        const { id } = req.params;
        await userService.unsuspendUser(id);
        res.json({ success: true, message: 'User unsuspended successfully' });
    } catch (error) {
        next(error);
    }
});



router.delete('/users/:id/reports', async (req, res, next) => {
    try {
        const { id } = req.params;
        await userService.clearReports(id);
        res.json({ success: true, message: 'User reports cleared successfully' });
    } catch (error) {
        next(error);
    }
});

/**
 * GET /api/admin/appeals
 * 구제 신청 목록 조회
 */
router.get('/appeals', async (req, res, next) => {
    try {
        const { status } = req.query;
        const appeals = await userService.getAppeals(status || 'pending');
        res.json(appeals);
    } catch (error) {
        next(error);
    }
});

/**
 * POST /api/admin/appeals/:id/resolve
 * 구제 신청 처리 (승인/거절)
 */
router.post('/appeals/:id/resolve', async (req, res, next) => {
    try {
        const { id } = req.params;
        const { status, adminComment } = req.body;

        await userService.resolveAppeal(id, status, adminComment);
        res.json({ success: true, message: `Appeal ${status}` });
    } catch (error) {
        next(error);
    }
});

/**
 * Global Settings (Get)
 * GET /api/admin/settings
 */
router.get('/settings', async (req, res, next) => {
    try {
        const settingsService = require('../services/settingsService');
        const settings = await settingsService.getAll();
        res.json(settings);
    } catch (error) {
        next(error);
    }
});

/**
 * Global Settings (Update)
 * POST /api/admin/settings
 */
router.post('/settings', async (req, res, next) => {
    try {
        const settingsService = require('../services/settingsService');
        const updates = req.body; // { key: value, ... }

        for (const [key, value] of Object.entries(updates)) {
            await settingsService.setValue(key, value);
        }

        res.json({ success: true, message: 'Settings updated' });
    } catch (error) {
        next(error);
    }
});

/**
 * Archived Messages Search
 * GET /api/admin/archives/messages
 */
router.get('/archives/messages', async (req, res, next) => {
    try {
        const { userId, keyword, limit = 50 } = req.query;

        let queryText = `
            SELECT 
                am.*, 
                ar.name as room_name,
                u.nickname as user_nickname,
                u.email as user_email
            FROM yeope_schema.archived_messages am
            LEFT JOIN yeope_schema.archived_rooms ar ON am.room_id = ar.id
            LEFT JOIN yeope_schema.users u ON am.user_id = u.id
            WHERE 1=1
        `;

        const params = [];
        let paramIndex = 1;

        if (userId) {
            queryText += ` AND am.user_id = $${paramIndex}`;
            params.push(userId);
            paramIndex++;
        }

        if (keyword) {
            // Simple content search
            queryText += ` AND am.content ILIKE $${paramIndex}`;
            params.push(`%${keyword}%`);
            paramIndex++;
        }

        queryText += ` ORDER BY am.created_at DESC LIMIT $${paramIndex}`;
        params.push(limit);

        const result = await pool.query(queryText, params);
        res.json(result.rows);
    } catch (error) {
        next(error);
    }
});

/**
 * System Status
 * GET /api/admin/system-status
 */
router.get('/system-status', async (req, res, next) => {
    try {
        const os = require('os');
        const { exec } = require('child_process');

        // 1. Process Memory
        const memoryUsage = process.memoryUsage();

        // 2. System Info
        const uptime = os.uptime();
        const loadAvg = os.loadavg();
        const freeMem = os.freemem();
        const totalMem = os.totalmem();

        // 3. Disk Usage (Async)
        exec('df -h /', (error, stdout, stderr) => {
            let diskInfo = 'N/A';
            if (!error) {
                // Parse stdout to find relevant line
                // Filesystem      Size  Used Avail Use% Mounted on
                // overlay         ...   ...  ...   ...  /
                const lines = stdout.trim().split('\n');
                if (lines.length >= 2) {
                    diskInfo = lines[1];
                }
            }

            res.json({
                process: {
                    rss: memoryUsage.rss,
                    heapTotal: memoryUsage.heapTotal,
                    heapUsed: memoryUsage.heapUsed,
                },
                system: {
                    uptime,
                    loadAvg,
                    freeMem,
                    totalMem,
                    platform: os.platform(),
                    arch: os.arch(),
                    cpus: os.cpus().length
                },
                disk: diskInfo
            });
        });

    } catch (error) {
        next(error);
    }
});

// Admin: Get Inquiries
router.get('/inquiries', authenticateAdmin, async (req, res) => {
    try {
        const { status = 'all', page = 1, limit = 50 } = req.query;
        const offset = (page - 1) * limit;

        const result = await inquiryService.getAllInquiries(status, limit, offset);

        res.json({
            inquiries: result.inquiries,
            pagination: {
                total: result.total,
                page: parseInt(page),
                pages: Math.ceil(result.total / limit)
            }
        });
    } catch (error) {
        console.error('Error fetching inquiries:', error);
        res.status(500).json({ error: 'Failed to fetch inquiries' });
    }
});

// Admin: Answer Inquiry
router.post('/inquiries/:id/answer', authenticateAdmin, async (req, res) => {
    try {
        const { answer } = req.body;
        if (!answer) {
            return res.status(400).json({ error: 'Answer content is required' });
        }

        const updatedInquiry = await inquiryService.answerInquiry(req.params.id, answer);
        if (!updatedInquiry) {
            return res.status(404).json({ error: 'Inquiry not found' });
        }

        res.json(updatedInquiry);
    } catch (error) {
        console.error('Error answering inquiry:', error);
        res.status(500).json({ error: 'Failed to answer inquiry' });
    }
});

module.exports = router;
