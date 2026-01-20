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
     (email, auth_provider, nickname, nickname_mask, password_hash, settings, profile_image_url)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING id, email, nickname, nickname_mask, profile_image_url, created_at`,
    [
      email,
      'email',
      nickname,
      nicknameMask,
      passwordHash,
      JSON.stringify({ bleVisible: true, pushEnabled: true }),
      null // Initial profile image is null
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
    nicknameMask: user.nickname_mask,
    profileImageUrl: user.profile_image_url // Mapped
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
    profileImageUrl: user.profile_image_url, // Added
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
  const { nickname, nicknameMask, settings, profileImageUrl } = data;
  const updates = [];
  const values = [];
  let paramIndex = 1;

  // 1. 실제 닉네임 업데이트 (Private)
  if (nickname) {
    if (nickname.length > 50) {
      throw new ValidationError('닉네임이 너무 깁니다');
    }
    updates.push(`nickname = $${paramIndex++}`);
    values.push(nickname);
  }

  // 2. 닉네임 마스크(공개 ID) 업데이트
  if (nicknameMask !== undefined) {
    if (nicknameMask === '' || nicknameMask === null) {
      updates.push(`nickname_mask = NULL`);
    } else {
      if (nicknameMask.length < 2 || nicknameMask.length > 20) {
        throw new ValidationError('공개 닉네임은 2자 이상 20자 이하여야 합니다');
      }

      // 중복 체크
      const existing = await query(
        'SELECT id FROM yeope_schema.users WHERE nickname_mask = $1',
        [nicknameMask]
      );

      if (existing.rows.length > 0 && existing.rows[0].id !== userId) {
        throw new ValidationError('이미 사용 중인 닉네임입니다');
      }

      updates.push(`nickname_mask = $${paramIndex++}`);
      values.push(nicknameMask);
    }
  }

  // 3. 프로필 이미지 업데이트
  if (profileImageUrl !== undefined) {
    // Allow null/empty string to remove? For now assume valid URL or empty to clear
    updates.push(`profile_image_url = $${paramIndex++}`);
    values.push(profileImageUrl);
  }

  // 4. 설정 업데이트
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
  let isNewUser = false;
  if (!user) {
    isNewUser = true;

    const nicknameMask = maskNickname(nickname);

    try {
      const createResult = await query(
        `INSERT INTO yeope_schema.users 
         (email, auth_provider, provider_id, nickname, nickname_mask, settings, profile_image_url)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING id, email, nickname, nickname_mask, profile_image_url, created_at`,
        [
          email,
          provider,
          providerId,
          nickname,
          nicknameMask,
          JSON.stringify({ bleVisible: true, pushEnabled: true }),
          null
        ]
      );
      user = createResult.rows[0];
      logger.info(`소셜 사용자 생성: ${email} (${provider})`);
    } catch (error) {
      // 이메일 중복 에러인 경우
      if (error.code === '23505') { // unique_violation
        isNewUser = false;
        const existingUser = await findUserByEmail(email);
        if (existingUser) {
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
    user: {
      id: user.id,
      email: user.email,
      nickname: user.nickname,
      nicknameMask: user.nickname_mask
    },
    isNewUser
  };
};

/**
 * 사용자 삭제
 */
const deleteUser = async (userId) => {
  // Related data (messages, rooms) should be handled by ON DELETE CASCADE or explicit cleanup
  // For MVP, just deleting user is enough if DB allows or we soft delete.
  // Assuming hard delete for "Trace Erasure"

  // Clean up Redis keys optionally

  await query('DELETE FROM yeope_schema.users WHERE id = $1', [userId]);
  return true;
};

/**
 * 닉네임 마스크 재생성 (랜덤) + 정보 초기화 + 방 나가기
 */
const regenerateMask = async (userId) => {
  // 1. Leave All Rooms
  const roomService = require('./roomService');
  await roomService.leaveAllRooms(userId, 'reset');

  // 2. Reset Info (Nickname, Profile Image) & Update Mask (Retry logic for collision)
  let retries = 0;
  const MAX_RETRIES = 5;

  while (retries < MAX_RETRIES) {
    try {
      // Generate random 8-char alphanumeric string (base36)
      // Math.random().toString(36) returns '0.xxxxx...' containing a-z,0-9
      const randomString = Math.random().toString(36).substring(2, 10).toUpperCase();
      const newMask = randomString;

      await query(
        `UPDATE yeope_schema.users 
         SET nickname_mask = $1, 
             nickname = NULL, 
             profile_image_url = NULL 
         WHERE id = $2`,
        [newMask, userId]
      );

      return await getUserProfile(userId);
    } catch (error) {
      if (error.code === '23505') { // Unique violation
        retries++;
        logger.warn(`Nickname mask collision (Random...), retrying (${retries}/${MAX_RETRIES})`);
        continue;
      }
      throw error;
    }
  }

  throw new Error('Failed to generate unique nickname mask after retries');
};

/**
 * 사용자 차단
 */
/**
 * 사용자 차단 (닉네임 스냅샷 저장)
 */
const blockUser = async (blockerId, blockedId) => {
  if (blockerId === blockedId) {
    throw new ValidationError('자신을 차단할 수 없습니다');
  }

  // Check existence
  const blockedUser = await findUserById(blockedId);
  if (!blockedUser) {
    throw new NotFoundError('차단할 사용자를 찾을 수 없습니다');
  }

  // Snapshot Nickname (Use Mask or Nickname)
  const snapshotNickname = blockedUser.nickname_mask || blockedUser.nickname || 'Unknown';

  // Insert ignore duplicates
  await query(
    `INSERT INTO yeope_schema.blocked_users (blocker_id, blocked_id, blocked_nickname) 
     VALUES ($1, $2, $3) 
     ON CONFLICT (blocker_id, blocked_id) DO NOTHING`,
    [blockerId, blockedId, snapshotNickname]
  );

  // Leave shared 1:1 rooms
  try {
    const activeRooms = await query(
      `SELECT room_id FROM yeope_schema.rooms 
       WHERE is_active = true 
       AND (
         (creator_id = $1 AND metadata->>'inviteeId' = $2) 
         OR 
         (creator_id = $2 AND metadata->>'inviteeId' = $1)
       )`,
      [blockerId, blockedId]
    );

    if (activeRooms.rows.length > 0) {
      const roomService = require('./roomService');
      for (const room of activeRooms.rows) {
        await roomService.leaveRoom(blockerId, room.room_id);
        // We only exit the blocker? User said "I should exit".
        // Usually breaking the link is enough. The other user remains alone.
      }
      logger.info(`Blocked user ${blockedId}: Left ${activeRooms.rows.length} shared rooms.`);
    }
  } catch (err) {
    logger.warn(`Failed to leave rooms during block: ${err.message}`);
  }

  return true;
};

/**
 * 사용자 차단 해제
 */
const unblockUser = async (blockerId, blockedId) => {
  await query(
    'DELETE FROM yeope_schema.blocked_users WHERE blocker_id = $1 AND blocked_id = $2',
    [blockerId, blockedId]
  );
  return true;
};

/**
 * 차단 목록 조회 (스냅샷 닉네임 반환)
 */
const getBlockedUsers = async (userId) => {
  const result = await query(
    `SELECT 
       b.blocked_id as id, 
       COALESCE(b.blocked_nickname, u.nickname_mask, u.nickname) as display_name,
       u.nickname_mask,
       b.created_at
     FROM yeope_schema.blocked_users b
     LEFT JOIN yeope_schema.users u ON b.blocked_id = u.id
     WHERE b.blocker_id = $1
     ORDER BY b.created_at DESC`,
    [userId]
  );

  return result.rows.map(row => ({
    id: row.id,
    nickname: row.display_name, // Client expects 'nickname' or 'displayName'
    nicknameMask: row.nickname_mask,
    blockedAt: row.created_at
  }));
};

/**
 * 사용자 신고
 */
const reportUser = async (reporterId, reportedId, reason, details) => {
  if (reporterId === reportedId) {
    throw new ValidationError('자신을 신고할 수 없습니다');
  }

  await query(
    `INSERT INTO yeope_schema.reports (reporter_id, reported_id, reason, details)
     VALUES ($1, $2, $3, $4)`,
    [reporterId, reportedId, reason, details || '']
  );

  // --- Auto-Block Logic (Policy: Report = Block) ---
  try {
    // 신고와 동시에 차단 처리 (상호 레이더 은신, 1:1 방 나가기)
    await blockUser(reporterId, reportedId);
    logger.info(`User ${reporterId} auto-blocked ${reportedId} upon reporting.`);
  } catch (err) {
    logger.warn(`Auto-block failed during report: ${err.message}`);
  }

  // --- Auto-Blind Logic (Stage 1: Blind on 1st Report) ---
  try {
    // "선 차단, 후 심사" - 1회 신고 시 즉시 under_review 상태로 변경하여 레이더에서 은신
    // 단, 이미 suspended/banned 상태인 경우 변경하지 않음
    await query(
      `UPDATE yeope_schema.users 
       SET status = 'under_review' 
       WHERE id = $1 AND status = 'active'`,
      [reportedId]
    );
    logger.warn(`User ${reportedId} set to 'under_review' (BLIND) due to a report.`);
  } catch (err) {
    logger.error(`Failed to apply Auto-Blind: ${err.message}`);
  }

  // --- Auto-Ban Logic (Stage 1) ---
  const REPORT_THRESHOLD = 3;
  const SUSPENSION_HOURS = 24;

  const countResult = await query(
    `SELECT COUNT(DISTINCT reporter_id) as report_count 
     FROM yeope_schema.reports 
     WHERE reported_id = $1 
     AND created_at > NOW() - INTERVAL '24 hours'`,
    [reportedId]
  );

  const reportCount = parseInt(countResult.rows[0].report_count || 0);

  if (reportCount >= REPORT_THRESHOLD) {
    // Check if already suspended to avoid resetting timer repeatedly or check status
    const userStatus = await query('SELECT status FROM yeope_schema.users WHERE id = $1', [reportedId]);
    if (userStatus.rows[0].status !== 'suspended' && userStatus.rows[0].status !== 'banned') {

      // Fetch Global Settings
      const settingsService = require('./settingsService');
      const durationStr = await settingsService.getValue('suspension_duration_hours', '24');
      const reason = await settingsService.getValue('suspension_reason', JSON.stringify({
        ko: '누적된 신고로 인해 시스템에 의해 자동으로 정지되었습니다.',
        en: 'Automatically suspended by the system due to accumulated reports.'
      }));
      const hours = parseInt(durationStr, 10) || 24;

      await query(
        `UPDATE yeope_schema.users 
         SET status = 'suspended', 
             suspended_until = NOW() + INTERVAL '${hours} hours',
             suspension_reason = $2
         WHERE id = $1`,
        [reportedId, reason]
      );
      logger.warn(`User ${reportedId} has been AUTO-SUSPENDED for ${hours}h due to ${reportCount} reports. Reason: ${reason}`);
    }
  }

  return true;
};

/**
 * 사용자 정지 (Temporary Suspension)
 */
const suspendUser = async (userId, hours, reason) => {
  // If reason is an object (multilingual), stringify it
  const reasonStr = typeof reason === 'object' ? JSON.stringify(reason) : reason;

  await query(
    `UPDATE yeope_schema.users 
     SET status = 'suspended', 
         suspended_until = NOW() + INTERVAL '${hours} hours',
         suspension_reason = $2
     WHERE id = $1`,
    [userId, reasonStr]
  );
  logger.warn(`User ${userId} SUSPENDED for ${hours}h by admin. Reason: ${reasonStr}`);
  return true;
};

/**
 * 사용자 차단 (Permanent Ban / Deactivation)
 */
const banUser = async (userId, reason) => {
  // If reason is an object (multilingual), stringify it
  const reasonStr = typeof reason === 'object' ? JSON.stringify(reason) : reason;

  await query(
    `UPDATE yeope_schema.users 
     SET is_active = false, 
         suspension_reason = $2 
     WHERE id = $1`,
    [userId, reasonStr]
  );
  logger.warn(`User ${userId} BANNED by admin. Reason: ${reasonStr}`);
  return true;
};

/**
 * 사용자 정지 해제 (Admin)
 */
const unsuspendUser = async (userId) => {
  await query(
    `UPDATE yeope_schema.users 
     SET status = 'active', 
         suspended_until = NULL,
         suspension_reason = NULL
     WHERE id = $1`,
    [userId]
  );
  logger.info(`User ${userId} has been UNSUSPENDED by admin.`);
  return true;
};

/**
 * 사용자 차단 해제 (Activation)
 */
const unbanUser = async (userId) => {
  await query(
    `UPDATE yeope_schema.users 
     SET is_active = true, 
         suspension_reason = NULL 
     WHERE id = $1`,
    [userId]
  );
  logger.info(`User ${userId} has been UNBANNED (Activated) by admin.`);
  return true;
};

/**
 * 사용자 신고 내역 초기화 (Admin)
 */
const clearReports = async (userId) => {
  await query('DELETE FROM yeope_schema.reports WHERE reported_id = $1', [userId]);
  logger.info(`Reports for user ${userId} have been cleared by admin.`);
  return true;
};

/**
 * 사용자 전화번호 업데이트 (본인인증)
 */
const updateUserPhoneNumber = async (userId, phoneNumber) => {
  // 중복 체크 (이미 다른 계정에 연동된 번호인지)
  const existing = await query(
    'SELECT id FROM yeope_schema.users WHERE phone_number = $1',
    [phoneNumber]
  );

  if (existing.rows.length > 0 && existing.rows[0].id !== userId) {
    throw new ValidationError('이미 다른 계정에 등록된 전화번호입니다.');
  }

  await query(
    'UPDATE yeope_schema.users SET phone_number = $1 WHERE id = $2',
    [phoneNumber, userId]
  );

  return true;
};

/**
 * 구제 신청 생성
 */
const createAppeal = async (userId, reason) => {
  // 이미 진행 중인 신청이 있는지 확인
  const existing = await query(
    "SELECT id FROM yeope_schema.appeals WHERE user_id = $1 AND status = 'pending'",
    [userId]
  );

  if (existing.rows.length > 0) {
    throw new ValidationError('이미 진행 중인 구제 신청이 있습니다. 관리자 승인을 기다려주세요.');
  }

  await query(
    'INSERT INTO yeope_schema.appeals (user_id, reason) VALUES ($1, $2)',
    [userId, reason]
  );
  return true;
};

/**
 * 구제 신청 목록 조회 (Admin)
 */
const getAppeals = async (status = 'pending') => {
  const result = await query(`
    SELECT a.*, u.email, u.nickname, u.nickname_mask, u.status as user_status, u.suspended_until
    FROM yeope_schema.appeals a
    JOIN yeope_schema.users u ON a.user_id = u.id
    WHERE a.status = $1
    ORDER BY a.created_at DESC
  `, [status]);
  return result.rows;
};

/**
 * 구제 신청 처리 (Admin)
 */
const resolveAppeal = async (appealId, status, adminComment) => {
  if (!['approved', 'rejected'].includes(status)) {
    throw new ValidationError('Invalid status');
  }

  const appealRes = await query(
    'UPDATE yeope_schema.appeals SET status = $1, admin_comment = $2, updated_at = NOW() WHERE id = $3 RETURNING user_id',
    [status, adminComment, appealId]
  );

  if (appealRes.rows.length === 0) {
    throw new NotFoundError('Appeal not found');
  }

  // 승인 시 자동 정지 및 차단 해제 (완전 복구)
  if (status === 'approved') {
    const userId = appealRes.rows[0].user_id;

    // Force Activate & Unsuspend
    await query(
      `UPDATE yeope_schema.users 
         SET status = 'active', 
             is_active = true,
             suspended_until = NULL,
             suspension_reason = NULL
         WHERE id = $1`,
      [userId]
    );
    logger.info(`User ${userId} restored via Appeal Approval.`);
  }

  return true;
};

// Re-export with new additions
module.exports = {
  findUserByEmail,
  findUserById,
  createUser,
  loginUser,
  getUserProfile,
  verifyPassword,
  updateUser,
  loginSocialUser,
  deleteUser,
  regenerateMask,
  blockUser,
  unblockUser,
  getBlockedUsers,
  reportUser,
  unsuspendUser,
  suspendUser,
  banUser,
  unbanUser,
  clearReports,
  updateUserPhoneNumber, // Added back to main exports
  createAppeal,
  getAppeals,
  resolveAppeal
};

// touch
