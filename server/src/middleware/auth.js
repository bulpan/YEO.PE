/**
 * JWT 인증 미들웨어
 */

const { verifyToken } = require('../config/auth');
const { AuthenticationError } = require('../utils/errors');

/**
 * JWT 토큰 인증 미들웨어
 */
const { query } = require('../config/database');

/**
 * JWT 토큰 인증 미들웨어
 * 요청 헤더에서 Authorization: Bearer {token} 형식으로 토큰을 받아 검증
 */
const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new AuthenticationError('인증 토큰이 필요합니다');
    }

    const token = authHeader.substring(7); // 'Bearer ' 제거
    const decoded = verifyToken(token);

    // [New] Check User Status from DB (Enforce Suspension and Activation)
    const result = await query(
      'SELECT status, suspended_until, is_active, suspension_reason, suspended_at FROM yeope_schema.users WHERE id = $1',
      [decoded.userId]
    );

    if (result.rows.length === 0) {
      throw new AuthenticationError('존재하지 않는 사용자입니다');
    }

    const userStatus = result.rows[0];

    // 1. Check Deactivated/Banned (is_active)
    if (userStatus.is_active === false) {
      let reason = userStatus.suspension_reason;

      if (!reason) {
        const settingsService = require('../services/settingsService');
        reason = await settingsService.getValue('ban_reason', JSON.stringify({
          ko: '운영 정책 위반으로 인해 계정이 영구 정지되었습니다.',
          en: 'Your account has been permanently banned due to policy violation.'
        }));
      }

      // Try Parse
      try {
        const parsed = JSON.parse(reason);
        if (parsed && typeof parsed === 'object') reason = parsed;
      } catch (e) { }

      const reasonMsg = (typeof reason === 'object') ? (reason.ko || reason.en || JSON.stringify(reason)) : reason;
      const message = `계정이 비활성화되었습니다: ${reasonMsg}`;

      const error = new Error(message);
      error.statusCode = 403;
      error.code = 'USER_BANNED'; // Client identifier
      error.details = {
        reason: reason,
        suspendedAt: userStatus.suspended_at // Add suspendedAt
      };
      throw error;
    }

    // 2. Check Suspension
    if (userStatus.status === 'suspended') {
      const suspendedUntil = new Date(userStatus.suspended_until);
      if (suspendedUntil > new Date()) {
        let reason = userStatus.suspension_reason;

        // Fallback to Global Setting if reason is missing
        if (!reason) {
          const settingsService = require('../services/settingsService');
          reason = await settingsService.getValue('suspension_reason', JSON.stringify({
            ko: '커뮤니티 가이드라인 위반으로 인해 일시 정지되었습니다.',
            en: 'Temporarily suspended due to community guideline violation.'
          }));
        }

        // Try Parse
        try {
          const parsed = JSON.parse(reason);
          if (parsed && typeof parsed === 'object') reason = parsed;
        } catch (e) { }

        const reasonMsg = (typeof reason === 'object') ? (reason.ko || reason.en || JSON.stringify(reason)) : reason;
        const message = `계정이 정지되었습니다. 사유: ${reasonMsg} (${suspendedUntil.toLocaleString()}까지 이용 불가)`;
        const error = new Error(message);
        error.statusCode = 403;
        error.code = 'USER_SUSPENDED'; // Client identifier
        error.details = {
          suspendedUntil: suspendedUntil.toISOString(),
          reason: reason,
          suspendedAt: userStatus.suspended_at // Add suspendedAt
        };
        throw error;
      } else {
        // Auto-reactivate
        await query("UPDATE yeope_schema.users SET status = 'active', suspended_until = NULL, suspension_reason = NULL WHERE id = $1", [decoded.userId]);
      }
    } else if (userStatus.status === 'banned') {
      throw new AuthenticationError('영구 정지된 계정입니다');
    }

    // 요청 객체에 사용자 정보 추가
    req.user = {
      userId: decoded.userId,
      email: decoded.email
    };

    next();
  } catch (error) {
    const logger = require('../utils/logger');

    // Don't log full stack for known auth errors
    if (error.statusCode === 403 || error instanceof AuthenticationError) {
      logger.warn(`Auth/Suspension Rejection: ${error.message} (User: ${req.ip})`);
    } else {
      logger.warn(`Authentication Failed: ${error.message} (IP: ${req.ip})`);
    }

    if (error instanceof AuthenticationError) {
      return next(error);
    }
    // Pass custom 403 error
    if (error.statusCode) {
      return res.status(error.statusCode).json({
        error: {
          message: error.message,
          code: error.code,
          details: error.details
        }
      });
    }

    next(new AuthenticationError('유효하지 않은 토큰입니다'));
  }
};

/**
 * 선택적 인증 미들웨어 (비회원도 접근 가능하지만, 토큰이 있으면 사용자 정보 추가)
 */
const optionalAuthenticate = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring(7);
      const decoded = verifyToken(token);
      req.user = {
        userId: decoded.userId,
        email: decoded.email
      };
    }

    next();
  } catch (error) {
    // 토큰이 유효하지 않아도 계속 진행 (비회원 모드)
    next();
  }
};

/**
 * 정지된 사용자도 허용하는 인증 미들웨어 (구제 신청용)
 */
const authenticateIgnoreSuspension = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new AuthenticationError('인증 토큰이 필요합니다');
    }

    const token = authHeader.substring(7);
    const decoded = verifyToken(token);

    // 사용자 존재 여부만 확인 (상태 체크 X)
    const result = await query('SELECT id FROM yeope_schema.users WHERE id = $1', [decoded.userId]);

    if (result.rows.length === 0) {
      throw new AuthenticationError('존재하지 않는 사용자입니다');
    }

    req.user = {
      userId: decoded.userId,
      email: decoded.email
    };

    next();
  } catch (error) {
    if (error instanceof AuthenticationError) {
      return next(error);
    }
    next(new AuthenticationError('유효하지 않은 토큰입니다'));
  }
};

module.exports = {
  authenticate,
  optionalAuthenticate,
  authenticateIgnoreSuspension
};





