/**
 * BLE 서비스
 */

const crypto = require('crypto');
const { query, transaction } = require('../config/database');
const { ValidationError, NotFoundError } = require('../utils/errors');
const logger = require('../utils/logger');

/**
 * Short UID 생성 (4~8바이트, 16진수 문자열)
 */
const generateShortUID = () => {
    // 3바이트 = 6자리 16진수 (BLE 패킷 길이 제한 고려)
    const bytes = crypto.randomBytes(3);
    return bytes.toString('hex').toUpperCase();
};

/**
 * 사용자에게 Short UID 발급
 */
const issueUID = async (userId) => {
    return await transaction(async (client) => {
        // 기존 활성 UID 비활성화
        await client.query(
            `UPDATE yeope_schema.ble_uids 
             SET is_active = false 
             WHERE user_id = $1 AND is_active = true`,
            [userId]
        );

        // 새 UID 생성
        let uid;
        let isUnique = false;
        let attempts = 0;
        const maxAttempts = 10;

        while (!isUnique && attempts < maxAttempts) {
            uid = generateShortUID();
            const existing = await client.query(
                'SELECT id FROM yeope_schema.ble_uids WHERE uid = $1',
                [uid]
            );
            if (existing.rows.length === 0) {
                isUnique = true;
            }
            attempts++;
        }

        if (!isUnique) {
            throw new Error('UID 생성 실패: 고유한 UID를 생성할 수 없습니다');
        }

        // 만료 시간 설정 (24시간 후)
        const expiresAt = new Date();
        expiresAt.setHours(expiresAt.getHours() + 24);

        // UID 저장
        await client.query(
            `INSERT INTO yeope_schema.ble_uids 
             (user_id, uid, expires_at, is_active)
             VALUES ($1, $2, $3, true)`,
            [userId, uid, expiresAt]
        );

        logger.info(`Short UID 발급: ${uid} for user ${userId}`);

        return {
            uid,
            expiresAt
        };
    });
};

/**
 * UID로 사용자 정보 조회
 */
const getUserByUID = async (uid) => {
    const result = await query(
        `SELECT u.*, bu.expires_at as uid_expires_at
     FROM yeope_schema.ble_uids bu
     JOIN yeope_schema.users u ON bu.user_id = u.id
     WHERE bu.uid = $1 
       AND bu.is_active = true 
       AND bu.expires_at > NOW()
       AND u.is_active = true`,
        [uid]
    );

    return result.rows[0] || null;
};

/**
 * UID 목록으로 사용자 정보 조회
 */
const getUsersByUIDs = async (uidList, observerId = null) => {
    if (!uidList || uidList.length === 0) {
        return [];
    }

    const uids = uidList.map(item => item.uid);
    const placeholders = uids.map((_, index) => `$${index + 1}`).join(', ');

    // params array starts with UIDs
    const params = [...uids];
    let queryText = `
        SELECT 
           bu.uid,
           u.id as user_id,
           u.nickname,
           u.nickname_mask,
           u.profile_image_url,
           bu.expires_at as uid_expires_at,
           bu.is_active as is_ble_active
         FROM yeope_schema.ble_uids bu
         JOIN yeope_schema.users u ON bu.user_id = u.id
         WHERE bu.uid IN (${placeholders})
           AND bu.expires_at > NOW()
           AND u.is_active = true
           AND u.status != 'under_review'
           AND (u.settings->>'bleVisible' IS DISTINCT FROM 'false')
    `;

    // Filter blocked users if observerId provided
    if (observerId) {
        // observerId is next param
        const observerParamIdx = params.length + 1;
        params.push(observerId);

        queryText += `
            AND u.id NOT IN (
                SELECT blocked_id FROM yeope_schema.blocked_users WHERE blocker_id = $${observerParamIdx}
            )
            AND u.id NOT IN (
                SELECT blocker_id FROM yeope_schema.blocked_users WHERE blocked_id = $${observerParamIdx}
            )
        `;
    }

    const result = await query(queryText, params);

    // UID 목록과 매칭하여 거리 정보 포함
    const users = result.rows.map(user => {
        const uidInfo = uidList.find(item => item.uid === user.uid);
        return {
            uid: user.uid,
            id: user.user_id,
            nickname: user.nickname,
            nicknameMask: user.nickname_mask,
            profileImageUrl: user.profile_image_url,
            distance: uidInfo ? calculateDistance(uidInfo.rssi) : null,
            rssi: uidInfo ? uidInfo.rssi : null,
            isBleActive: user.is_ble_active
        };
    });

    // 활성 방 정보 조회
    for (const user of users) {
        const activeRoom = await query(
            `SELECT r.room_id, r.name
       FROM yeope_schema.rooms r
       JOIN yeope_schema.room_members rm ON r.id = rm.room_id
       WHERE rm.user_id = $1
         AND rm.left_at IS NULL
         AND r.is_active = true
         AND r.expires_at > NOW()
       ORDER BY rm.last_seen_at DESC
       LIMIT 1`,
            [user.userId]
        );

        if (activeRoom.rows.length > 0) {
            user.hasActiveRoom = true;
            user.roomId = activeRoom.rows[0].room_id;
            user.roomName = activeRoom.rows[0].name;
        } else {
            user.hasActiveRoom = false;
        }
    }

    return users;
};

/**
 * RSSI를 거리로 변환 (미터)
 */
const calculateDistance = (rssi) => {
    const txPower = -59; // 전송 전력 (dBm)
    const n = 2; // 경로 손실 지수

    if (rssi === 0) {
        return -1; // 거리를 계산할 수 없음
    }

    const ratio = (txPower - rssi) / (10 * n);
    const distance = Math.pow(10, ratio);

    return Math.round(distance * 10) / 10; // 소수점 첫째 자리까지
};

/**
 * 만료된 UID 정리
 */
const cleanupExpiredUIDs = async () => {
    const result = await query(
        `UPDATE yeope_schema.ble_uids 
     SET is_active = false 
     WHERE expires_at < NOW() AND is_active = true
     RETURNING id`
    );

    logger.info(`만료된 BLE UID ${result.rowCount}개 비활성화`);
    return result.rowCount;
};

module.exports = {
    issueUID,
    getUserByUID,
    getUsersByUIDs,
    calculateDistance,
    cleanupExpiredUIDs
};
