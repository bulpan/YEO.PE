/**
 * 푸시 토큰 관리 서비스
 */

const { query } = require('../config/database');
const logger = require('../utils/logger');

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
        return {};
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
 * 토큰 비활성화 (만료/삭제 시)
 */
const deactivateToken = async (token) => {
    try {
        await query(
            `UPDATE yeope_schema.push_tokens 
       SET is_active = false 
       WHERE device_token = $1`,
            [token]
        );
        logger.info(`푸시 토큰 비활성화 완료: ${token.substring(0, 20)}...`);
    } catch (error) {
        logger.error('푸시 토큰 비활성화 실패:', error);
        throw error;
    }
};

module.exports = {
    getActivePushTokens,
    getActivePushTokensForUsers,
    deactivateToken
};
