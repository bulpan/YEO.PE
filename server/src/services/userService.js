/**
 * 사용자 서비스
 */

const bcrypt = require('bcrypt');
const { query } = require('../config/database');
const { ValidationError, NotFoundError } = require('../utils/errors');
const { maskNickname } = require('../utils/nickname');
const logger = require('../utils/logger');

/**
 * 이메일로 사용자 조회
 */
const findUserByEmail = async (email) => {
  const result = await query(
    'SELECT * FROM yeope_schema.users WHERE email = $1',
    [email]
  );
  return result.rows[0] || null;
};

/**
 * ID로 사용자 조회
 */
const findUserById = async (userId) => {
  const result = await query(
    'SELECT * FROM yeope_schema.users WHERE id = $1',
    [userId]
  );
  return result.rows[0] || null;
};

/**
 * 사용자 생성 (이메일 회원가입)
 */
const createUser = async (email, password, nickname) => {
  // 이메일 중복 확인
  const existingUser = await findUserByEmail(email);
  if (existingUser) {
    throw new ValidationError('이미 사용 중인 이메일입니다');
  }

  // 비밀번호 해싱
  const passwordHash = await bcrypt.hash(password, 10);

  // 닉네임 마스킹
  const nicknameMask = maskNickname(nickname);

  // 사용자 생성
  const result = await query(
    `INSERT INTO yeope_schema.users 
     (email, auth_provider, nickname, nickname_mask, password_hash, settings)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id, email, nickname, nickname_mask, created_at`,
    [
      email,
      'email',
      nickname,
      nicknameMask,
      passwordHash,
      JSON.stringify({ bleVisible: true, pushEnabled: true })
    ]
  );

  return result.rows[0];
};

/**
 * 비밀번호 검증
 */
const verifyPassword = async (password, passwordHash) => {
  return await bcrypt.compare(password, passwordHash);
};

/**
 * 사용자 로그인 (이메일/비밀번호)
 */
const loginUser = async (email, password) => {
  const user = await findUserByEmail(email);

  if (!user) {
    throw new ValidationError('이메일 또는 비밀번호가 올바르지 않습니다');
  }

  if (!user.password_hash) {
    throw new ValidationError('이메일 로그인을 사용할 수 없는 계정입니다');
  }

  const isValidPassword = await verifyPassword(password, user.password_hash);

  if (!isValidPassword) {
    throw new ValidationError('이메일 또는 비밀번호가 올바르지 않습니다');
  }

  // 마지막 로그인 시간 업데이트
  await query(
    'UPDATE yeope_schema.users SET last_login_at = NOW() WHERE id = $1',
    [user.id]
  );

  return {
    id: user.id,
    email: user.email,
    nickname: user.nickname,
    nicknameMask: user.nickname_mask
  };
};

/**
 * 사용자 정보 조회 (비밀번호 제외)
 */
const getUserProfile = async (userId) => {
  const user = await findUserById(userId);

  if (!user) {
    throw new NotFoundError('사용자를 찾을 수 없습니다');
  }

  return {
    id: user.id,
    email: user.email,
    nickname: user.nickname,
    nicknameMask: user.nickname_mask,
    settings: typeof user.settings === 'string'
      ? JSON.parse(user.settings)
      : user.settings,
    createdAt: user.created_at,
    lastLoginAt: user.last_login_at
  };
};

/**
 * 사용자 정보 수정
 */
const updateUser = async (userId, data) => {
  const { nickname, settings } = data;
  const updates = [];
  const values = [];
  let paramIndex = 1;

  // 1. 닉네임 업데이트
  if (nickname) {
    if (nickname.length < 2 || nickname.length > 20) {
      throw new ValidationError('닉네임은 2자 이상 20자 이하여야 합니다');
    }

    const nicknameMask = maskNickname(nickname);
    updates.push(`nickname = $${paramIndex++}`);
    values.push(nickname);
    updates.push(`nickname_mask = $${paramIndex++}`);
    values.push(nicknameMask);
  }

  // 2. 설정 업데이트
  if (settings) {
    // 기존 설정 조회
    const currentUser = await findUserById(userId);
    if (!currentUser) {
      throw new NotFoundError('사용자를 찾을 수 없습니다');
    }

    const currentSettings = typeof currentUser.settings === 'string'
      ? JSON.parse(currentUser.settings)
      : currentUser.settings;

    const newSettings = { ...currentSettings, ...settings };

    updates.push(`settings = $${paramIndex++}`);
    values.push(JSON.stringify(newSettings));
  }

  if (updates.length === 0) {
    return await getUserProfile(userId);
  }

  values.push(userId);
  const queryText = `
    UPDATE yeope_schema.users 
    SET ${updates.join(', ')} 
    WHERE id = $${paramIndex}
    RETURNING *
  `;

  await query(queryText, values);

  return await getUserProfile(userId);
};

/**
 * 소셜 로그인 (사용자 조회 또는 생성)
 */
const loginSocialUser = async (provider, providerId, email, nickname) => {
  // 1. provider + providerId로 사용자 조회
  const result = await query(
    'SELECT * FROM yeope_schema.users WHERE auth_provider = $1 AND provider_id = $2',
    [provider, providerId]
  );

  let user = result.rows[0];

  // 2. 없으면 생성
  if (!user) {
    // 이메일 중복 체크 (선택사항: 소셜 이메일이 기존 이메일과 겹칠 경우 병합할지, 에러낼지. 여기선 별도 계정으로 처리하거나 에러 무시)
    // 간단히하기 위해 이메일이 겹치면 해당 이메일 유저에게 연동...은 복잡하므로,
    // 이메일이 unique constraint가 있으므로, 만약 겹치면 에러가 날 것임.
    // 여기서는 이메일 뒤에 provider를 붙여서 저장하거나, 그냥 try-catch로 처리.
    // MVP: 그냥 생성 시도.

    const nicknameMask = maskNickname(nickname);

    try {
      const createResult = await query(
        `INSERT INTO yeope_schema.users 
         (email, auth_provider, provider_id, nickname, nickname_mask, settings)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING id, email, nickname, nickname_mask, created_at`,
        [
          email,
          provider,
          providerId,
          nickname,
          nicknameMask,
          JSON.stringify({ bleVisible: true, pushEnabled: true })
        ]
      );
      user = createResult.rows[0];
      logger.info(`소셜 사용자 생성: ${email} (${provider})`);
    } catch (error) {
      // 이메일 중복 에러인 경우
      if (error.code === '23505') { // unique_violation
        // 기존 이메일 유저 찾아서 연동? 아니면 에러?
        // 여기서는 기존 유저를 찾아서 리턴 (이메일 신뢰)
        const existingUser = await findUserByEmail(email);
        if (existingUser) {
          // TODO: provider_id 업데이트?
          user = existingUser;
        } else {
          throw error;
        }
      } else {
        throw error;
      }
    }
  }

  // 로그인 처리 (마지막 로그인 시간 업데이트)
  if (user) {
    await query(
      'UPDATE yeope_schema.users SET last_login_at = NOW() WHERE id = $1',
      [user.id]
    );
  }

  return {
    id: user.id,
    email: user.email,
    nickname: user.nickname,
    nicknameMask: user.nickname_mask
  };
};

module.exports = {
  findUserByEmail,
  findUserById,
  createUser,
  loginUser,
  getUserProfile,
  verifyPassword,
  updateUser,
  loginSocialUser
};
