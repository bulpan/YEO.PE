/**
 * 사용자 API 라우트
 */

const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const bleService = require('../services/bleService');
const { ValidationError } = require('../utils/errors');
const logger = require('../utils/logger');

/**
 * POST /api/users/ble/uid
 * Short UID 발급
 */
router.post('/ble/uid', authenticate, async (req, res, next) => {
    try {
        const userId = req.user.userId;

        const result = await bleService.issueUID(userId);

        logger.info(`Short UID 발급: ${result.uid} for user ${userId}`);

        res.json({
            uid: result.uid,
            expiresAt: result.expiresAt
        });
    } catch (error) {
        next(error);
    }
});

/**
 * POST /api/users/ble/scan
 * UID 목록으로 사용자 정보 조회
 */
router.post('/ble/scan', authenticate, async (req, res, next) => {
    try {
        const { uids } = req.body;
        const userId = req.user.userId;

        if (!uids || !Array.isArray(uids) || uids.length === 0) {
            throw new ValidationError('UID 목록이 필요합니다');
        }

        // UID 목록 검증
        if (uids.length > 50) {
            throw new ValidationError('UID 목록은 최대 50개까지 조회 가능합니다');
        }

        // 각 UID 검증
        for (const uidInfo of uids) {
            if (!uidInfo.uid || typeof uidInfo.uid !== 'string') {
                throw new ValidationError('유효하지 않은 UID 형식입니다');
            }
            if (uidInfo.rssi && (uidInfo.rssi < -120 || uidInfo.rssi > 0)) {
                throw new ValidationError('유효하지 않은 RSSI 값입니다');
            }
        }

        const users = await bleService.getUsersByUIDs(uids);

        // 30m 이내 사용자만 필터링
        const nearbyUsers = users.filter(user => {
            if (user.distance === null) return false;
            return user.distance <= 30;
        });

        // 주변 사용자 발견 알림 전송 (새로운 사용자가 발견된 경우)
        const pushService = require('../services/pushService');
        const redis = require('../config/redis');

        // 이전 스캔 결과와 비교 (Redis에 캐시)
        const lastScanKey = `ble:scan:${userId}`;
        const lastScanResult = await redis.get(lastScanKey);
        const lastUids = lastScanResult ? JSON.parse(lastScanResult) : [];

        const currentUids = nearbyUsers.map(u => u.uid);
        const newUids = currentUids.filter(uid => !lastUids.includes(uid));

        // 새로운 사용자가 발견된 경우 알림 전송
        if (newUids.length > 0) {
            pushService.sendNearbyUserFoundNotification(
                userId,
                newUids.length
            ).catch(err => {
                logger.error('주변 사용자 발견 알림 전송 실패:', err);
            });
        }

        // 현재 스캔 결과 캐시 (5분 TTL)
        await redis.setex(lastScanKey, 5 * 60, JSON.stringify(currentUids));

        res.json({
            users: nearbyUsers
        });
    } catch (error) {
        next(error);
    }
});

/**
 * PATCH /api/users/me
 * 사용자 정보 수정 (닉네임, 설정)
 */
router.patch('/me', authenticate, async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const { nickname, settings } = req.body;

        if (!nickname && !settings) {
            throw new ValidationError('수정할 정보를 입력해주세요');
        }

        const userService = require('../services/userService');
        const updatedUser = await userService.updateUser(userId, { nickname, settings });

        logger.info(`사용자 정보 수정: ${userId}`);

        res.json({
            user: updatedUser
        });
    } catch (error) {
        next(error);
    }
});

module.exports = router;
