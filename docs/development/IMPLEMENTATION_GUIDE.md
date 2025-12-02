# 누락된 기능 구현 가이드

> **목적**: 문서 검토 결과 누락된 BLE 관련 기능 구현 가이드

---

## 1. DB 마이그레이션 실행

### 마이그레이션 스크립트 실행

```bash
# 서버에 접속
ssh -i yeope-ssh-key.key opc@152.67.208.177

# PostgreSQL 접속
sudo -u postgres psql -d yeope

# 마이그레이션 실행
\i /opt/yeope/server/database/migration_add_ble_uids.sql
```

또는 직접 실행:

```bash
sudo -u postgres psql -d yeope -f /opt/yeope/server/database/migration_add_ble_uids.sql
```

---

## 2. BLE 서비스 구현

### 파일 생성: `server/src/services/bleService.js`

```javascript
/**
 * BLE 서비스
 */

const crypto = require('crypto');
const { query, transaction } = require('../config/database');
const { ValidationError, NotFoundError } = require('../utils/errors');
const logger = require('../utils/logger');

/**
 * Short UID 생성 (4~8바이트, 16진수 문자열)
 */
const generateShortUID = () => {
  // 4바이트 = 8자리 16진수
  const bytes = crypto.randomBytes(4);
  return bytes.toString('hex').toUpperCase();
};

/**
 * 사용자에게 Short UID 발급
 */
const issueUID = async (userId) => {
  // 기존 활성 UID 비활성화
  await query(
    `UPDATE yeope_schema.ble_uids 
     SET is_active = false 
     WHERE user_id = $1 AND is_active = true`,
    [userId]
  );

  // 새 UID 생성
  let uid;
  let isUnique = false;
  let attempts = 0;
  const maxAttempts = 10;

  while (!isUnique && attempts < maxAttempts) {
    uid = generateShortUID();
    const existing = await query(
      'SELECT id FROM yeope_schema.ble_uids WHERE uid = $1',
      [uid]
    );
    if (existing.rows.length === 0) {
      isUnique = true;
    }
    attempts++;
  }

  if (!isUnique) {
    throw new Error('UID 생성 실패: 고유한 UID를 생성할 수 없습니다');
  }

  // 만료 시간 설정 (24시간 후)
  const expiresAt = new Date();
  expiresAt.setHours(expiresAt.getHours() + 24);

  // UID 저장
  await query(
    `INSERT INTO yeope_schema.ble_uids 
     (user_id, uid, expires_at, is_active)
     VALUES ($1, $2, $3, true)`,
    [userId, uid, expiresAt]
  );

  logger.info(`Short UID 발급: ${uid} for user ${userId}`);

  return {
    uid,
    expiresAt
  };
};

/**
 * UID로 사용자 정보 조회
 */
const getUserByUID = async (uid) => {
  const result = await query(
    `SELECT u.*, bu.expires_at as uid_expires_at
     FROM yeope_schema.ble_uids bu
     JOIN yeope_schema.users u ON bu.user_id = u.id
     WHERE bu.uid = $1 
       AND bu.is_active = true 
       AND bu.expires_at > NOW()
       AND u.is_active = true`,
    [uid]
  );

  return result.rows[0] || null;
};

/**
 * UID 목록으로 사용자 정보 조회
 */
const getUsersByUIDs = async (uidList) => {
  if (!uidList || uidList.length === 0) {
    return [];
  }

  const uids = uidList.map(item => item.uid);
  const placeholders = uids.map((_, index) => `$${index + 1}`).join(', ');

  const result = await query(
    `SELECT 
       bu.uid,
       u.id as user_id,
       u.nickname,
       u.nickname_mask,
       bu.expires_at as uid_expires_at
     FROM yeope_schema.ble_uids bu
     JOIN yeope_schema.users u ON bu.user_id = u.id
     WHERE bu.uid IN (${placeholders})
       AND bu.is_active = true
       AND bu.expires_at > NOW()
       AND u.is_active = true`,
    uids
  );

  // UID 목록과 매칭하여 거리 정보 포함
  const users = result.rows.map(user => {
    const uidInfo = uidList.find(item => item.uid === user.uid);
    return {
      uid: user.uid,
      userId: user.user_id,
      nicknameMask: user.nickname_mask,
      distance: uidInfo ? calculateDistance(uidInfo.rssi) : null,
      rssi: uidInfo ? uidInfo.rssi : null
    };
  });

  // 활성 방 정보 조회
  for (const user of users) {
    const activeRoom = await query(
      `SELECT r.room_id, r.name
       FROM yeope_schema.rooms r
       JOIN yeope_schema.room_members rm ON r.id = rm.room_id
       WHERE rm.user_id = $1
         AND rm.left_at IS NULL
         AND r.is_active = true
         AND r.expires_at > NOW()
       ORDER BY rm.last_seen_at DESC
       LIMIT 1`,
      [user.userId]
    );

    if (activeRoom.rows.length > 0) {
      user.hasActiveRoom = true;
      user.roomId = activeRoom.rows[0].room_id;
      user.roomName = activeRoom.rows[0].name;
    } else {
      user.hasActiveRoom = false;
    }
  }

  return users;
};

/**
 * RSSI를 거리로 변환 (미터)
 */
const calculateDistance = (rssi) => {
  const txPower = -59; // 전송 전력 (dBm)
  const n = 2; // 경로 손실 지수
  
  if (rssi === 0) {
    return -1; // 거리를 계산할 수 없음
  }

  const ratio = (txPower - rssi) / (10 * n);
  const distance = Math.pow(10, ratio);
  
  return Math.round(distance * 10) / 10; // 소수점 첫째 자리까지
};

/**
 * 만료된 UID 정리
 */
const cleanupExpiredUIDs = async () => {
  const result = await query(
    `UPDATE yeope_schema.ble_uids 
     SET is_active = false 
     WHERE expires_at < NOW() AND is_active = true
     RETURNING id`
  );

  logger.info(`만료된 BLE UID ${result.rowCount}개 비활성화`);
  return result.rowCount;
};

module.exports = {
  issueUID,
  getUserByUID,
  getUsersByUIDs,
  calculateDistance,
  cleanupExpiredUIDs
};
```

