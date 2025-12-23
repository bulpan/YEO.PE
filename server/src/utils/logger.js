/**
 * Winston 로거 설정
 */

const winston = require('winston');

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format.splat(),
    winston.format.json()
  ),
  defaultMeta: { service: 'yeope-server' },
  transports: [
    // 콘솔 출력
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.printf(({ timestamp, level, message, ...meta }) => {
          return `${timestamp} [${level}]: ${message} ${Object.keys(meta).length ? JSON.stringify(meta, null, 2) : ''
            }`;
        })
      )
    })
  ]
});

// 모든 환경에서 파일에 로그 저장 (Admin Console용)
logger.add(
  new winston.transports.File({ filename: 'logs/error.log', level: 'error' })
);
logger.add(
  new winston.transports.File({ filename: 'logs/combined.log' })
);

module.exports = logger;





