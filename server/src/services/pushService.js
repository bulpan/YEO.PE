/**
 * 푸시 알림 서비스
 * Firebase Cloud Messaging (FCM)을 사용한 푸시 알림 발송
 */

const admin = require('firebase-admin');
const { query } = require('../config/database');
const logger = require('../utils/logger');
const tokenService = require('./tokenService');
const { PushType, createPushPayload } = require('../constants/pushTypes');

// Firebase Admin SDK 초기화
let firebaseInitialized = false;

const path = require('path');

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
      // .env에 설정된 경로가 프로젝트 루트 기준일 경우를 대비해 절대 경로로 변환
      const resolvedPath = path.isAbsolute(serviceAccountPath)
        ? serviceAccountPath
        : path.resolve(process.cwd(), serviceAccountPath);

      logger.info(`[PushDebug] Loading Firebase config from: ${resolvedPath} (Original: ${serviceAccountPath})`);

      const serviceAccount = require(resolvedPath);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
      });
    } else if (serviceAccountJson) {
      // JSON 문자열로 초기화
      logger.info('[PushDebug] Loading Firebase config from JSON string');
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
      await tokenService.deactivateToken(token);
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
    // FCM 배치 전송 (sendEachForMulticast 사용)
    // sendAll은 deprecated 되었으며 HTTP v1 API로 이전됨
    const message = {
      tokens: tokens, // 토큰 배열
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
    };

    logger.info('[Push Request] Sending Batch', {
      tokensCount: tokens.length,
      notification: notification,
      data: data,
      firstToken: tokens[0] ? tokens[0].substring(0, 10) + '...' : null
    });

    const response = await admin.messaging().sendEachForMulticast(message);

    logger.info(`배치 푸시 알림 전송: 성공 ${response.successCount}개, 실패 ${response.failureCount}개`);

    // 실패한 토큰 처리
    const failedTokens = [];
    if (response.failureCount > 0) {
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const token = tokens[idx];
          failedTokens.push({ token, error: resp.error });

          // 만료된 토큰 삭제
          if (resp.error?.code === 'messaging/registration-token-not-registered' ||
            resp.error?.code === 'messaging/invalid-registration-token') {
            tokenService.deactivateToken(token).catch(err => logger.error('토큰 삭제 실패:', err));
          }
        }
      });

      if (failedTokens.length > 0) {
        logger.warn(`[Push Response] Partial Failure (${failedTokens.length}/${tokens.length})`, {
          failedTokens: failedTokens.map(f => ({ ...f, token: f.token.substring(0, 10) + '...' }))
        });
      }
    } else {
      logger.info(`[Push Response] Success (${response.successCount}/${tokens.length})`);
    }

    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
      failedTokens: response.failureCount > 0 ? failedTokens : []
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
    logger.info(`[PushDebug] sendMessageNotification called for room ${roomId}, sender ${senderUserId}`);

    // 방 멤버 조회 (발신자 제외)
    const members = await query(
      `SELECT DISTINCT rm.user_id 
       FROM yeope_schema.room_members rm
       WHERE rm.room_id = (SELECT id FROM yeope_schema.rooms WHERE room_id = $1)
         AND rm.user_id != $2
         AND rm.left_at IS NULL`,
      [roomId, senderUserId]
    );

    logger.info(`[PushDebug] Found ${members.rows.length} other members in room`);

    if (members.rows.length === 0) {
      logger.info('[PushDebug] No other members found, skipping push');
      return { success: true, sent: 0 };
    }

    const userIds = members.rows.map(row => row.user_id);
    const tokensByUser = await tokenService.getActivePushTokensForUsers(userIds);
    logger.info(`[PushDebug] Found tokens for users: ${Object.keys(tokensByUser).join(', ')}`);

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
      logger.info(`[PushDebug] Connected users in room: ${Array.from(connectedUserIds).join(', ')}`);
    } else {
      logger.warn('[PushDebug] io instance is null, cannot check connected users');
    }

    // 연결되지 않은 사용자만 필터링
    const disconnectedUserIds = userIds.filter(userId => !connectedUserIds.has(userId));
    logger.info(`[PushDebug] Disconnected users (targets): ${disconnectedUserIds.join(', ')}`);

    // 모든 토큰 수집 (연결되지 않은 사용자만)
    const allTokens = [];
    disconnectedUserIds.forEach(userId => {
      if (tokensByUser[userId]) {
        tokensByUser[userId].forEach(tokenInfo => {
          allTokens.push(tokenInfo.token);
        });
      }
    });

    logger.info(`[PushDebug] Total tokens to send: ${allTokens.length}`);

    if (allTokens.length === 0) {
      logger.info('[PushDebug] No tokens to send (all connected or no tokens)');
      return { success: true, sent: 0, reason: 'All users connected or no tokens' };
    }

    // 알림 내용 구성 (Standardized)
    const { notification, data } = createPushPayload(PushType.NEW_MESSAGE, {
      senderNicknameMask,
      messageContent,
      messageType,
      roomId,
      messageId: '' // 메시지 ID는 호출하는 쪽에서 전달
    });

    // 배치 전송
    const result = await sendBatchPushNotifications(allTokens, 'android', notification, data);
    logger.info(`[PushDebug] Send result: success=${result.success}, count=${result.successCount}`);
    return result;
  } catch (error) {
    logger.error('[PushDebug] 메시지 알림 전송 실패:', error);
    return { success: false, error: error.message };
  }
};

/**
 * 주변 사용자 발견 알림 전송
 */
/**
 * 주변 사용자 발견 알림 전송 (단일 또는 다수 사용자)
 */
