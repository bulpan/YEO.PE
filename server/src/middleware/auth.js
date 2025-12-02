/**
 * JWT 인증 미들웨어
 */

const { verifyToken } = require('../config/auth');
const { AuthenticationError } = require('../utils/errors');

/**
 * JWT 토큰 인증 미들웨어
 * 요청 헤더에서 Authorization: Bearer {token} 형식으로 토큰을 받아 검증
 */
const authenticate = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new AuthenticationError('인증 토큰이 필요합니다');
    }
    
    const token = authHeader.substring(7); // 'Bearer ' 제거
    const decoded = verifyToken(token);
    
    // 요청 객체에 사용자 정보 추가
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

module.exports = {
  authenticate,
  optionalAuthenticate
};





