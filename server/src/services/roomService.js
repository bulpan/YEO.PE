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
const createRoom = async (userId, name, category = 'general', inviteeId = null) => {
  const roomId = crypto.randomUUID();
  const expiresAt = new Date();
  expiresAt.setHours(expiresAt.getHours() + 24); // 24시간 후 만료

  const isActive = !inviteeId; // 초대자가 있으면 비활성 상태로 시작
  const metadata = { category };
  if (inviteeId) {
    metadata.inviteeId = inviteeId;
  }

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
      isActive,
      JSON.stringify(metadata)
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

  logger.info(`방 생성: ${roomId} by user ${userId} (Invitee: ${inviteeId || 'None'})`);

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
const findRoomByRoomId = async (roomId, includeInactive = false) => {
  let queryText = `SELECT * FROM yeope_schema.rooms WHERE room_id = $1`;
  if (!includeInactive) {
    queryText += ` AND is_active = true`;
  }

  const result = await query(queryText, [roomId]);
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
  // Use a joined query to fetch nickname info for dynamic titles
  const result = await query(
    `SELECT r.*, 
            u_creator.nickname as creator_nickname,
            u_creator.nickname_mask as creator_nickname_mask,
            u_invitee.nickname as invitee_nickname,
            u_invitee.nickname_mask as invitee_nickname_mask
     FROM yeope_schema.rooms r
     LEFT JOIN yeope_schema.users u_creator ON r.creator_id = u_creator.id
     LEFT JOIN yeope_schema.users u_invitee ON (r.metadata->>'inviteeId')::uuid = u_invitee.id
     WHERE r.room_id = $1`,
    [roomId]
  );

  const room = result.rows[0];

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
    creatorId: room.creator_id,
    creatorNickname: room.creator_nickname_mask || room.creator_nickname,
    creatorNicknameMask: room.creator_nickname_mask,
    inviteeNickname: room.invitee_nickname_mask || room.invitee_nickname,
    inviteeNicknameMask: room.invitee_nickname_mask,
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
  const room = await findRoomByRoomId(roomId, true); // 비활성 방도 조회

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

  // 1:1 초대 방 로직 (비활성 방은 초대된 사용자만 입장 가능)
  if (!room.is_active) {
    const metadata = typeof room.metadata === 'string' ? JSON.parse(room.metadata) : room.metadata;
    if (metadata && metadata.inviteeId) {
      if (metadata.inviteeId !== userId) {
        throw new AuthorizationError('이 방은 초대된 사용자만 입장할 수 있습니다.');
      }
      // 초대된 사용자가 입장하면 방 활성화 로직은 아래 트랜잭션에서 처리
    } else {
      // 초대장이 없는데 비활성? 이상하지만 일단 진행하지 않음
      throw new ValidationError('비활성화된 방입니다.');
    }
  }

  // 트랜잭션으로 방 참여 처리
  const transactionResult = await transaction(async (client) => {
    // 방 멤버 추가
    await client.query(
      `INSERT INTO yeope_schema.room_members 
       (room_id, user_id, role, last_seen_at)
       VALUES ($1, $2, $3, NOW())`,
      [room.id, userId, 'member']
    );

    // 멤버 수 증가 및 방 활성화 (필요 시)
    let updateQuery = `UPDATE yeope_schema.rooms SET member_count = member_count + 1`;
    const params = [room.id];

    // 비활성 상태이고 초대된 사용자가 들어오는 경우 활성화
    if (!room.is_active) {
      updateQuery += `, is_active = true`;
    }

    updateQuery += ` WHERE id = $1`;

    await client.query(updateQuery, params);
    // 시스템 메시지 추가 (참여 알림)
    const userRes = await client.query('SELECT nickname_mask FROM yeope_schema.users WHERE id = $1', [userId]);
    const nickname = userRes.rows[0]?.nickname_mask || 'Anonymous';
    const systemContent = `${nickname} joined the room.`;

    const msgResult = await client.query(
      `INSERT INTO yeope_schema.messages 
       (room_id, user_id, type, content, created_at, expires_at)
       VALUES ($1, $2, 'system', $3, NOW(), (SELECT expires_at FROM yeope_schema.rooms WHERE id = $1))
       RETURNING id, created_at`,
      [room.id, userId, systemContent]
    );

    const messageId = msgResult.rows[0].id;
    const createdAt = msgResult.rows[0].created_at;

    return {
      alreadyJoined: false,
      systemMessage: {
        messageId,
        roomId: room.room_id,
        userId,
        nickname, // Include nickname for client display
        type: 'system',
        content: systemContent,
        createdAt
      }
    };
  });

  logger.info(`사용자 ${userId}가 방 ${roomId}에 참여 (Activated: ${!room.is_active})`);

  return transactionResult;
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
  const transactionResult = await transaction(async (client) => {
    // 1. 사용자 닉네임 조회 (시스템 메시지용)
    const userRes = await client.query('SELECT nickname_mask FROM yeope_schema.users WHERE id = $1', [userId]);
    const nickname = userRes.rows[0]?.nickname_mask || 'Anonymous';

    // 2. 사용자의 모든 메시지 삭제 (Evaporation)
    await client.query(
      `DELETE FROM yeope_schema.messages 
       WHERE room_id = $1 AND user_id = $2`,
      [room.id, userId]
    );

    // 3. 시스템 메시지 추가 (증발 알림)
    const systemContent = `${nickname}'s messages have evaporated.`;
    // 한글: `${nickname}님의 대화내용이 증발했습니다.` (클라이언트에서 로컬라이징하거나 서버에서 처리. 여기선 영어로 저장하고 클라이언트가 type=system일 때 처리 권장하지만, 요구사항이 "표기"이므로 텍스트 저장)
    // 요구사항: "**명의 대화내용이 증발했습니다", "**명이 방에서 사라졌습니다"
    // 여기서는 메시지 삭제 후 "증발했습니다" 메시지 삽입.

    const msgResult = await client.query(
      `INSERT INTO yeope_schema.messages 
       (room_id, user_id, type, content, created_at, expires_at)
       VALUES ($1, $2, 'system', $3, NOW(), $4)
       RETURNING id`,
      [room.id, userId, systemContent, room.expires_at]
    );

    const messageId = msgResult.rows[0].id;

    // 4. 중복 참여 세션 정리 (Race Condition으로 인해 중복된 active session이 있을 경우 대비)
    // unique_room_user_active 제약조건(room_id, user_id, left_at)이 left_at=NULL 중복을 허용하므로
    // 여러 active row가 있을 수 있음. 이들을 한 번에 NOW()로 업데이트하면 제약조건 위반 발생.
    // 따라서 하나만 남기고 나머지는 삭제.
    await client.query(
      `DELETE FROM yeope_schema.room_members
       WHERE id IN (
         SELECT id FROM yeope_schema.room_members
         WHERE room_id = $1 AND user_id = $2 AND left_at IS NULL
         ORDER BY joined_at DESC
         OFFSET 1
       )`,
      [room.id, userId]
    );

    // 4-2. left_at 업데이트 (남은 1개 행에 대해)
    await client.query(
      `UPDATE yeope_schema.room_members 
       SET left_at = NOW() 
       WHERE room_id = $1 AND user_id = $2 AND left_at IS NULL`,
      [room.id, userId]
    );

    // 5. 멤버 수 감소
    await client.query(
      `UPDATE yeope_schema.rooms 
       SET member_count = GREATEST(member_count - 1, 0) 
       WHERE id = $1`,
      [room.id]
    );

    // 6. 방장이 나가거나 멤버가 0명이면 방 종료 (만료 처리)
    if (room.creator_id === userId) {
      await client.query(
        `UPDATE yeope_schema.rooms 
             SET is_active = false, expires_at = NOW() 
             WHERE id = $1`,
        [room.id]
      );
      logger.info(`방장이 나가서 방 종료: ${room.room_id}`);
    } else {
      // 멤버가 0명이면 종료
      const countRes = await client.query('SELECT member_count FROM yeope_schema.rooms WHERE id = $1', [room.id]);
      if (countRes.rows[0].member_count === 0) {
        await client.query(
          `UPDATE yeope_schema.rooms 
                 SET is_active = false, expires_at = NOW() 
                 WHERE id = $1`,
          [room.id]
        );
        logger.info(`멤버가 0명이라 방 종료: ${room.room_id}`);
      }
    }

    // Return system message for socket broadcast
    return {
      success: true,
      systemMessage: {
        messageId,
        roomId: room.room_id, // Use room_id (UUID) for client
        userId: userId,
        type: 'system',
        content: systemContent,
        createdAt: new Date()
      },
      leftUserId: userId
    };
  });

  // Transaction returns the result of the callback
  return transactionResult;
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
    nickname: member.nickname_mask || member.nickname,
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
  // 1. 참여 중인 방 (Active or Inactive if creator)
  // 2. 초대받은 방 (Inactive & inviteeId match)
  const result = await query(
    `SELECT DISTINCT r.*, 
            COALESCE(rm.role, 'invitee') as role, 
            COALESCE(rm.joined_at, r.created_at) as joined_at, 
            COALESCE(rm.last_seen_at, r.created_at) as last_seen_at,
            u_creator.nickname as creator_nickname,
            u_creator.nickname_mask as creator_nickname_mask,
            u_invitee.nickname as invitee_nickname,
            u_invitee.nickname_mask as invitee_nickname_mask,
            (SELECT COUNT(*)::int FROM yeope_schema.messages m 
             WHERE m.room_id = r.id 
               AND m.created_at > COALESCE(rm.last_seen_at, r.created_at)
               AND m.is_deleted = false
            ) as unread_count,
            (SELECT content FROM yeope_schema.messages m 
             WHERE m.room_id = r.id AND m.is_deleted = false
             ORDER BY m.created_at DESC LIMIT 1
            ) as last_message
     FROM yeope_schema.rooms r
     LEFT JOIN (
       SELECT DISTINCT ON (room_id) *
       FROM yeope_schema.room_members
       WHERE user_id = $1 AND left_at IS NULL
       ORDER BY room_id, joined_at DESC
     ) rm ON r.id = rm.room_id
     LEFT JOIN yeope_schema.users u_creator ON r.creator_id = u_creator.id
     LEFT JOIN yeope_schema.users u_invitee ON (r.metadata->>'inviteeId')::uuid = u_invitee.id
     WHERE (rm.user_id IS NOT NULL AND r.expires_at > NOW())
        OR ((r.metadata->>'inviteeId')::uuid = $1 AND r.is_active = false AND r.expires_at > NOW())
     ORDER BY last_seen_at DESC`,
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
    isActive: room.is_active,
    unreadCount: room.unread_count,
    lastMessage: room.last_message,
    creatorId: room.creator_id,
    creatorNickname: room.creator_nickname_mask || room.creator_nickname, // Add creator info
    creatorNicknameMask: room.creator_nickname_mask,
    inviteeNickname: room.invitee_nickname_mask || room.invitee_nickname, // Add invitee info
    inviteeNicknameMask: room.invitee_nickname_mask,
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

