/**
 * TTL 관리 서비스
 * 24시간 후 만료된 방과 메시지를 자동으로 삭제
 */

const cron = require('node-cron');
const { query } = require('../config/database');
const logger = require('../utils/logger');
const bleService = require('./bleService');

/**
 * 만료된 방과 메시지 삭제
 */
const cleanupExpiredData = async () => {
  try {
    logger.info('만료된 데이터 정리 시작...');

    // 트랜잭션으로 처리
    await query('BEGIN');

    // 1. 만료된 메시지 아카이빙
    const msgArchiveResult = await query(
      `INSERT INTO yeope_schema.archived_messages (id, room_id, user_id, type, content, image_url, created_at, expires_at)
       SELECT id, room_id, user_id, type, content, image_url, created_at, expires_at
       FROM yeope_schema.messages
       WHERE expires_at < NOW()`
    );
    if (msgArchiveResult.rowCount > 0) {
      logger.info(`메시지 ${msgArchiveResult.rowCount}개 아카이브 이동`);
    }

    // 2. 만료된 원본 메시지 삭제
    const messagesResult = await query(
      `DELETE FROM yeope_schema.messages 
       WHERE expires_at < NOW() 
       RETURNING id`
    );
    logger.info(`만료된 메시지 ${messagesResult.rowCount}개 삭제 (Active Table)`);

    // 3. 만료된 방 멤버 아카이빙
    const memberArchiveResult = await query(
      `INSERT INTO yeope_schema.archived_room_members (id, room_id, user_id, joined_at, left_at, role)
       SELECT id, room_id, user_id, joined_at, left_at, role
       FROM yeope_schema.room_members
       WHERE room_id IN (
         SELECT id FROM yeope_schema.rooms WHERE expires_at < NOW()
       )`
    );
    if (memberArchiveResult.rowCount > 0) {
      logger.info(`방 멤버 ${memberArchiveResult.rowCount}개 아카이브 이동`);
    }

    // 4. 만료된 방 멤버 삭제
    const membersResult = await query(
      `DELETE FROM yeope_schema.room_members 
       WHERE room_id IN (
         SELECT id FROM yeope_schema.rooms WHERE expires_at < NOW()
       ) 
       RETURNING id`
    );
    logger.info(`만료된 방 멤버 ${membersResult.rowCount}개 삭제 (Active Table)`);

    // 5. 만료된 방 아카이빙
    const roomArchiveResult = await query(
      `INSERT INTO yeope_schema.archived_rooms (id, room_id, name, creator_id, created_at, expires_at, metadata)
       SELECT id, room_id, name, creator_id, created_at, expires_at, metadata
       FROM yeope_schema.rooms
       WHERE expires_at < NOW()`
    );
    if (roomArchiveResult.rowCount > 0) {
      logger.info(`방 멤버 ${roomArchiveResult.rowCount}개 아카이브 이동`);
    }

    // 6. 만료된 방 삭제
    const roomsResult = await query(
      `DELETE FROM yeope_schema.rooms 
       WHERE expires_at < NOW() 
       RETURNING id`
    );
    logger.info(`만료된 방 ${roomsResult.rowCount}개 삭제 (Active Table)`);

    // 7. 만료된 BLE UID 비활성화 (No archiving needed as these are ephemeral IDs)
    const uidCount = await bleService.cleanupExpiredUIDs();
    logger.info(`만료된 BLE UID ${uidCount}개 비활성화`);

    await query('COMMIT');
    logger.info('만료된 데이터 정리 완료');
  } catch (error) {
    await query('ROLLBACK');
    logger.error('만료된 데이터 정리 중 오류:', error);
    throw error;
  }
};

/**
 * 6개월 지난 아카이브 데이터 영구 삭제
 */
const cleanupArchivedData = async () => {
  try {
    await query('BEGIN');

    // 6개월 = 180일
    const retentionDate = new Date();
    retentionDate.setDate(retentionDate.getDate() - 180);

    const msgDel = await query(
      `DELETE FROM yeope_schema.archived_messages WHERE archived_at < $1`,
      [retentionDate]
    );

    const memDel = await query(
      `DELETE FROM yeope_schema.archived_room_members WHERE archived_at < $1`,
      [retentionDate]
    );

    const roomDel = await query(
      `DELETE FROM yeope_schema.archived_rooms WHERE archived_at < $1`,
      [retentionDate]
    );

    if (msgDel.rowCount + memDel.rowCount + roomDel.rowCount > 0) {
      logger.info(`오래된 아카이브 삭제: Msg=${msgDel.rowCount}, Mem=${memDel.rowCount}, Room=${roomDel.rowCount}`);
    }

    await query('COMMIT');
  } catch (error) {
    await query('ROLLBACK');
    logger.error('아카이브 정리 중 오류:', error);
  }
}

/**
 * TTL 정리 스케줄러 시작
 * 매 시간마다 실행
 */
const startTTLScheduler = () => {
  // 매 시간 0분에 실행 (예: 1:00, 2:00, 3:00...)
  cron.schedule('0 * * * *', async () => {
    await cleanupExpiredData();
  });

  // 매일 새벽 4시에 아카이브 정리 실행
  cron.schedule('0 4 * * *', async () => {
    await cleanupArchivedData();
  });

  logger.info('TTL 정리 스케줄러 시작 (매 시간 실행 / 매일 04시 아카이브 정리)');
};

module.exports = {
  cleanupExpiredData,
  startTTLScheduler
};





