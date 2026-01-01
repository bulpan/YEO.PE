/**
 * 메시지 관련 WebSocket 이벤트 핸들러
 */

const messageService = require('../services/messageService');
const pushService = require('../services/pushService');
const logger = require('../utils/logger');

/**
 * 메시지 관련 Socket 이벤트 처리
 */
const messageHandler = (socket, io) => {
  /**
   * send-message: 메시지 전송
   */
  socket.on('send-message', async (data) => {
    try {
      const { roomId, type, content, imageUrl } = data;
      const userId = socket.userId;

      if (!roomId) {
        return socket.emit('error', { message: 'roomId가 필요합니다' });
      }

      // 메시지 생성
      const message = await messageService.createMessage(
        userId,
        roomId,
        type,
        content,
        imageUrl
      );

      // 같은 방의 모든 사용자에게 메시지 전송
      const roomName = `room:${roomId}`;
      io.to(roomName).emit('new-message', {
        messageId: message.messageId,
        roomId,
        userId: message.userId,
        nicknameMask: message.nicknameMask,
        type: message.type,
        content: message.content,
        imageUrl: message.imageUrl,
        createdAt: message.createdAt
      });

      // [Dual Emission for 1:1 Chats]
      // If this is a 1:1 room (has inviteeId), also emit to the invitee's PERSONAL channel.
      // This ensures they receive the message even if they haven't "joined" the room socket channel yet.
      if (message.roomMetadata && message.roomMetadata.inviteeId) {
        const inviteeId = message.roomMetadata.inviteeId;
        // Don't echo back to sender if they are the invitee (edge case, usually creator sends first)
        if (inviteeId !== userId) {
          logger.info(`[Socket 1:1] Dual emitting to user:${inviteeId}`);
          io.to(`user:${inviteeId}`).emit('new-message', {
            messageId: message.messageId,
            roomId,
            userId: message.userId,
            nicknameMask: message.nicknameMask,
            type: message.type,
            content: message.content,
            imageUrl: message.imageUrl,
            createdAt: message.createdAt
          });
        }
      }

      // 푸시 알림 전송 (백그라운드에서 비동기 처리)
      // WebSocket에 연결되지 않은 사용자에게만 전송
      logger.info(`[PushTrace] Calling sendMessageNotification for room ${roomId}`);
      pushService.sendMessageNotification(
        roomId,
        userId,
        message.nicknameMask,
        message.content,
        message.type,
        io // Socket.io 인스턴스 전달 (연결 상태 확인용)
      ).then(result => {
        logger.info(`[PushTrace] sendMessageNotification completed: ${JSON.stringify(result)}`);
      }).catch(err => {
        logger.error('[PushSummary] 푸시 알림 전송 실패 (Handler):', err);
      });

      logger.info(`메시지 전송 (WebSocket): ${message.messageId} in room ${roomId}`);
    } catch (error) {
      logger.error('send-message 에러:', error);
      socket.emit('error', {
        message: error.message || '메시지 전송 중 오류가 발생했습니다'
      });
    }
  });
};

module.exports = messageHandler;



