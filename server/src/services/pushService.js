/**
 * 푸시 알림 서비스
 * Firebase Cloud Messaging (FCM)을 사용한 푸시 알림 발송
 */

const admin = require('firebase-admin');
const { query } = require('../config/database');
const logger = require('../utils/logger');

// Firebase Admin SDK 초기화
let firebaseInitialized = false;

const initializeFirebase = () => {
  if (firebaseInitialized) {
    return;
  }

  try {
    // 환경 변수에서 서비스 계정 키 경로 또는 JSON 가져오기
    const serviceAccountPath = process.env.FCM_SERVICE_ACCOUNT_PATH;
    const serviceAccountJson = process.env.FCM_SERVICE_ACCOUNT_JSON;

    if (serviceAccountPath) {
      // 파일 경로로 초기화
      const serviceAccount = require(serviceAccountPath);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
      });
    } else if (serviceAccountJson) {
      // JSON 문자열로 초기화
      const serviceAccount = JSON.parse(serviceAccountJson);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
      });
    } else {
      logger.warn('FCM 서비스 계정이 설정되지 않았습니다. 푸시 알림이 작동하지 않습니다.');
      return;
    }

    firebaseInitialized = true;
    logger.info('Firebase Admin SDK 초기화 완료');
  } catch (error) {
    logger.error('Firebase Admin SDK 초기화 실패:', error);
  }
};

// 서버 시작 시 초기화
initializeFirebase();

/**
 * 사용자의 활성 푸시 토큰 조회
 */
const getActivePushTokens = async (userId) => {
  const result = await query(
    `SELECT device_token, platform 
     FROM yeope_schema.push_tokens 
     WHERE user_id = $1 AND is_active = true`,
    [userId]
  );

  return result.rows;
};

/**
 * 여러 사용자의 활성 푸시 토큰 조회
 */
const getActivePushTokensForUsers = async (userIds) => {
  if (!userIds || userIds.length === 0) {
    return [];
  }

  const placeholders = userIds.map((_, index) => `$${index + 1}`).join(', ');
  const result = await query(
    `SELECT user_id, device_token, platform 
     FROM yeope_schema.push_tokens 
     WHERE user_id IN (${placeholders}) AND is_active = true`,
    userIds
  );

  // 사용자별로 그룹화
  const tokensByUser = {};
  result.rows.forEach(row => {
    if (!tokensByUser[row.user_id]) {
      tokensByUser[row.user_id] = [];
    }
    tokensByUser[row.user_id].push({
      token: row.device_token,
      platform: row.platform
    });
  });

  return tokensByUser;
};

/**
 * FCM을 통해 푸시 알림 전송
 */
const sendPushNotification = async (token, platform, notification, data = {}) => {
  if (!firebaseInitialized) {
    logger.warn('Firebase가 초기화되지 않아 푸시 알림을 전송할 수 없습니다.');
    return { success: false, error: 'Firebase not initialized' };
  }

  try {
    const message = {
      token: token,
      notification: notification,
      data: {
        ...data,
        // 모든 데이터를 문자열로 변환 (FCM 요구사항)
        type: String(data.type || ''),
        timestamp: String(Date.now())
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'yeope_notifications'
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1
          }
        }
      }
    };

    const response = await admin.messaging().send(message);
    logger.info(`푸시 알림 전송 성공: ${response} (token: ${token.substring(0, 20)}...)`);
    return { success: true, messageId: response };
  } catch (error) {
    logger.error(`푸시 알림 전송 실패 (token: ${token.substring(0, 20)}...):`, error);

    // 만료된 토큰인 경우 삭제
    if (error.code === 'messaging/registration-token-not-registered' ||
      error.code === 'messaging/invalid-registration-token') {
      await query(
        `UPDATE yeope_schema.push_tokens 
         SET is_active = false 
         WHERE device_token = $1`,
        [token]
      );
      logger.info(`만료된 푸시 토큰 비활성화: ${token.substring(0, 20)}...`);
    }

    return { success: false, error: error.message };
  }
};

/**
 * 여러 토큰에 배치로 푸시 알림 전송
 */
