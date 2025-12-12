/**
 * WebSocket 연결 핸들러
 */

const { verifyToken } = require('../config/auth');
const { AuthenticationError } = require('../utils/errors');
const logger = require('../utils/logger');
const sanitize = require('../utils/sanitizer');
const roomHandler = require('./roomHandler');
const messageHandler = require('./messageHandler');
const roomService = require('../services/roomService');

/**
 * Socket.io 연결 처리
 */
const handleConnection = (io) => {
  io.use(async (socket, next) => {
    try {
      // 토큰 추출: auth 객체 또는 query 파라미터에서
      const token = socket.handshake.auth?.token || socket.handshake.query?.token;

      if (!token) {
        return next(new AuthenticationError('인증 토큰이 필요합니다'));
      }

      // 토큰 검증
      const decoded = verifyToken(token);

      // 소켓에 사용자 정보 저장
      socket.userId = decoded.userId;
      socket.userEmail = decoded.email;

      // 사용자 개인 룸 조인 (개별 알림용)
      socket.join(`user:${decoded.userId}`);

      // [Auto-Join] 사용자가 참여 중인 모든 방에 자동으로 소켓 연결
      // 이를 통해 MainView에서도 'new-message' 이벤트를 수신할 수 있음
      try {
        const userRooms = await roomService.getUserRooms(decoded.userId);
        userRooms.forEach(room => {
          if (room.roomId) {
            socket.join(`room:${room.roomId}`);
          }
        });
        logger.info(`WebSocket Auto-Join: user ${decoded.userId} joined ${userRooms.length} rooms`);
      } catch (err) {
        logger.error(`WebSocket Auto-Join Failed for ${decoded.userId}:`, err);
        // 치명적이지 않으므로 연결은 허용
      }

      logger.info(`WebSocket 연결: user ${decoded.userId}`);
      next();
    } catch (error) {
      logger.error('WebSocket 인증 실패:', error);
      next(new AuthenticationError('유효하지 않은 토큰입니다'));
    }
  });

  io.on('connection', (socket) => {
    logger.info(`사용자 연결: ${socket.userId} (socket: ${socket.id})`);

    // [Socket] 로깅: 들어오는 이벤트
    socket.onAny((event, ...args) => {
      // 핑퐁 등 빈번한 이벤트는 제외 가능 (현재는 모두 기록)
      logger.info(`[Socket In] ${event}`, {
        user: socket.userId,
        socketId: socket.id,
        args: sanitize(args)
      });
    });

    // [Socket] 로깅: 나가는 이벤트 (Socket.io v3+)
    if (socket.onAnyOutgoing) {
      socket.onAnyOutgoing((event, ...args) => {
        logger.info(`[Socket Out] ${event}`, {
          user: socket.userId,
          socketId: socket.id,
          args: sanitize(args)
        });
      });
    }

    // 방 관련 이벤트 핸들러
    roomHandler(socket, io);

    // 메시지 관련 이벤트 핸들러
    messageHandler(socket, io);

    // Typing Handler logic (simple enough to keep here or move)
    socket.on('typing_start', ({ roomId }) => {
      if (!roomId) return;
      socket.to(`room:${roomId}`).emit('typing_update', {
        roomId: roomId,
        userId: socket.userId,
        isTyping: true
      });
    });

    socket.on('typing_end', ({ roomId }) => {
      if (!roomId) return;
      socket.to(`room:${roomId}`).emit('typing_update', {
        roomId: roomId,
        userId: socket.userId,
        isTyping: false
      });
    });

    // 연결 해제 처리
    socket.on('disconnect', (reason) => {
      logger.info(`사용자 연결 해제: ${socket.userId} (reason: ${reason})`);
    });

    // 에러 처리
    socket.on('error', (error) => {
      logger.error(`Socket 에러 (user: ${socket.userId}):`, error);
    });
  });
};

module.exports = handleConnection;

