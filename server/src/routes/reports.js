const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const { query } = require('../config/database');
const logger = require('../utils/logger');
const { ValidationError } = require('../utils/errors');

// Initialize Reports Table (MVP Lazy Migration)
const initTable = async () => {
    try {
        await query(`
            CREATE TABLE IF NOT EXISTS yeope_schema.reports (
                id SERIAL PRIMARY KEY,
                reporter_id UUID NOT NULL REFERENCES yeope_schema.users(id),
                target_id UUID NOT NULL REFERENCES yeope_schema.users(id),
                reason TEXT NOT NULL,
                details TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);
        logger.info('Reports table initialized');
    } catch (err) {
        logger.error('Failed to init reports table:', err);
    }
};

// Run init
initTable();

/**
 * @route POST /api/reports
 * @desc Report a user
 * @access Private
 */
router.post('/', authenticate, async (req, res, next) => {
    try {
        const reporterId = req.user.userId;
        const { targetUserId, reason, details } = req.body;

        if (!targetUserId || !reason) {
            throw new ValidationError('신고 대상과 사유는 필수입니다.');
        }

        // Prevent self-reporting?
        if (reporterId === targetUserId) {
            throw new ValidationError('자신을 신고할 수 없습니다.');
        }

        await query(
            `INSERT INTO yeope_schema.reports (reporter_id, target_id, reason, details)
             VALUES ($1, $2, $3, $4)`,
            [reporterId, targetUserId, reason, details || '']
        );

        logger.warn(`🚨 신고 접수: User ${reporterId.substring(0, 8)} reported ${targetUserId.substring(0, 8)} (Reason: ${reason})`);

        res.status(201).json({
            success: true,
            message: '신고가 접수되었습니다. 검토 후 조치하겠습니다.'
        });
    } catch (error) {
        next(error);
    }
});

module.exports = router;