---

## 3. 사용자 라우트 생성

### 파일 생성: `server/src/routes/users.js`

```javascript
/**
 * 사용자 API 라우트
 */

const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const bleService = require('../services/bleService');
const { ValidationError } = require('../utils/errors');
const logger = require('../utils/logger');

/**
 * POST /api/users/ble/uid
 * Short UID 발급
 */
router.post('/ble/uid', authenticate, async (req, res, next) => {
  try {
    const userId = req.user.userId;
    
    const result = await bleService.issueUID(userId);
    
    logger.info(`Short UID 발급: ${result.uid} for user ${userId}`);
    
    res.json({
      uid: result.uid,
      expiresAt: result.expiresAt
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/users/ble/scan
 * UID 목록으로 사용자 정보 조회
 */
router.post('/ble/scan', authenticate, async (req, res, next) => {
  try {
    const { uids } = req.body;
    
    if (!uids || !Array.isArray(uids) || uids.length === 0) {
      throw new ValidationError('UID 목록이 필요합니다');
    }

    // UID 목록 검증
    if (uids.length > 50) {
      throw new ValidationError('UID 목록은 최대 50개까지 조회 가능합니다');
    }

    // 각 UID 검증
    for (const uidInfo of uids) {
      if (!uidInfo.uid || typeof uidInfo.uid !== 'string') {
        throw new ValidationError('유효하지 않은 UID 형식입니다');
      }
      if (uidInfo.rssi && (uidInfo.rssi < -120 || uidInfo.rssi > 0)) {
        throw new ValidationError('유효하지 않은 RSSI 값입니다');
      }
    }

    const users = await bleService.getUsersByUIDs(uids);
    
    // 30m 이내 사용자만 필터링
    const nearbyUsers = users.filter(user => {
      if (user.distance === null) return false;
      return user.distance <= 30;
    });

    // 주변 사용자 발견 알림 전송 (새로운 사용자가 발견된 경우)
    const pushService = require('../services/pushService');
    const redis = require('../config/redis');
    
    // 이전 스캔 결과와 비교 (Redis에 캐시)
    const lastScanKey = `ble:scan:${userId}`;
    const lastScanResult = await redis.get(lastScanKey);
    const lastUids = lastScanResult ? JSON.parse(lastScanResult) : [];
    
    const currentUids = nearbyUsers.map(u => u.uid);
    const newUids = currentUids.filter(uid => !lastUids.includes(uid));
    
    // 새로운 사용자가 발견된 경우 알림 전송
    if (newUids.length > 0) {
      pushService.sendNearbyUserFoundNotification(
        userId,
        newUids.length
      ).catch(err => {
        logger.error('주변 사용자 발견 알림 전송 실패:', err);
      });
    }
    
    // 현재 스캔 결과 캐시 (5분 TTL)
    await redis.setex(lastScanKey, 5 * 60, JSON.stringify(currentUids));

    res.json({
      users: nearbyUsers
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
```