const sendNearbyUserFoundNotification = async (userIds, userCount) => {
  try {
    const targets = Array.isArray(userIds) ? userIds : [userIds];
    if (targets.length === 0) return { success: true, sent: 0 };

    // 1. 사용자 설정 확인 (푸시 알림 활성화 여부)
    const users = await query(
      `SELECT id, settings FROM yeope_schema.users WHERE id = ANY($1)`,
      [targets]
    );

    const validUserIds = [];
    users.rows.forEach(row => {
      const settings = typeof row.settings === 'string'
        ? JSON.parse(row.settings)
        : row.settings;

      if (settings.pushEnabled !== false) {
        validUserIds.push(row.id);
      }
    });

    if (validUserIds.length === 0) {
      return { success: true, sent: 0, reason: 'All targets disabled push' };
    }

    // 2. 중복 알림 방지 (Redis)
    const redis = require('../config/redis');
    const finalTargets = [];

    for (const uid of validUserIds) {
      const lastNotificationKey = `push:nearby_user:${uid}`;
      const lastNotificationTime = await redis.get(lastNotificationKey);

      let shouldSend = true;
      if (lastNotificationTime) {
        const timeDiff = Date.now() - parseInt(lastNotificationTime);
        if (timeDiff < 1 * 60 * 1000) { // 1분 (Testing)
          shouldSend = false;
        }
      }

      if (shouldSend) {
        finalTargets.push(uid);
      }
    }

    if (finalTargets.length === 0) {
      return { success: true, sent: 0, reason: 'Too frequent for all targets' };
    }

    // 3. 푸시 토큰 조회
    const tokensByUser = await tokenService.getActivePushTokensForUsers(finalTargets);

    const allTokens = [];
    Object.values(tokensByUser).forEach(tokens => {
      tokens.forEach(tokenInfo => {
        allTokens.push(tokenInfo.token);
      });
    });

    if (allTokens.length === 0) {
      return { success: true, sent: 0, reason: 'No tokens' };
    }

    // 4. 알림 전송 (Standardized)
    // 주의: 다수 사용자에게 보내지만, 내용은 동일함 ("주변에 N명 있음")
    // 만약 개별적인 내용이 필요하다면 루프를 돌려야 함. 여기서는 통일.
    const { notification, data } = createPushPayload(PushType.NEARBY_USER, {
      userCount,
      userId: '' // 특정 ID 포커싱은 생략 (다수이므로)
    });

    const result = await sendBatchPushNotifications(allTokens, 'android', notification, data);

    // 5. 마지막 알림 시간 업데이트
    if (result.success) {
      const now = String(Date.now());
      for (const uid of finalTargets) {
        const lastNotificationKey = `push:nearby_user:${uid}`;
        await redis.setex(lastNotificationKey, 1 * 60, now); // 1분 TTL (Testing)
      }
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
const sendRoomCreatedNotification = async (roomId, roomName, creatorUserId, nearbyUserIds) => {
  try {
    if (!nearbyUserIds || nearbyUserIds.length === 0) {
      return { success: true, sent: 0 };
    }

    // 주변 사용자들의 푸시 토큰 조회
    const tokensByUser = await tokenService.getActivePushTokensForUsers(nearbyUserIds);

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

    // 알림 전송 (Standardized)
    const { notification, data } = createPushPayload(PushType.ROOM_CREATED, {
      roomName,
      roomId
    });

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
    const tokens = await tokenService.getActivePushTokens(invitedUserId);

    if (tokens.length === 0) {
      return { success: true, sent: 0, reason: 'No tokens' };
    }

    // 알림 전송 (Standardized)
    const { notification, data } = createPushPayload(PushType.ROOM_INVITE, {
      inviterNicknameMask,
      roomName,
      roomId,
      inviterId
    });

    const allTokens = tokens.map(t => t.device_token);
    const result = await sendBatchPushNotifications(allTokens, 'android', notification, data);

    return result;
  } catch (error) {
    logger.error('방 초대 알림 전송 실패:', error);
    return { success: false, error: error.message };
  }
};

/**
 * 급질문 알림 전송
 */
const sendQuickQuestionNotification = async (targetUserIds, content) => {
  try {
    if (!targetUserIds || targetUserIds.length === 0) {
      return { success: true, sent: 0 };
    }

    // 1. 사용자 설정 확인 (푸시 알림 활성화 여부)
    const users = await query(
      `SELECT id, settings FROM yeope_schema.users WHERE id = ANY($1)`,
      [targetUserIds]
    );

    const validUserIds = [];
    users.rows.forEach(row => {
      const settings = typeof row.settings === 'string'
        ? JSON.parse(row.settings)
        : row.settings;

      if (settings.pushEnabled !== false) {
        validUserIds.push(row.id);
      }
    });

    if (validUserIds.length === 0) {
      return { success: true, sent: 0, reason: 'All targets disabled push' };
    }

    // 2. 푸시 토큰 조회
    const tokensByUser = await tokenService.getActivePushTokensForUsers(validUserIds);

    const allTokens = [];
    Object.values(tokensByUser).forEach(tokens => {
      tokens.forEach(tokenInfo => {
        allTokens.push(tokenInfo.token);
      });
    });

    if (allTokens.length === 0) {
      return { success: true, sent: 0, reason: 'No tokens' };
    }

    // 3. 알림 전송
    const { notification, data } = createPushPayload(PushType.QUICK_QUESTION, {
      content
    });

    const result = await sendBatchPushNotifications(allTokens, 'android', notification, data);
    return result;
  } catch (error) {
    logger.error('급질문 알림 전송 실패:', error);
    return { success: false, error: error.message };
  }
};

module.exports = {
  initializeFirebase,
  sendPushNotification,
  sendBatchPushNotifications,
  sendMessageNotification,
  sendNearbyUserFoundNotification,
  sendRoomCreatedNotification,
  sendRoomInviteNotification,
  sendQuickQuestionNotification
};

