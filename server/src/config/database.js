/**
 * PostgreSQL 데이터베이스 연결 설정
 */

const { Pool } = require('pg');
const logger = require('../utils/logger');

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'yeope',
  user: process.env.DB_USER || 'yeope_user',
  password: process.env.DB_PASSWORD,
  max: 20, // 최대 연결 수
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
  schema: 'yeope_schema'
});

// 연결 테스트
pool.on('connect', () => {
  logger.info('PostgreSQL 연결 성공');
});

pool.on('error', (err) => {
  logger.error('PostgreSQL 연결 오류:', err);
  process.exit(-1);
});

// 쿼리 실행 헬퍼 함수
const query = async (text, params) => {
  const start = Date.now();
  try {
    const res = await pool.query(text, params);
    const duration = Date.now() - start;
    logger.debug('쿼리 실행', { text, duration, rows: res.rowCount });
    return res;
  } catch (error) {
    logger.error('쿼리 실행 오류', { text, error: error.message });
    throw error;
  }
};

// 트랜잭션 헬퍼 함수
const transaction = async (callback) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};

module.exports = {
  pool,
  query,
  transaction
};





