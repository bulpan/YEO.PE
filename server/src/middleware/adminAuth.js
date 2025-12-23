/**
 * Admin 권한 확인 미들웨어
 */

const { verifyToken } = require('../config/auth');
const { AuthenticationError, AuthorizationError } = require('../utils/errors');

const authenticateAdmin = (req, res, next) => {
    try {
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            throw new AuthenticationError('관리자 권한이 필요합니다');
        }

        const token = authHeader.substring(7);
        const decoded = verifyToken(token);

        if (decoded.role !== 'admin') {
            throw new AuthorizationError('관리자 권한이 없습니다');
        }

        req.admin = decoded;
        next();
    } catch (error) {
        if (error instanceof AuthenticationError || error instanceof AuthorizationError) {
            return next(error);
        }
        next(new AuthenticationError('유효하지 않은 토큰입니다'));
    }
};

module.exports = { authenticateAdmin };
