/**
 * YEO.PE 서버 진입점
 * Express + Socket.io 기반 실시간 채팅 서버
 */

require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const logger = require('./utils/logger');
const fs = require('fs');
const path = require('path');

// 데이터베이스 및 서비스 초기화
const { pool, query } = require('./config/database'); // PostgreSQL 연결

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: process.env.CORS_ORIGIN || '*',
    methods: ['GET', 'POST']
  }
});

// Socket.io instance sharing
app.set('io', io);

// [Migration] Run Blocked Users & Nickname Migrations on Startup
const runMigration = async () => {
  const migrations = [
    { name: 'Ensure Blocked Users', file: 'migration_ensure_blocked_users.sql' },
    { name: 'Block Nickname', file: 'migration_block_nickname.sql' },
    { name: 'Profile Image', file: 'migration_add_profile_image.sql' },
    { name: 'BLE UIDs', file: 'migration_add_ble_uids.sql' },
    { name: 'Push Tokens', file: 'migration_add_push_tokens.sql' },
    { name: 'Reports', file: 'migration_block_report.sql' },
    { name: 'Repair Reports', file: 'migration_repair_reports.sql' },
    { name: 'User Status', file: 'migration_add_user_status.sql' },
    { name: 'Login Logs', file: 'migration_add_login_logs.sql' },
    { name: 'Allow NULL Nickname', file: 'migration_allow_null_nickname.sql' },
    { name: 'Allow NULL Nickname Mask', file: 'migration_allow_null_nickname_mask.sql' },
    { name: 'Appeals', file: 'migration_add_appeals.sql' },
    { name: 'Suspension Reason', file: 'migration_add_suspension_reason.sql' },
    { name: 'System Settings', file: 'migration_add_system_settings.sql' },
    { name: 'Suspended At', file: 'migration_add_suspended_at.sql' },
    { name: 'Phone Number', file: 'migration_add_phone_number.sql' },
    { name: 'Archives', file: 'migration_add_archiving.sql' },
    { name: 'Inquiries', file: 'migration_add_inquiries.sql' } // Add inquiries table
  ];

  for (const m of migrations) {
    try {
      const sqlPath = path.join(__dirname, '../database', m.file);
      if (fs.existsSync(sqlPath)) {
        const sql = fs.readFileSync(sqlPath, 'utf8');
        await query(sql);
        logger.info(`✅ Migration (${m.name}) executed successfully.`);
      }
    } catch (error) {
      logger.warn(`⚠️ Migration (${m.name}) failed:`, error.message);
    }
  }
};

// 미들웨어
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request logging middleware
app.use(require('./middleware/requestLogger'));

// Admin Panel Static Files
app.use('/admin', express.static(path.join(__dirname, '../public/admin'), {
  setHeaders: (res, path) => {
    if (path.endsWith('index.html')) {
      res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
      res.setHeader('Pragma', 'no-cache');
      res.setHeader('Expires', '0');
    }
  }
}));

// Admin Panel Redirect
app.get('/admin', (req, res) => {
  res.redirect('/admin/');
});

// Admin Panel SPA fallback
app.get('/admin/*', (req, res) => {
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('Expires', '0');
  res.sendFile(path.join(__dirname, '../public/admin/index.html'));
});

// 정적 파일 서빙 (랜딩 페이지) - General Fallback
app.use(express.static(path.join(__dirname, '../public')));

// Rate Limiting
const { apiLimiter, adminLimiter } = require('./middleware/rateLimit');

// 1. Admin 라우트에 대해서는 관대한 제한 적용
app.use('/api/admin', adminLimiter);

// 2. 나머지 API에 대해서는 일반 제한 적용 (Admin 제외)
app.use('/api', (req, res, next) => {
  if (req.path.startsWith('/admin')) return next();
  apiLimiter(req, res, next);
});

// 기본 라우트
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: 'YEO.PE Server'
  });
});

// API 라우트
app.use('/api/auth', require('./routes/auth'));
app.use('/api/rooms', require('./routes/rooms'));
app.use('/api', require('./routes/messages'));
app.use('/api/push', require('./routes/push'));
app.use('/api/users', require('./routes/users'));
app.use('/api/upload', require('./routes/upload'));
app.use('/api/reports', require('./routes/reports'));
app.use('/api/admin', require('./routes/admin'));
app.use('/api/config', require('./routes/config'));
app.use('/api/inquiries', require('./routes/inquiries')); // Use inquiries routes

// Firebase & WebSocket
const pushService = require('./services/pushService');
pushService.initializeFirebase();

const socketHandler = require('./socket/socketHandler');
socketHandler(io);

// 에러 핸들링
app.use((err, req, res, next) => {
  if (err.isOperational) {
    logger.warn(`Operational Error: ${err.message}`, {
      statusCode: err.statusCode,
      path: req.path,
      method: req.method
    });
    return res.status(err.statusCode || 500).json({
      error: {
        message: err.message || 'Internal Server Error'
      }
    });
  }

  logger.error('Unexpected Error:', {
    error: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method
  });

  res.status(err.statusCode || 500).json({
    error: {
      message: process.env.NODE_ENV === 'production'
        ? 'Internal Server Error'
        : err.message,
      ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
    }
  });
});

// 404 핸들러
app.use('/api', (req, res) => {
  res.status(404).json({ error: 'Not Found' });
});

const PORT = process.env.PORT || 3000;

// [Sequential Startup]
const startServer = async () => {
  try {
    logger.info('🚀 Starting server setup...');

    // 1. Database & Migrations
    logger.info('📦 Running migrations...');
    await runMigration();
    logger.info('✅ Migrations complete.');

    // 2. Services
    require('./config/redis');
    const { startTTLScheduler } = require('./services/ttlService');
    const { startWorker } = require('./workers/pushWorker');

    startWorker();

    // 3. Bind Port
    server.listen(PORT, '0.0.0.0', () => {
      logger.info(`🚀 YEO.PE Server is running on port ${PORT}`);
      logger.info(`📝 Environment: ${process.env.NODE_ENV || 'development'}`);

      startTTLScheduler();
    });
  } catch (error) {
    logger.error('❌ Server failed to start:', error);
    process.exit(1);
  }
};

startServer();

// Graceful shutdown
const gracefulShutdown = async () => {
  logger.info('Shutdown signal received: closing server...');

  server.close(() => {
    logger.info('HTTP server closed');

    const { pool } = require('./config/database');
    pool.end(() => {
      logger.info('PostgreSQL connection pool closed');

      const redis = require('./config/redis');
      redis.quit(() => {
        logger.info('Redis connection closed');
        process.exit(0);
      });
    });
  });
};

process.on('SIGTERM', gracefulShutdown);
process.on('SIGINT', gracefulShutdown);

module.exports = { app, server, io };
