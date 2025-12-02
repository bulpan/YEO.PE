/**
 * Redis 연결 설정
 */

const Redis = require('ioredis');
const logger = require('../utils/logger');

const redisConfig = {
  host: process.env.REDIS_HOST || 'localhost',
  port: process.env.REDIS_PORT || 6379,
  password: process.env.REDIS_PASSWORD || undefined,
  retryStrategy: (times) => {
    const delay = Math.min(times * 50, 2000);
    return delay;
  },
  maxRetriesPerRequest: 3
};

logger.info(`Redis connecting to ${redisConfig.host}:${redisConfig.port}`);

const redis = new Redis(redisConfig);

redis.on('connect', () => {
  logger.info('Redis 연결 성공');
});

redis.on('error', (err) => {
  logger.error('Redis 연결 오류:', err);
});

redis.on('close', () => {
  logger.warn('Redis 연결 종료');
});

module.exports = redis;





