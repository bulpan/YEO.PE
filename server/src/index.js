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

// 데이터베이스 및 서비스 초기화
require('./config/database'); // PostgreSQL 연결
require('./config/redis'); // Redis 연결
const { startTTLScheduler } = require('./services/ttlService');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: process.env.CORS_ORIGIN || '*',
    methods: ['GET', 'POST']
  }
});

// 미들웨어
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Socket.io instance sharing
app.set('io', io);

// Request logging middleware
// Request logging middleware
app.use(require('./middleware/requestLogger'));

// 정적 파일 서빙 (랜딩 페이지)
app.use(express.static('public'));

// 전역 Rate Limiting
const { apiLimiter } = require('./middleware/rateLimit');
app.use('/api', apiLimiter);

// 기본 라우트
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: 'YEO.PE Server'
  });
});

// 랜딩 페이지는 정적 파일로 서빙 (public/index.html)

// API 라우트
app.use('/api/auth', require('./routes/auth'));
app.use('/api/rooms', require('./routes/rooms'));
app.use('/api', require('./routes/messages'));
app.use('/api/push', require('./routes/push'));
app.use('/api/users', require('./routes/users'));
app.use('/api/upload', require('./routes/upload'));

// Firebase 초기화 (푸시 알림)
const pushService = require('./services/pushService');
pushService.initializeFirebase();

// WebSocket 연결
const socketHandler = require('./socket/socketHandler');
socketHandler(io);

// 에러 핸들링
app.use((err, req, res, next) => {
  // 커스텀 에러인 경우
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

  // 예상치 못한 에러
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

// 404 핸들러 (API 요청만 JSON 응답)
app.use('/api', (req, res) => {
  res.status(404).json({ error: 'Not Found' });
});

const PORT = process.env.PORT || 3000;

server.listen(PORT, '0.0.0.0', () => {
  logger.info(`🚀 YEO.PE Server is running on port ${PORT}`);
  logger.info(`📝 Environment: ${process.env.NODE_ENV || 'development'}`);

  // TTL 정리 스케줄러 시작
  startTTLScheduler();
});

// Graceful shutdown
const gracefulShutdown = async () => {
  logger.info('Shutdown signal received: closing server...');

  server.close(() => {
    logger.info('HTTP server closed');

    // 데이터베이스 연결 종료
    const { pool } = require('./config/database');
    pool.end(() => {
      logger.info('PostgreSQL connection pool closed');

      // Redis 연결 종료
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