---

## 4. 서버 인덱스에 라우트 추가

### `server/src/index.js` 수정

```javascript
// 기존 라우트들
const authRoutes = require('./routes/auth');
const roomRoutes = require('./routes/rooms');
const messageRoutes = require('./routes/messages');
const userRoutes = require('./routes/users'); // 추가

// ...

app.use('/api/auth', authRoutes);
app.use('/api/rooms', roomRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/users', userRoutes); // 추가
```

---

## 5. TTL 서비스에 UID 정리 추가

### `server/src/services/ttlService.js` 수정

```javascript
const bleService = require('./bleService');

const cleanupExpiredData = async () => {
  try {
    logger.info('만료된 데이터 정리 시작...');
    
    await query('BEGIN');
    
    // 만료된 메시지 삭제
    // ... 기존 코드 ...
    
    // 만료된 방 삭제
    // ... 기존 코드 ...
    
    // 만료된 BLE UID 비활성화 (추가)
    await bleService.cleanupExpiredUIDs();
    
    await query('COMMIT');
    logger.info('만료된 데이터 정리 완료');
  } catch (error) {
    await query('ROLLBACK');
    logger.error('만료된 데이터 정리 중 오류:', error);
    throw error;
  }
};
```

---

## 6. 테스트

### Short UID 발급 테스트

```bash
# 토큰 발급 (로그인)
TOKEN=$(curl -X POST https://yeop3.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}' \
  | jq -r '.token')

# Short UID 발급
curl -X POST https://yeop3.com/api/users/ble/uid \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"
```

### UID 스캔 테스트

```bash
curl -X POST https://yeop3.com/api/users/ble/scan \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "uids": [
      {"uid": "A1B2C3D4", "rssi": -65, "timestamp": 1234567890}
    ]
  }'
```

---

## 7. 구현 체크리스트

- [ ] DB 마이그레이션 실행
- [ ] `bleService.js` 생성
- [ ] `users.js` 라우트 생성
- [ ] `index.js`에 라우트 추가
- [ ] TTL 서비스에 UID 정리 추가
- [ ] API 테스트
- [ ] 에러 처리 확인
- [ ] 로깅 확인

---

## 참고

- [문서 검토 결과](./DOCUMENT_REVIEW.md)
- [BLE 탐색 기능 명세](../functional-spec/04-ble-discovery.md)
- [푸시 알림 설정 가이드](./PUSH_NOTIFICATION_SETUP.md)

