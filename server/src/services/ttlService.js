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

    // 1. 만료된 방의 메시지 삭제
    const messagesResult = await query(
      `DELETE FROM yeope_schema.messages 
       WHERE expires_at < NOW() 
       RETURNING id`
    );
    logger.info(`만료된 메시지 ${messagesResult.rowCount}개 삭제`);

    // 2. 만료된 방의 멤버 삭제
    const membersResult = await query(
      `DELETE FROM yeope_schema.room_members 
       WHERE room_id IN (
         SELECT id FROM yeope_schema.rooms WHERE expires_at < NOW()
       ) 
       RETURNING id`
    );
    logger.info(`만료된 방 멤버 ${membersResult.rowCount}개 삭제`);

    // 3. 만료된 방 삭제
    const roomsResult = await query(
      `DELETE FROM yeope_schema.rooms 
       WHERE expires_at < NOW() 
       RETURNING id`
    );
    logger.info(`만료된 방 ${roomsResult.rowCount}개 삭제`);

    // 4. 만료된 BLE UID 비활성화
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
 * TTL 정리 스케줄러 시작
 * 매 시간마다 실행
 */
const startTTLScheduler = () => {
  // 매 시간 0분에 실행 (예: 1:00, 2:00, 3:00...)
  cron.schedule('0 * * * *', async () => {
    await cleanupExpiredData();
  });

  logger.info('TTL 정리 스케줄러 시작 (매 시간 실행)');
};

module.exports = {
  cleanupExpiredData,
  startTTLScheduler
};





