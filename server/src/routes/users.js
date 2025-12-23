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

        // 3.5. 이미 대화 중인 사용자 필터링
        const roomService = require('../services/roomService');
        const myRooms = await roomService.getUserRooms(userId);

        // 내 방에 있는 상대방 ID 목록 추출 (Private 1:1 방의 경우)
        // Creator이거나 Invitee인 경우 상대방 ID를 찾음
        const chattingUserIds = new Set();
        myRooms.forEach(r => {
            if (r.isActive && r.metadata?.inviteeId) {
                // 1:1 방으로 가정
                if (r.creatorId === userId) chattingUserIds.add(r.metadata.inviteeId);
                else if (r.metadata.inviteeId === userId) chattingUserIds.add(r.creatorId);
            }
        });

        const usersToNotify = nearbyUsers.filter(u => !chattingUserIds.has(u.id));
        const notifyUids = usersToNotify.map(u => u.uid);

        // Redis Check against Last Scan
        const lastScanKey = `ble:scan:${userId}`;
        const lastScanResult = await redis.get(lastScanKey);
        const lastUids = lastScanResult ? JSON.parse(lastScanResult) : [];

        // 실제로 알림 보낼 대상: (이번 발견 목록 - 이미 대화중) - (저번에 발견함)
        const currentUids = nearbyUsers.map(u => u.uid); // 캐시는 전체 저장 (그래야 사라졌을 때 등 추적 가능.. 아니면 알림만 필터?)
        // 알림 로직: "New Nearby Found"
        // 이미 대화 중인 사람은 "New"로 취급 안 함? 요구사항: "알림도 ... 제외해야해"
        // 즉, 대화 중인 사람이 나타나도 알림 X.

        const meaningfulNewUids = notifyUids.filter(uid => !lastUids.includes(uid));

        // 새로운 대화 비참여 사용자가 발견된 경우 알림 전송
        if (meaningfulNewUids.length > 0) {
            pushService.sendNearbyUserFoundNotification(
                userId,
                meaningfulNewUids.length
            ).catch(err => {
                logger.error('주변 사용자 발견 알림 전송 실패:', err);
            });
        }

        // 현재 스캔 결과 캐시 (1분 TTL - Testing)
        await redis.setex(lastScanKey, 1 * 60, JSON.stringify(currentUids));

        res.json({
            users: nearbyUsers
        });
    } catch (error) {
        next(error);
    }
});

/**
 * GET /api/users/me
 * 내 정보 조회
 */
router.get('/me', authenticate, async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const userService = require('../services/userService');
        const user = await userService.findUserById(userId);

        res.json({ user });
    } catch (error) {
        next(error);
    }
});

/**
 * PATCH /api/users/me
 * 사용자 정보 수정 (닉네임, 설정, 공개 ID)
 */
router.patch('/me', authenticate, async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const { nickname, nicknameMask, settings, profileImageUrl } = req.body;

        if (!nickname && !settings && !nicknameMask && !profileImageUrl) {
            throw new ValidationError('수정할 정보를 입력해주세요');
        }

        const userService = require('../services/userService');
        const updatedUser = await userService.updateUser(userId, { nickname, nicknameMask, settings, profileImageUrl });

        logger.info(`사용자 정보 수정: ${userId}`);

        res.json({
            user: updatedUser
        });
    } catch (error) {
        next(error);
    }
});

/**
 * POST /api/users/me/mask
 * 닉네임 마스크(익명 ID) 랜덤 변경
 */
router.post('/me/mask', authenticate, async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const userService = require('../services/userService');
        const updatedUser = await userService.regenerateMask(userId);

        logger.info(`익명 ID 변경: ${userId} -> ${updatedUser.nicknameMask}`);

        res.json({ user: updatedUser });
    } catch (error) {
        next(error);
    }
});

/**
 * DELETE /api/users/me
 * 회원 탈퇴
 */
router.delete('/me', authenticate, async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const userService = require('../services/userService');

        await userService.deleteUser(userId);

        logger.info(`회원 탈퇴: ${userId}`);

        res.json({ success: true, message: '계정이 삭제되었습니다.' });
    } catch (error) {
        next(error);
    }
});

/**
 * POST /api/users/quick_question
 * 급질문 (주변 사용자에게 질문 전송)
 */
