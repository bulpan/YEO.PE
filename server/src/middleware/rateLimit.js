/**
 * Rate Limiting 미들웨어
 */

const rateLimit = require('express-rate-limit');
const logger = require('../utils/logger');

/**
 * 일반 API Rate Limiter
 * 분당 100회 요청 제한
 */
const apiLimiter = rateLimit({
  windowMs: 60 * 1000, // 1분
  max: 100, // 최대 100회 요청
  message: '너무 많은 요청이 발생했습니다. 잠시 후 다시 시도해주세요.',
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    logger.warn(`Rate limit exceeded for IP: ${req.ip}`);
    res.status(429).json({
      error: {
        message: '너무 많은 요청이 발생했습니다. 잠시 후 다시 시도해주세요.'
      }
    });
  }
});

/**
 * 인증 API Rate Limiter
 * 분당 10회 요청 제한 (로그인/회원가입 보호)
 */
const authLimiter = rateLimit({
  windowMs: 60 * 1000, // 1분
  max: 10, // 최대 10회 요청
  message: '인증 요청이 너무 많습니다. 잠시 후 다시 시도해주세요.',
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: true, // 성공한 요청은 카운트에서 제외
  handler: (req, res) => {
    logger.warn(`Auth rate limit exceeded for IP: ${req.ip}`);
    res.status(429).json({
      error: {
        message: '인증 요청이 너무 많습니다. 잠시 후 다시 시도해주세요.'
      }
    });
  }
});

/**
 * 메시지 전송 Rate Limiter
 * 초당 5개, 분당 30개 제한
 */
const messageLimiter = rateLimit({
  windowMs: 60 * 1000, // 1분
  max: 30, // 분당 30개
  message: '메시지 전송이 너무 많습니다. 잠시 후 다시 시도해주세요.',
  standardHeaders: true,
  legacyHeaders: false
});

/**
 * 방 생성 Rate Limiter
 * 시간당 10개 제한
 */
const roomCreationLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1시간
  max: 100, // 시간당 100개 (테스트 위해 상향)
  message: '방 생성이 너무 많습니다. 잠시 후 다시 시도해주세요.',
  standardHeaders: true,
  legacyHeaders: false
});

module.exports = {
  apiLimiter,
  authLimiter,
  messageLimiter,
  roomCreationLimiter
};





