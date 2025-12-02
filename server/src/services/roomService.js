/**
 * 방(Room) 서비스
 */

const crypto = require('crypto');
const { query, transaction } = require('../config/database');
const { ValidationError, NotFoundError, AuthorizationError } = require('../utils/errors');
const logger = require('../utils/logger');

/**
 * 방 생성
 */
const createRoom = async (userId, name, category = 'general') => {
  const roomId = crypto.randomUUID();
  const expiresAt = new Date();
  expiresAt.setHours(expiresAt.getHours() + 24); // 24시간 후 만료

  const result = await query(
    `INSERT INTO yeope_schema.rooms 
     (room_id, name, creator_id, expires_at, member_count, is_active, metadata)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING id, room_id, name, creator_id, created_at, expires_at, member_count, metadata`,
    [
      roomId,
      name,
      userId,
      expiresAt,
      1, // 생성자 포함
      true,
      JSON.stringify({ category })
    ]
  );

  const room = result.rows[0];

  // 생성자를 방 멤버로 추가
  await query(
    `INSERT INTO yeope_schema.room_members 
     (room_id, user_id, role, last_seen_at)
     VALUES ($1, $2, $3, NOW())`,
    [room.id, userId, 'creator']
  );

  logger.info(`방 생성: ${roomId} by user ${userId}`);

  return {
    id: room.id,
    roomId: room.room_id,
    name: room.name,
    creatorId: room.creator_id,
    createdAt: room.created_at,
    expiresAt: room.expires_at,
    memberCount: room.member_count,
    metadata: typeof room.metadata === 'string'
      ? JSON.parse(room.metadata)
      : room.metadata
  };
};



/**
 * 중복 방 이름 확인
 */
const checkDuplicateRoom = async (name, creatorIds) => {
  if (!creatorIds || creatorIds.length === 0) return null;

  const result = await query(
    `SELECT * FROM yeope_schema.rooms 
     WHERE name = $1 
       AND creator_id = ANY($2) 
       AND is_active = true 
       AND expires_at > NOW()
     LIMIT 1`,
    [name, creatorIds]
  );

  return result.rows[0] || null;
};

/**
 * 방 ID로 방 조회
 */
const findRoomByRoomId = async (roomId) => {
  const result = await query(
    `SELECT * FROM yeope_schema.rooms 
     WHERE room_id = $1 AND is_active = true`,
    [roomId]
  );
  return result.rows[0] || null;
};

/**
 * 방 ID로 방 조회 (UUID)
 */
const findRoomById = async (id) => {
  const result = await query(
    `SELECT * FROM yeope_schema.rooms 
     WHERE id = $1 AND is_active = true`,
    [id]
  );
  return result.rows[0] || null;
};

/**
 * 활성 방 목록 조회 (근처 방 목록)
 */
const getActiveRooms = async (options = {}) => {
  const { limit = 10, category, before } = options;

  let queryText = `
    SELECT r.*, u.nickname_mask as creator_nickname_mask
    FROM yeope_schema.rooms r
    LEFT JOIN yeope_schema.users u ON r.creator_id = u.id
    WHERE r.is_active = true 
      AND r.expires_at > NOW()
  `;

  const params = [];
  let paramIndex = 1;

  if (category) {
    queryText += ` AND r.metadata->>'category' = $${paramIndex}`;
    params.push(category);
    paramIndex++;
  }

  if (before) {
    queryText += ` AND r.created_at < $${paramIndex}`;
    params.push(before);
    paramIndex++;
  }

  queryText += ` ORDER BY r.created_at DESC LIMIT $${paramIndex}`;
  params.push(limit);

  const result = await query(queryText, params);

  return result.rows.map(room => ({
    id: room.id,
    roomId: room.room_id,
    name: room.name,
    creatorId: room.creator_id,
    creatorNicknameMask: room.creator_nickname_mask,
    createdAt: room.created_at,
    expiresAt: room.expires_at,
    memberCount: room.member_count,
    metadata: typeof room.metadata === 'string'
      ? JSON.parse(room.metadata)
      : room.metadata
  }));
};

/**
 * 방 상세 정보 조회
 */
const getRoomDetails = async (roomId) => {
  const room = await findRoomByRoomId(roomId);

  if (!room) {
    throw new NotFoundError('방을 찾을 수 없습니다');
  }

  // 만료된 방인지 확인
  if (new Date(room.expires_at) < new Date()) {
    throw new NotFoundError('만료된 방입니다');
  }

  return {
    id: room.id,
    roomId: room.room_id,
    name: room.name,
    creatorId: room.creator_id,
    createdAt: room.created_at,
    expiresAt: room.expires_at,
    memberCount: room.member_count,
    isActive: room.is_active,
    metadata: typeof room.metadata === 'string'
      ? JSON.parse(room.metadata)
      : room.metadata
  };
};

/**
 * 방 참여
 */