const sendBatchPushNotifications = async (tokens, platform, notification, data = {}) => {
  if (!firebaseInitialized) {
    logger.warn('Firebase가 초기화되지 않아 푸시 알림을 전송할 수 없습니다.');
    return { success: false, error: 'Firebase not initialized' };
  }

  if (!tokens || tokens.length === 0) {
    return { success: true, results: [] };
  }

  try {
    // FCM 배치 전송 (최대 500개)
    const messages = tokens.map(token => ({
      token: token,
      notification: notification,
      data: {
        ...data,
        type: String(data.type || ''),
        timestamp: String(Date.now())
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'yeope_notifications'
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1
          }
        }
      }
    }));

    const response = await admin.messaging().sendAll(messages);

    logger.info(`배치 푸시 알림 전송: 성공 ${response.successCount}개, 실패 ${response.failureCount}개`);

    // 실패한 토큰 처리
    if (response.failureCount > 0) {
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const token = tokens[idx];
          failedTokens.push({ token, error: resp.error });

          // 만료된 토큰 삭제
          if (resp.error?.code === 'messaging/registration-token-not-registered' ||
            resp.error?.code === 'messaging/invalid-registration-token') {
            query(
              `UPDATE yeope_schema.push_tokens 
               SET is_active = false 
               WHERE device_token = $1`,
              [token]
            ).catch(err => logger.error('토큰 삭제 실패:', err));
          }
        }
      });

      if (failedTokens.length > 0) {
        logger.warn(`실패한 푸시 토큰 ${failedTokens.length}개:`, failedTokens);
      }
    }

    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount
    };
  } catch (error) {
    logger.error('배치 푸시 알림 전송 실패:', error);
    return { success: false, error: error.message };
  }
};

/**
 * 메시지 알림 전송
 * @param {string} roomId - 방 ID
 * @param {string} senderUserId - 발신자 사용자 ID
 * @param {string} senderNicknameMask - 발신자 마스킹된 닉네임
 * @param {string} messageContent - 메시지 내용
 * @param {string} messageType - 메시지 타입 (text, image, emoji)
 * @param {object} io - Socket.io 인스턴스 (선택, 연결 상태 확인용)
 */
const sendMessageNotification = async (roomId, senderUserId, senderNicknameMask, messageContent, messageType = 'text', io = null) => {
  try {
    // 방 멤버 조회 (발신자 제외)
    const members = await query(
      `SELECT DISTINCT rm.user_id 
       FROM yeope_schema.room_members rm
       WHERE rm.room_id = (SELECT id FROM yeope_schema.rooms WHERE room_id = $1)
         AND rm.user_id != $2
         AND rm.left_at IS NULL`,
      [roomId, senderUserId]
    );

    if (members.rows.length === 0) {
      return { success: true, sent: 0 };
    }

    const userIds = members.rows.map(row => row.user_id);
    const tokensByUser = await getActivePushTokensForUsers(userIds);

    // WebSocket 연결 상태 확인 (연결되어 있으면 푸시 발송 안 함)
    const connectedUserIds = new Set();
    if (io) {
      const roomName = `room:${roomId}`;
      const socketsInRoom = await io.in(roomName).fetchSockets();
      socketsInRoom.forEach(socket => {
        if (socket.userId) {
          connectedUserIds.add(socket.userId);
        }
      });
    }

    // 연결되지 않은 사용자만 필터링
    const disconnectedUserIds = userIds.filter(userId => !connectedUserIds.has(userId));

    // 모든 토큰 수집 (연결되지 않은 사용자만)
    const allTokens = [];
    disconnectedUserIds.forEach(userId => {
      if (tokensByUser[userId]) {
        tokensByUser[userId].forEach(tokenInfo => {
          allTokens.push(tokenInfo.token);
        });
      }
    });

    if (allTokens.length === 0) {
      return { success: true, sent: 0, reason: 'All users connected or no tokens' };
    }

    // 알림 내용 구성
    const notification = {
      title: senderNicknameMask,
      body: messageType === 'text' ? messageContent : messageType === 'image' ? '📷 이미지' : '이모지'
    };

    const data = {
      type: 'new_message',
      roomId: roomId,
      messageId: '', // 메시지 ID는 호출하는 쪽에서 전달
      senderNicknameMask: senderNicknameMask
    };

    // 배치 전송
    const result = await sendBatchPushNotifications(allTokens, 'android', notification, data);
    return result;
  } catch (error) {
    logger.error('메시지 알림 전송 실패:', error);
    return { success: false, error: error.message };
  }
};

/**
 * 주변 사용자 발견 알림 전송
 */
