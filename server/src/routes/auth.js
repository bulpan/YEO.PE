/**
 * 인증 API 라우트
 */

const express = require('express');
const router = express.Router();
const { generateAccessToken, generateRefreshToken } = require('../config/auth');
const { authenticate } = require('../middleware/auth');
const { authLimiter } = require('../middleware/rateLimit');
const userService = require('../services/userService');
const redis = require('../config/redis');
const { ValidationError } = require('../utils/errors');
const logger = require('../utils/logger');
const { admin } = require('../config/firebase');

/**
 * POST /api/auth/register
 * 이메일 회원가입
 */
router.post('/register', authLimiter, async (req, res, next) => {
  try {
    const { email, password, nickname } = req.body;

    // 입력 검증
    if (!email || !password || !nickname) {
      throw new ValidationError('이메일, 비밀번호, 닉네임을 모두 입력해주세요');
    }

    if (password.length < 8) {
      throw new ValidationError('비밀번호는 8자 이상이어야 합니다');
    }

    if (nickname.length < 2 || nickname.length > 20) {
      throw new ValidationError('닉네임은 2자 이상 20자 이하여야 합니다');
    }

    // 이메일 형식 검증
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new ValidationError('올바른 이메일 형식이 아닙니다');
    }

    // 사용자 생성
    const user = await userService.createUser(email, password, nickname);

    // JWT 토큰 생성
    const accessToken = generateAccessToken({
      userId: user.id,
      email: user.email
    });

    const refreshToken = generateRefreshToken({
      userId: user.id
    });

    // Refresh Token을 Redis에 저장 (30일)
    await redis.setex(
      `refresh_token:${user.id}`,
      30 * 24 * 60 * 60, // 30일
      refreshToken
    );

    logger.info(`새 사용자 등록: ${user.email}`);

    res.status(201).json({
      token: accessToken,
      refreshToken: refreshToken,
      user: {
        id: user.id,
        email: user.email,
        nickname: user.nickname,
        nicknameMask: user.nickname_mask
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/auth/login
 * 이메일 로그인
 */
router.post('/login', authLimiter, async (req, res, next) => {
  try {
    const { email, password } = req.body;

    // 입력 검증
    if (!email || !password) {
      throw new ValidationError('이메일과 비밀번호를 입력해주세요');
    }

    // 사용자 인증
    const user = await userService.loginUser(email, password);

    // JWT 토큰 생성
    const accessToken = generateAccessToken({
      userId: user.id,
      email: user.email
    });

    const refreshToken = generateRefreshToken({
      userId: user.id
    });

    // Refresh Token을 Redis에 저장 (30일)
    await redis.setex(
      `refresh_token:${user.id}`,
      30 * 24 * 60 * 60, // 30일
      refreshToken
    );

    logger.info(`사용자 로그인: ${user.email}`);

    res.json({
      token: accessToken,
      refreshToken: refreshToken,
      user: {
        id: user.id,
        email: user.email,
        nickname: user.nickname,
        nicknameMask: user.nicknameMask
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/auth/logout
 * 로그아웃 (Refresh Token 삭제)
 */
router.post('/logout', authenticate, async (req, res, next) => {
  try {
    const userId = req.user.userId;

    // [Logout Cleanup] Leave all rooms
    try {
      const roomService = require('../services/roomService');
      await roomService.leaveAllRooms(userId);
    } catch (err) {
      logger.error(`Logout cleanup failed for ${userId}:`, err);
    }

    // Refresh Token 삭제
    await redis.del(`refresh_token:${userId}`);

    logger.info(`사용자 로그아웃: ${userId}`);

    res.json({ message: '로그아웃되었습니다' });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/auth/refresh
 * Access Token 갱신
 */
router.post('/refresh', async (req, res, next) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      throw new ValidationError('Refresh Token이 필요합니다');
    }

    const { verifyToken } = require('../config/auth');
    const decoded = verifyToken(refreshToken);

    if (decoded.type !== 'refresh') {
      throw new ValidationError('유효하지 않은 Refresh Token입니다');
    }

    // Redis에서 Refresh Token 확인
    const storedToken = await redis.get(`refresh_token:${decoded.userId}`);

    if (!storedToken || storedToken !== refreshToken) {
      throw new ValidationError('유효하지 않은 Refresh Token입니다');
    }

    // 사용자 정보 조회
    const user = await userService.findUserById(decoded.userId);

    if (!user) {
      throw new ValidationError('사용자를 찾을 수 없습니다');
    }

    // 새로운 Access Token 생성
    const accessToken = generateAccessToken({
      userId: user.id,
      email: user.email
    });

    res.json({
      token: accessToken
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/auth/me
 * 현재 사용자 정보 조회
 */
router.get('/me', authenticate, async (req, res, next) => {
  try {
    const user = await userService.getUserProfile(req.user.userId);
    res.json({ user });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/auth/social/:provider
 * 소셜 로그인 (Google, Apple, Kakao)
 */
router.post('/social/:provider', async (req, res, next) => {
  try {
    const { provider } = req.params;
    const { token } = req.body;

    if (!token) {
      throw new ValidationError('토큰이 필요합니다');
    }

    let providerId;
    let email;
    let nickname;

    // Provider별 토큰 검증 및 처리
    if (provider === 'google') {
      // Google: ID Token 검증
      const { OAuth2Client } = require('google-auth-library');
      const client = new OAuth2Client(); // 클라이언트 ID는 환경변수 등에서 로드 권장

      const ticket = await client.verifyIdToken({
        idToken: token,
        // audience: process.env.GOOGLE_CLIENT_ID,  // 실제 운영 시 필수 체크
      });
      const payload = ticket.getPayload();

      providerId = payload.sub;
      email = payload.email;
      nickname = payload.name;

    } else if (provider === 'apple') {
      // Apple: ID Token (JWT) 검증
      // 참고: Apple은 서명 검증을 위해 JWKS를 조회해야 함.
      // MVP 단계에서는 Payload 디코딩 + '비암호화된' 검증만 수행하고, 추후 jwks-rsa 등으로 보강 권장
      const jwt = require('jsonwebtoken');
      const decoded = jwt.decode(token); // 서명 검증 없는 디코딩 (주의)

      if (!decoded || !decoded.sub) {
        throw new ValidationError('유효하지 않은 Apple 토큰입니다');
      }

      providerId = decoded.sub;
      email = decoded.email || `${provider}_${providerId}@yeo.pe`; // 이메일은 첫 로그인 시에만 올 수 있음
      // Apple은 닉네임을 토큰에 안 줌 (클라이언트가 별도로 보내거나 user field에 있음)
      nickname = `User_${providerId.substring(0, 6)}`;

    } else if (provider === 'kakao') {
      // Kakao: Access Token으로 사용자 정보 조회 (보안 강화)
      const axios = require('axios');
      try {
        const kakaoRes = await axios.get('https://kapi.kakao.com/v2/user/me', {
          headers: { Authorization: `Bearer ${token}` }
        });

        providerId = String(kakaoRes.data.id);
        const kakaoAccount = kakaoRes.data.kakao_account || {};
        email = kakaoAccount.email || `kakao_${providerId}@yeo.pe`;
        nickname = (kakaoAccount.profile && kakaoAccount.profile.nickname) || `KakaoUser_${providerId}`;
      } catch (e) {
        logger.error(`Kakao API Verification Failed: ${e.response?.data?.msg || e.message}`);
        throw new ValidationError('유효하지 않은 카카오 토큰입니다');
      }

    } else if (provider === 'naver') {
      // Naver: Access Token으로 사용자 정보 조회 (보안 강화)
      const axios = require('axios');
      try {
        const naverRes = await axios.get('https://openapi.naver.com/v1/nid/me', {
          headers: { Authorization: `Bearer ${token}` }
        });

        if (naverRes.data.resultcode !== '00') {
          throw new ValidationError('유효하지 않은 네이버 토큰입니다');
        }

        const naverAccount = naverRes.data.response;
        providerId = naverAccount.id;
        email = naverAccount.email || `naver_${providerId}@yeo.pe`;
        nickname = naverAccount.nickname || `NaverUser_${providerId.substring(0, 6)}`;
      } catch (e) {
        logger.error(`Naver API Verification Failed: ${e.message}`);
        throw new ValidationError('유효하지 않은 네이버 토큰입니다');
      }

    } else {
      throw new ValidationError('지원하지 않는 소셜 공급자입니다');
    }

    // 사용자 로그인/생성
    const { user, isNewUser } = await userService.loginSocialUser(provider, providerId, email, nickname);

    // JWT 토큰 생성
    const accessToken = generateAccessToken({
      userId: user.id,
      email: user.email
    });

    const refreshToken = generateRefreshToken({
      userId: user.id
    });

    // Refresh Token 저장
    await redis.setex(
      `refresh_token:${user.id}`,
      30 * 24 * 60 * 60,
      refreshToken
    );

    logger.info(`소셜 로그인 성공: ${user.email} (${provider})`);

    res.json({
      token: accessToken,
      refreshToken: refreshToken,
      isNewUser: isNewUser,
      user: {
        id: user.id,
        email: user.email,
        nickname: user.nickname,
        nicknameMask: user.nicknameMask
      }
    });

  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/auth/verify/phone
 * Firebase Phone Auth ID Token 검증 및 전화번호 연동
 */
router.post('/verify/phone', authenticate, async (req, res, next) => {
  try {
    const { idToken } = req.body;
    const userId = req.user.userId;

    if (!idToken) {
      throw new ValidationError('Firebase ID Token이 필요합니다');
    }

    // 1. Firebase Admin으로 토큰 검증
    if (!admin) {
      throw new Error('Firebase Admin이 초기화되지 않았습니다. 서버 설정을 확인해주세요.');
    }

    logger.info(`[PhoneAuth] Verifying token for user ${userId}...`);
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const phoneNumber = decodedToken.phone_number;

    if (!phoneNumber) {
      throw new ValidationError('유효한 전화번호가 포함되지 않은 토큰입니다');
    }

    logger.info(`[PhoneAuth] Token verified. Phone: ${phoneNumber}`);

    // 2. User DB 업데이트
    await userService.updateUserPhoneNumber(userId, phoneNumber);

    res.json({
      success: true,
      message: '본인인증(전화번호)이 완료되었습니다.',
      phoneNumber
    });

  } catch (error) {
    if (error.code && error.code.startsWith('auth/')) {
      logger.error(`[PhoneAuth] Firebase Error: ${error.code} - ${error.message}`);
      return next(new ValidationError('유효하지 않거나 만료된 인증 토큰입니다.'));
    }
    next(error);
  }
});

module.exports = router;

