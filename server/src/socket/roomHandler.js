/**
 * 방 관련 WebSocket 이벤트 핸들러
 */

const roomService = require('../services/roomService');
const userService = require('../services/userService');
const logger = require('../utils/logger');

/**
 * 방 관련 Socket 이벤트 처리
 */
const roomHandler = (socket, io) => {
  /**
   * join-room: 방 참여
   */
  socket.on('join-room', async (data) => {
    try {
      const { roomId } = data;
      const userId = socket.userId;

      if (!roomId) {
        return socket.emit('error', { message: 'roomId가 필요합니다' });
      }

      // NOTE: We NO LONGER call roomService.joinRoom() here.
      // The API /rooms/:roomId/join already handles DB operations (member insert, system message).
      // This socket handler ONLY joins the socket channel for real-time events.

      // Socket.io Room에 참여
      const roomName = `room:${roomId}`;
      socket.join(roomName);

      // 방 정보 조회
      const room = await roomService.findRoomByRoomId(roomId, true);

      // 본인에게 방 참여 확인 전송
      socket.emit('room-joined', {
        roomId,
        memberCount: room?.member_count || 0
      });

      // NOTE: We do NOT emit 'user-joined' here anymore since the API already emits it.
      // This prevents duplicate system messages.

      logger.info(`사용자 ${userId}가 WebSocket으로 방 ${roomId} 채널에 참여 (DB join handled by API)`);
    } catch (error) {
      logger.error('join-room 에러:', error);
      socket.emit('error', {
        message: error.message || '방 참여 중 오류가 발생했습니다'
      });
    }
  });

  /**
   * leave-room: 방 나가기 (소켓 채널만 나감, DB 유지)
   */
  socket.on('leave-room', async (data) => {
    try {
      const { roomId } = data;
      const userId = socket.userId;

      if (!roomId) {
        return socket.emit('error', { message: 'roomId가 필요합니다' });
      }

      // Socket.io Room에서 나가기
      const roomName = `room:${roomId}`;
      socket.leave(roomName);

      logger.info(`사용자 ${userId}가 WebSocket으로 방 ${roomId} 채널에서 나감`);
    } catch (error) {
      logger.error('leave-room 에러:', error);
    }
  });

  /**
   * exit-room: 방 완전히 나가기 (DB에서 제거)
   */
  socket.on('exit-room', async (data) => {
    try {
      const { roomId } = data;
      const userId = socket.userId;

      if (!roomId) {
        return socket.emit('error', { message: 'roomId가 필요합니다' });
      }

      // 방 나가기 처리 (DB)
      await roomService.leaveRoom(userId, roomId);

      // Socket.io Room에서 나가기
      const roomName = `room:${roomId}`;
      socket.leave(roomName);

      // 방 정보 조회
      const room = await roomService.findRoomByRoomId(roomId);

      // 본인에게 방 나가기 확인 전송
      socket.emit('room-left', { roomId });

      // 다른 사용자들에게 사용자 나감 알림
      socket.to(roomName).emit('user-left', {
        roomId,
        userId,
        memberCount: room ? room.member_count : 0
      });

      logger.info(`사용자 ${userId}가 방 ${roomId}에서 완전히 나감`);
    } catch (error) {
      logger.error('exit-room 에러:', error);
      socket.emit('error', {
        message: error.message || '방 나가기 중 오류가 발생했습니다'
      });
    }
  });

  /**
   * typing: 타이핑 인디케이터
   */
  socket.on('typing', async (data) => {
    try {
      const { roomId, isTyping } = data;
      const userId = socket.userId;

      if (!roomId) {
        return;
      }

      // 사용자 정보 조회
      const user = await userService.findUserById(userId);

      // 같은 방의 다른 사용자들에게 타이핑 상태 전송
      const roomName = `room:${roomId}`;
      socket.to(roomName).emit('typing-indicator', {
        roomId,
        userId,
        nicknameMask: user.nickname_mask,
        isTyping: isTyping !== false
      });
    } catch (error) {
      logger.error('typing 에러:', error);
    }
  });
};

module.exports = roomHandler;