const sendNearbyUserFoundNotification = async (userId, userCount) => {
  try {
    // 사용자 설정 확인 (푸시 알림 활성화 여부)
    const user = await query(
      `SELECT settings FROM yeope_schema.users WHERE id = $1`,
      [userId]
    );

    if (user.rows.length === 0) {
      return { success: false, error: 'User not found' };
    }

    const settings = typeof user.rows[0].settings === 'string'
      ? JSON.parse(user.rows[0].settings)
      : user.rows[0].settings;

    if (settings.pushEnabled === false) {
      return { success: true, sent: 0, reason: 'Push disabled by user' };
    }

    // 중복 알림 방지 (최근 5분 이내 발송 여부 확인)
    const redis = require('../config/redis');
    const lastNotificationKey = `push:nearby_user:${userId}`;
    const lastNotificationTime = await redis.get(lastNotificationKey);

    if (lastNotificationTime) {
      const timeDiff = Date.now() - parseInt(lastNotificationTime);
      if (timeDiff < 5 * 60 * 1000) { // 5분
        return { success: true, sent: 0, reason: 'Too frequent' };
      }
    }

    // 푸시 토큰 조회
    const tokens = await getActivePushTokens(userId);
    if (tokens.length === 0) {
      return { success: true, sent: 0, reason: 'No tokens' };
    }

    // 알림 전송
    const notification = {
      title: '주변에 사용자가 있습니다',
      body: `근처에 YEO.PE 사용자 ${userCount}명이 있습니다`
    };

    const data = {
      type: 'nearby_user_found',
      userCount: String(userCount),
      timestamp: String(Date.now())
    };

    const allTokens = tokens.map(t => t.device_token);
    const result = await sendBatchPushNotifications(allTokens, 'android', notification, data);

    // 마지막 알림 시간 저장 (5분 TTL)
    if (result.success) {
      await redis.setex(lastNotificationKey, 5 * 60, String(Date.now()));
    }

    return result;
  } catch (error) {
    logger.error('주변 사용자 발견 알림 전송 실패:', error);
    return { success: false, error: error.message };
  }
};

/**
 * 방 생성 알림 전송 (주변 사용자에게)
 */
/**
 * 방 생성 알림 전송 (주변 사용자에게)
 */
const sendRoomCreatedNotification = async (roomId, roomName, creatorUserId, nearbyUserIds) => {
  try {
    if (!nearbyUserIds || nearbyUserIds.length === 0) {
      return { success: true, sent: 0 };
    }

    // 주변 사용자들의 푸시 토큰 조회
    const tokensByUser = await getActivePushTokensForUsers(nearbyUserIds);

    // 모든 토큰 수집
    const allTokens = [];
    Object.values(tokensByUser).forEach(tokens => {
      tokens.forEach(tokenInfo => {
        allTokens.push(tokenInfo.token);
      });
    });

    if (allTokens.length === 0) {
      return { success: true, sent: 0 };
    }

    // 알림 전송
    const notification = {
      title: '새로운 방이 생성되었습니다',
      body: roomName
    };

    const data = {
      type: 'room_created',
      roomId: roomId,
      roomName: roomName
    };

    const result = await sendBatchPushNotifications(allTokens, 'android', notification, data);
    return result;
  } catch (error) {
    logger.error('방 생성 알림 전송 실패:', error);
    return { success: false, error: error.message };
  }
};

/**
 * 방 초대 알림 전송
 */
const sendRoomInviteNotification = async (invitedUserId, roomId, roomName, inviterId, inviterNicknameMask) => {
  try {
    // 초대받은 사용자의 푸시 토큰 조회
    const tokens = await getActivePushTokens(invitedUserId);

    if (tokens.length === 0) {
      return { success: true, sent: 0, reason: 'No tokens' };
    }

    // 알림 전송
    const notification = {
      title: '방 초대',
      body: `${inviterNicknameMask}님이 ${roomName} 방에 초대했습니다`
    };

    const data = {
      type: 'room_invite',
      roomId: roomId,
      roomName: roomName,
      inviterId: inviterId
    };

    const allTokens = tokens.map(t => t.device_token);
    const result = await sendBatchPushNotifications(allTokens, 'android', notification, data);

    return result;
  } catch (error) {
    logger.error('방 초대 알림 전송 실패:', error);
    return { success: false, error: error.message };
  }
};

module.exports = {
  initializeFirebase,
  getActivePushTokens,
  getActivePushTokensForUsers,
  sendPushNotification,
  sendBatchPushNotifications,
  sendMessageNotification,
  sendNearbyUserFoundNotification,
  sendRoomCreatedNotification,
  sendRoomInviteNotification
};