const joinRoom = async (userId, roomId) => {
  const room = await findRoomByRoomId(roomId);

  if (!room) {
    throw new NotFoundError('방을 찾을 수 없습니다');
  }

  // 만료된 방인지 확인
  if (new Date(room.expires_at) < new Date()) {
    throw new ValidationError('만료된 방입니다');
  }

  // 이미 참여 중인지 확인
  const existingMember = await query(
    `SELECT * FROM yeope_schema.room_members 
     WHERE room_id = $1 AND user_id = $2 AND left_at IS NULL`,
    [room.id, userId]
  );

  if (existingMember.rows.length > 0) {
    // 이미 참여 중이면 last_seen_at만 업데이트
    await query(
      `UPDATE yeope_schema.room_members 
       SET last_seen_at = NOW() 
       WHERE room_id = $1 AND user_id = $2 AND left_at IS NULL`,
      [room.id, userId]
    );
    return { alreadyJoined: true };
  }

  // 트랜잭션으로 방 참여 처리
  await transaction(async (client) => {
    // 방 멤버 추가
    await client.query(
      `INSERT INTO yeope_schema.room_members 
       (room_id, user_id, role, last_seen_at)
       VALUES ($1, $2, $3, NOW())`,
      [room.id, userId, 'member']
    );

    // 멤버 수 증가
    await client.query(
      `UPDATE yeope_schema.rooms 
       SET member_count = member_count + 1 
       WHERE id = $1`,
      [room.id]
    );
  });

  logger.info(`사용자 ${userId}가 방 ${roomId}에 참여`);

  return { alreadyJoined: false };
};

/**
 * 방 나가기
 */
const leaveRoom = async (userId, roomId) => {
  const room = await findRoomByRoomId(roomId);

  if (!room) {
    throw new NotFoundError('방을 찾을 수 없습니다');
  }

  // 참여 중인지 확인
  const member = await query(
    `SELECT * FROM yeope_schema.room_members 
     WHERE room_id = $1 AND user_id = $2 AND left_at IS NULL`,
    [room.id, userId]
  );

  if (member.rows.length === 0) {
    throw new ValidationError('참여 중인 방이 아닙니다');
  }

  // 트랜잭션으로 방 나가기 처리
  await transaction(async (client) => {
    // left_at 업데이트
    await client.query(
      `UPDATE yeope_schema.room_members 
       SET left_at = NOW() 
       WHERE room_id = $1 AND user_id = $2 AND left_at IS NULL`,
      [room.id, userId]
    );

    // 멤버 수 감소
    await client.query(
      `UPDATE yeope_schema.rooms 
       SET member_count = GREATEST(member_count - 1, 0) 
       WHERE id = $1`,
      [room.id]
    );
  });

  logger.info(`사용자 ${userId}가 방 ${roomId}에서 나감`);

  return { success: true };
};

/**
 * 방 멤버 목록 조회
 */
const getRoomMembers = async (roomId) => {
  const room = await findRoomByRoomId(roomId);

  if (!room) {
    throw new NotFoundError('방을 찾을 수 없습니다');
  }

  const result = await query(
    `SELECT rm.*, u.nickname_mask, u.nickname
     FROM yeope_schema.room_members rm
     JOIN yeope_schema.users u ON rm.user_id = u.id
     WHERE rm.room_id = $1 AND rm.left_at IS NULL
     ORDER BY rm.joined_at ASC`,
    [room.id]
  );

  return result.rows.map(member => ({
    userId: member.user_id,
    nickname: member.nickname,
    nicknameMask: member.nickname_mask,
    role: member.role,
    joinedAt: member.joined_at,
    lastSeenAt: member.last_seen_at
  }));
};

/**
 * 사용자가 참여 중인 방 목록 조회
 */
const getUserRooms = async (userId) => {
  const result = await query(
    `SELECT r.*, rm.role, rm.joined_at, rm.last_seen_at
     FROM yeope_schema.rooms r
     JOIN yeope_schema.room_members rm ON r.id = rm.room_id
     WHERE rm.user_id = $1 
       AND rm.left_at IS NULL 
       AND r.is_active = true
       AND r.expires_at > NOW()
     ORDER BY rm.last_seen_at DESC`,
    [userId]
  );

  return result.rows.map(room => ({
    id: room.id,
    roomId: room.room_id,
    name: room.name,
    role: room.role,
    memberCount: room.member_count,
    joinedAt: room.joined_at,
    lastSeenAt: room.last_seen_at,
    expiresAt: room.expires_at,
    metadata: typeof room.metadata === 'string'
      ? JSON.parse(room.metadata)
      : room.metadata
  }));
};

module.exports = {
  createRoom,
  checkDuplicateRoom,
  findRoomByRoomId,
  findRoomById,
  getActiveRooms,
  getRoomDetails,
  joinRoom,
  leaveRoom,
  getRoomMembers,
  getUserRooms
};

