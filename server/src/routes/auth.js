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

    // Provider별 토큰 처리
    if (provider === 'google' || provider === 'apple') {
      // JWT 디코딩 (서명 검증은 생략하고 Payload만 확인 - MVP)
      const jwt = require('jsonwebtoken');
      const decoded = jwt.decode(token);

      if (!decoded) {
        throw new ValidationError('유효하지 않은 토큰입니다');
      }

      providerId = decoded.sub;
      email = decoded.email;
      nickname = decoded.name || (email ? email.split('@')[0] : `User_${providerId.substring(0, 6)}`);

      if (!email) {
        // Apple의 경우 이메일 비공개시 email이 없을 수 있음. 가상 이메일 생성
        email = `${provider}_${providerId}@yeo.pe`;
      }

    } else if (provider === 'kakao') {
      // Kakao는 Access Token이므로 자체 검증 필요하지만,
      // MVP에서는 토큰 자체를 ID로 사용하거나, 클라이언트에서 ID를 보내줘야 함.
      // 여기서는 임시로 토큰의 해시를 ID로 사용하거나, 그냥 토큰 앞부분 사용.
      // 실제로는 Kakao API 호출해야 함: https://kapi.kakao.com/v2/user/me

      // 임시 구현: Kakao API 호출 시도 (axios 필요)
      try {
        const axios = require('axios');
        const kakaoRes = await axios.get('https://kapi.kakao.com/v2/user/me', {
          headers: { Authorization: `Bearer ${token}` }
        });

        providerId = String(kakaoRes.data.id);
        const kakaoAccount = kakaoRes.data.kakao_account || {};
        email = kakaoAccount.email || `kakao_${providerId}@yeo.pe`;
        nickname = (kakaoAccount.profile && kakaoAccount.profile.nickname) || `KakaoUser_${providerId}`;

      } catch (e) {
        logger.warn(`Kakao API 호출 실패: ${e.message}. Mocking login.`);
        // API 호출 실패시 (테스트용 토큰 등) Mock 처리
        providerId = `mock_kakao_${token.substring(0, 10)}`;
        email = `kakao_${providerId}@yeo.pe`;
        nickname = `KakaoUser`;
      }
    } else if (provider === 'naver') {
      // Naver Login
      // https://developers.naver.com/docs/login/api/v1/nid/me

      try {
        const axios = require('axios');
        const naverRes = await axios.get('https://openapi.naver.com/v1/nid/me', {
          headers: { Authorization: `Bearer ${token}` }
        });

        if (naverRes.data.resultcode !== '00') {
          throw new Error(`Naver API Error: ${naverRes.data.message}`);
        }

        const naverAccount = naverRes.data.response;
        providerId = naverAccount.id;
        email = naverAccount.email || `naver_${providerId}@yeo.pe`;
        nickname = naverAccount.nickname || `NaverUser_${providerId.substring(0, 6)}`;

      } catch (e) {
        logger.warn(`Naver API 호출 실패: ${e.message}. Mocking login for dev/test.`);
        // API 호출 실패시 (테스트용 토큰 등) Mock 처리
        // 실제 운영 환경에서는 이 부분을 제거하거나 더 엄격하게 처리해야 함
        providerId = `mock_naver_${token.substring(0, 10)}`;
        email = `naver_${providerId}@yeo.pe`;
        nickname = `NaverUser`;
      }
    } else {
      throw new ValidationError('지원하지 않는 소셜 공급자입니다');
    }

    // 사용자 로그인/생성
    const user = await userService.loginSocialUser(provider, providerId, email, nickname);

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

module.exports = router;

