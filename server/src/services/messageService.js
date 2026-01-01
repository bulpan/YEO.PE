/**
 * 메시지 서비스
 */

const { query, transaction } = require('../config/database');
const { ValidationError, NotFoundError, AuthorizationError } = require('../utils/errors');
const logger = require('../utils/logger');
const roomService = require('./roomService');
const userService = require('./userService');

/**
 * 메시지 생성
 */
const createMessage = async (userId, roomId, type, content, imageUrl = null) => {
  // 방 존재 확인 (비활성 방도 허용 - 1:1 초대 대기 상태 등)
  const room = await roomService.findRoomByRoomId(roomId, true);

  if (!room) {
    throw new NotFoundError('방을 찾을 수 없습니다');
  }

  // 만료된 방인지 확인
  if (new Date(room.expires_at) < new Date()) {
    throw new ValidationError('만료된 방입니다');
  }

  // 사용자가 방에 참여 중인지 확인
  const member = await query(
    `SELECT * FROM yeope_schema.room_members 
     WHERE room_id = $1 AND user_id = $2 AND left_at IS NULL`,
    [room.id, userId]
  );

  if (member.rows.length === 0) {
    throw new AuthorizationError('방에 참여 중이 아닙니다');
  }

  // 메시지 타입 검증
  const validTypes = ['text', 'image', 'emoji'];
  if (!validTypes.includes(type)) {
    throw new ValidationError('유효하지 않은 메시지 타입입니다');
  }

  // 텍스트 메시지 길이 검증
  if (type === 'text' && (!content || content.trim().length === 0)) {
    throw new ValidationError('메시지 내용을 입력해주세요');
  }

  if (type === 'text' && content.length > 1000) {
    throw new ValidationError('메시지는 1000자 이하여야 합니다');
  }

  // 이미지 타입인 경우 imageUrl 필수
  if (type === 'image' && !imageUrl) {
    throw new ValidationError('이미지 URL이 필요합니다');
  }

  // 만료 시간 설정 (방과 동일하게 24시간)
  const expiresAt = new Date(room.expires_at);

  // 메시지 저장
  const result = await query(
    `INSERT INTO yeope_schema.messages 
     (room_id, user_id, type, content, image_url, expires_at)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id, room_id, user_id, type, content, image_url, created_at, expires_at`,
    [room.id, userId, type, content, imageUrl, expiresAt]
  );

  // [Fix] Self-Message Unread Bug: Update Sender's last_seen_at immediately
  await query(
    `UPDATE yeope_schema.room_members 
     SET last_seen_at = NOW() 
     WHERE room_id = $1 AND user_id = $2`,
    [room.id, userId]
  );

  const message = result.rows[0];

  // 사용자 정보 조회
  const user = await userService.findUserById(userId);

  logger.info(`메시지 생성: ${message.id} in room ${roomId} by user ${userId}`);

  return {
    messageId: message.id,
    roomId: room.room_id,
    userId: message.user_id,
    nickname: user.nickname_mask || user.nickname,
    nicknameMask: user.nickname_mask || require('../utils/nickname').maskNickname(user.nickname),
    type: message.type,
    content: message.content,
    imageUrl: message.image_url,
    imageUrl: message.image_url,
    createdAt: message.created_at,
    roomMetadata: typeof room.metadata === 'string' ? JSON.parse(room.metadata) : room.metadata
  };
};

/**
 * 메시지 목록 조회
 */
const getMessages = async (roomId, options = {}) => {
  const { limit = 50, before } = options;

  // 방 존재 확인 (비활성 방도 허용)
  const room = await roomService.findRoomByRoomId(roomId, true);

  if (!room) {
    throw new NotFoundError('방을 찾을 수 없습니다');
  }

  let queryText = `
    SELECT m.*, u.nickname, u.nickname_mask
    FROM yeope_schema.messages m
    JOIN yeope_schema.users u ON m.user_id = u.id
    WHERE m.room_id = $1 AND m.is_deleted = false
  `;

  const params = [room.id];
  let paramIndex = 2;

  if (before) {
    queryText += ` AND m.created_at < $${paramIndex}`;
    params.push(before);
    paramIndex++;
  }

  queryText += ` ORDER BY m.created_at DESC LIMIT $${paramIndex}`;
  params.push(limit);

  const result = await query(queryText, params);

  // 최신 메시지가 먼저 오도록 정렬 (역순)
  const messages = result.rows.reverse().map(msg => ({
    messageId: msg.id,
    userId: msg.user_id,
    nickname: msg.nickname_mask || msg.nickname,
    nicknameMask: msg.nickname_mask,
    type: msg.type,
    content: msg.content,
    imageUrl: msg.image_url,
    createdAt: msg.created_at
  }));

  return {
    messages,
    hasMore: result.rows.length === limit
  };
};

/**
 * 메시지 삭제 (소프트 삭제)
 */
const deleteMessage = async (userId, messageId) => {
  // 메시지 조회
  const result = await query(
    `SELECT * FROM yeope_schema.messages 
     WHERE id = $1 AND is_deleted = false`,
    [messageId]
  );

  if (result.rows.length === 0) {
    throw new NotFoundError('메시지를 찾을 수 없습니다');
  }

  const message = result.rows[0];

  // 본인 메시지인지 확인
  if (message.user_id !== userId) {
    throw new AuthorizationError('본인의 메시지만 삭제할 수 있습니다');
  }

  // 소프트 삭제
  await query(
    `UPDATE yeope_schema.messages 
     SET is_deleted = true 
     WHERE id = $1`,
    [messageId]
  );

  logger.info(`메시지 삭제: ${messageId} by user ${userId}`);

  return { success: true };
};

module.exports = {
  createMessage,
  getMessages,
  deleteMessage
};





