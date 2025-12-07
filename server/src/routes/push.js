/**
 * 푸시 알림 API 라우트
 */

const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const { query } = require('../config/database');
const { ValidationError } = require('../utils/errors');
const logger = require('../utils/logger');

/**
 * POST /api/push/register
 * FCM/APNs 토큰 등록
 */
router.post('/register', authenticate, async (req, res, next) => {
  try {
    const { deviceToken, platform, deviceId, deviceInfo } = req.body;
    const userId = req.user.userId;

    logger.info(`[PushDebug] Registering token for user ${userId}: ${deviceToken?.substring(0, 20)}...`);

    // 입력 검증
    if (!deviceToken) {
      throw new ValidationError('디바이스 토큰이 필요합니다');
    }

    if (!platform || !['ios', 'android'].includes(platform)) {
      throw new ValidationError('플랫폼은 "ios" 또는 "android"여야 합니다');
    }

    // 기존 토큰 확인 (같은 사용자, 같은 토큰)
    const existing = await query(
      `SELECT id FROM yeope_schema.push_tokens 
       WHERE user_id = $1 AND device_token = $2`,
      [userId, deviceToken]
    );

    if (existing.rows.length > 0) {
      // 기존 토큰 업데이트
      await query(
        `UPDATE yeope_schema.push_tokens 
         SET platform = $1, 
             device_id = $2, 
             device_info = $3, 
             is_active = true, 
             last_used_at = NOW(),
             updated_at = NOW()
         WHERE user_id = $4 AND device_token = $5`,
        [
          platform,
          deviceId || null,
          deviceInfo ? JSON.stringify(deviceInfo) : null,
          userId,
          deviceToken
        ]
      );
      logger.info(`푸시 토큰 업데이트: user ${userId}, platform ${platform}`);
    } else {
      // 새 토큰 등록
      await query(
        `INSERT INTO yeope_schema.push_tokens 
         (user_id, device_token, platform, device_id, device_info, is_active)
         VALUES ($1, $2, $3, $4, $5, true)`,
        [
          userId,
          deviceToken,
          platform,
          deviceId || null,
          deviceInfo ? JSON.stringify(deviceInfo) : null
        ]
      );
      logger.info(`푸시 토큰 등록: user ${userId}, platform ${platform}`);
    }

    res.json({
      success: true,
      message: '푸시 토큰이 등록되었습니다'
    });
  } catch (error) {
    next(error);
  }
});

/**
 * DELETE /api/push/unregister
 * 푸시 토큰 삭제 (로그아웃 시 등)
 */
router.delete('/unregister', authenticate, async (req, res, next) => {
  try {
    const { deviceToken } = req.body;
    const userId = req.user.userId;

    if (!deviceToken) {
      throw new ValidationError('디바이스 토큰이 필요합니다');
    }

    // 토큰 비활성화
    await query(
      `UPDATE yeope_schema.push_tokens 
       SET is_active = false, updated_at = NOW()
       WHERE user_id = $1 AND device_token = $2`,
      [userId, deviceToken]
    );

    logger.info(`푸시 토큰 삭제: user ${userId}`);

    res.json({
      success: true,
      message: '푸시 토큰이 삭제되었습니다'
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/push/tokens
 * 내 푸시 토큰 목록 조회
 */
router.get('/tokens', authenticate, async (req, res, next) => {
  try {
    const userId = req.user.userId;

    const result = await query(
      `SELECT id, platform, device_id, device_info, is_active, last_used_at, created_at
       FROM yeope_schema.push_tokens 
       WHERE user_id = $1
       ORDER BY created_at DESC`,
      [userId]
    );

    const tokens = result.rows.map(row => ({
      id: row.id,
      platform: row.platform,
      deviceId: row.device_id,
      deviceInfo: typeof row.device_info === 'string'
        ? JSON.parse(row.device_info)
        : row.device_info,
      isActive: row.is_active,
      lastUsedAt: row.last_used_at,
      createdAt: row.created_at
    }));

    res.json({ tokens });
  } catch (error) {
    next(error);
  }
});

module.exports = router;