router.post('/quick_question', authenticate, async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const { uids, content } = req.body;

        if (!uids || !Array.isArray(uids) || uids.length === 0) {
            return res.json({ message: '주변에 발견된 사용자가 없어 질문을 보낼 수 없습니다.' });
        }

        if (!content || content.trim().length === 0) {
            throw new ValidationError('질문 내용을 입력해주세요');
        }

        // 쿨다운 체크 (Redis)
        const redis = require('../config/redis');
        const cooldownKey = `quick_question:${userId}`;
        const lastSent = await redis.get(cooldownKey);

        if (lastSent) {
            return res.status(429).json({ message: '잠시 후 다시 시도해주세요.' });
        }

        // Create a new room for the quick question
        const roomService = require('../services/roomService');
        const messageService = require('../services/messageService');

        // 1. Create Room (Category: 'quick_question')
        // Name it based on content summary or standard
        const roomName = content.length > 20 ? content.substring(0, 20) + '...' : content;
        const newRoom = await roomService.createRoom(userId, roomName, 'quick_question');
        const roomId = newRoom.id;
        const roomUuid = newRoom.roomId;

        logger.info(`급질문 방 생성: ${roomUuid} (Creator: ${userId})`);

        // 2. Insert Message
        const message = await messageService.createMessage(
            userId,
            roomUuid, // Pass UUID string as expected by messageService/roomService
            'text',
            content
        );

        // 3. Send Notifications & Invite (Push logic needs update to support inviting to existing room)
        const bleService = require('../services/bleService');
        const pushService = require('../services/pushService');

        // Target Users
        const targetUsers = await bleService.getUsersByUIDs(uids.map(u => ({ uid: u })));
        const targetUserIds = targetUsers.map(u => u.id);

        logger.info(`[Debug] QuickQuestion Targets - UIDs: ${uids.join(', ')}, Found UserIds: ${targetUserIds.join(', ')}`);

        let successCount = 0;
        if (targetUserIds.length > 0) {
            // Send Push with Action: CHAT_ROOM
            // We need a new method or update sendQuickQuestionNotification to include room info
            // Actually, we can just send "Room Invite" style push but with "Quick Question" context.
            // But requirements say "Like sending a question... but acts like room invite".
            // Let's make a specific `sendQuickQuestionInvite` in pushService.

            // For now, let's use a specialized batch send here or update pushService.
            // Let's invoke pushService.sendQuickQuestionNotification but with roomId param (we need to update that function).

            const result = await pushService.sendQuickQuestionNotification(
                targetUserIds,
                content,
                roomUuid // Pass roomId
            );
            successCount = result.successCount || 0;

            logger.info(`급질문 전송 (방 초대): User ${userId} -> ${targetUserIds.length} users (Success: ${successCount})`);

            // 쿨다운 설정 (1분)
            await redis.setex(cooldownKey, 60, String(Date.now()));
        }

        res.json({
            success: true,
            sentCount: successCount,
            room: newRoom // Return room info so client can join immediately
        });
    } catch (error) {
        next(error);
    }
});

/**
 * POST /api/users/boost
 * 내 신호 증폭 (Deprecated -> quick_question 사용 권장)
 */
router.post('/boost', authenticate, async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const { uids } = req.body;

        if (!uids || !Array.isArray(uids) || uids.length === 0) {
            return res.json({ message: '주변에 발견된 사용자가 없어 증폭할 수 없습니다.' });
        }

        const bleService = require('../services/bleService');
        const pushService = require('../services/pushService');

        const targetUsers = await bleService.getUsersByUIDs(uids.map(u => ({ uid: u })));
        const targetUserIds = targetUsers.map(u => u.id);

        if (targetUserIds.length > 0) {
            await pushService.sendNearbyUserFoundNotification(
                targetUserIds,
                1
            );
            logger.info(`신호 증폭: User ${userId} -> ${targetUserIds.length} users`);
        }

        res.json({
            success: true,
            boostedCount: targetUserIds.length
        });
    } catch (error) {
        next(error);
    }
});

/**
 * POST /api/users/block
 * 사용자 차단
 */
router.post('/block', authenticate, async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const { targetUserId } = req.body;

        if (!targetUserId) {
            throw new ValidationError('차단할 사용자 ID가 필요합니다');
        }

        const userService = require('../services/userService');
        await userService.blockUser(userId, targetUserId);

        logger.info(`사용자 차단: ${userId} -> ${targetUserId}`);

        res.json({ success: true, message: '사용자를 차단했습니다.' });
    } catch (error) {
        next(error);
    }
});

/**
 * POST /api/users/unblock
 * 사용자 차단 해제
 */
router.post('/unblock', authenticate, async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const { targetUserId } = req.body;

        if (!targetUserId) {
            throw new ValidationError('차단 해제할 사용자 ID가 필요합니다');
        }

        const userService = require('../services/userService');
        await userService.unblockUser(userId, targetUserId);

        logger.info(`사용자 차단 해제: ${userId} -> ${targetUserId}`);

        res.json({ success: true, message: '사용자 차단을 해제했습니다.' });
    } catch (error) {
        next(error);
    }
});

/**
 * GET /api/users/blocked
 * 차단한 사용자 목록 조회
 */
router.get('/blocked', authenticate, async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const userService = require('../services/userService');
        const blockedUsers = await userService.getBlockedUsers(userId);

        res.json({ blockedUsers });
    } catch (error) {
        next(error);
    }
});

/**
 * POST /api/users/report
 * 사용자 신고
 */
router.post('/report', authenticate, async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const { targetUserId, reason, details } = req.body;

        if (!targetUserId || !reason) {
            throw new ValidationError('신고 대상과 사유가 필요합니다');
        }

        const userService = require('../services/userService');
        await userService.reportUser(userId, targetUserId, reason, details);

        logger.info(`사용자 신고: ${userId} -> ${targetUserId} (${reason})`);

        res.json({ success: true, message: '신고가 접수되었습니다.' });
    } catch (error) {
        next(error);
    }
});

module.exports = router;
