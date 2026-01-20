/**
 * 푸시 알림 서비스 (Producer/Facade)
 * - 실제 발송 로직은 제거되고, Redis Queue에 작업을 등록하는 역할만 수행함.
 * - API 서버의 응답 속도 향상 목적.
 */

const Queue = require('bull');
const logger = require('../utils/logger');
const { PushType } = require('../constants/pushTypes');

// 1. Bull Queue 초기화
// Redis Connection Info from Env
const redisConfig = {
  host: process.env.REDIS_HOST || 'yeope-redis',
  port: process.env.REDIS_PORT || 6379,
  password: process.env.REDIS_PASSWORD || undefined
};

const pushQueue = new Queue('push-queue', {
  redis: redisConfig,
  defaultJobOptions: {
    attempts: 3, // 실패 시 3회 재시도
    backoff: {
      type: 'exponential',
      delay: 1000 // 1초, 2초, 4초...
    },
    removeOnComplete: 100, // 완료된 작업 100개 유지
    removeOnFail: 100      // 실패한 작업 100개 유지
  }
});

logger.info('[PushService] Queue Initialized');

// 2. Queue Wrapper Functions

const sendMessageNotification = async (roomId, senderUserId, senderNicknameMask, messageContent, messageType = 'text', io = null, messageId = null) => {
  try {
    // [Policy] Suppress Push if User is Online in Room
    let excludeUserIds = [];
    if (io && io.sockets && io.sockets.adapter) {
      try {
        const roomName = `room:${roomId}`;
        const roomSockets = io.sockets.adapter.rooms.get(roomName);
        if (roomSockets) {
          for (const socketId of roomSockets) {
            const socket = io.sockets.sockets?.get(socketId);
            if (socket?.userId) {
              excludeUserIds.push(socket.userId);
            }
          }
          // Use Debug level only to reduce noise unless checking
          // logger.debug(`[PushService] Online users in room ${roomId}: ${excludeUserIds.length}`);
        }
      } catch (e) {
        logger.warn('[PushService] Online check failed (Non-fatal):', e.message);
      }
    }

    await pushQueue.add('MESSAGE', {
      roomId,
      senderUserId,
      senderNicknameMask,
      messageContent,
      messageType,
      excludeUserIds, // Pass exclusion list to Worker
      messageId
    });
    return { success: true, queued: true, messageId };
  } catch (error) {
    logger.error('[PushService] Queue Error:', error);
    return { success: false, error: 'Queue Error' };
  }
};

const sendNearbyUserFoundNotification = async (userIds, userCount) => {
  try {
    await pushQueue.add('NEARBY', {
      userIds,
      userCount
    });
    return { success: true, queued: true };
  } catch (error) {
    logger.error('[PushService] Queue Error:', error);
    return { success: false, error: 'Queue Error' };
  }
};

const sendRoomCreatedNotification = async (roomId, roomName, creatorUserId, nearbyUserIds) => {
  try {
    await pushQueue.add('ROOM_CREATED', {
      roomId,
      roomName,
      creatorUserId,
      nearbyUserIds
    });
    return { success: true, queued: true };
  } catch (error) {
    logger.error('[PushService] Queue Error:', error);
    return { success: false, error: 'Queue Error' };
  }
};

const sendRoomInviteNotification = async (invitedUserId, roomId, roomName, inviterId, inviterNicknameMask) => {
  try {
    await pushQueue.add('ROOM_INVITE', {
      invitedUserId,
      roomId,
      roomName,
      inviterId,
      inviterNicknameMask
    });
    return { success: true, queued: true };
  } catch (error) {
    logger.error('[PushService] Queue Error:', error);
    return { success: false, error: 'Queue Error' };
  }
};

const sendQuickQuestionNotification = async (targetUserIds, content, roomId) => {
  try {
    await pushQueue.add('QUICK_QUESTION', {
      targetUserIds,
      content,
      roomId
    });
    return { success: true, queued: true };
  } catch (error) {
    logger.error('[PushService] Queue Error:', error);
    return { success: false, error: 'Queue Error' };
  }
};

// Legacy/Direct Call Support (Optional: Deprecated)
const sendPushNotification = async (token, platform, notification, data) => {
  logger.warn('[PushService] Direct call to sendPushNotification is deprecated. Use Queue instead.');
  // For specific legacy calls, we might still want to support them via Queue or Direct? 
  // To match interface, let's keep it but warn.
  // Ideally this should be refactored out.
  // For now, return "Not Supported" or implement a "RAW" job type.
  return { success: false, error: 'Direct calls deprecated. Use specific notification methods.' };
};

const sendBatchPushNotifications = async (tokens, platform, notification, data) => {
  logger.warn('[PushService] Direct call to sendBatchPushNotifications is deprecated.');
  return { success: false, error: 'Deprecated' };
};

const initializeFirebase = () => {
  // No-op in facade
  logger.info('[PushService] Firebase init deferred to Worker');
};

module.exports = {
  initializeFirebase,
  pushQueue, // Export queue for Worker binding
  sendMessageNotification,
  sendNearbyUserFoundNotification,
  sendRoomCreatedNotification,
  sendRoomInviteNotification,
  sendQuickQuestionNotification,
  sendPushNotification,
  sendBatchPushNotifications
};
