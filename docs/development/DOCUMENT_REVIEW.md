# 문서 일관성 검토 및 DB/API 적합성 분석

> **검토일**: 2024년 11월  
> **검토 범위**: 기획서, 아키텍처, 기능명세서, DB 스키마, API 구현

---

## 📋 검토 결과 요약

### ✅ 일관성 있는 부분
- 기본 아키텍처 원칙 (BLE 탐색 + 서버 채팅)
- 사용자 인증 시스템
- 방 관리 및 실시간 채팅
- TTL 정책 (24시간)

### ⚠️ 불일치 및 누락 사항
1. **BLE 설계 불일치** (중요)
2. **DB 스키마 누락** (BLE 관련)
3. **API 누락** (BLE 관련)
4. **기획서 업데이트 필요**

---

## 🔴 1. BLE 설계 불일치 (중요)

### 문제점

#### 아키텍처 문서 (architecture.md)
- **방식**: GATT Connection 사용
- **Service UUID**: `0000FEED-0000-1000-8000-00805F9B34FB`
- **특성(Characteristic) 사용**:
  - Device Info (읽기 전용)
  - Room Invite (읽기/쓰기)
- **데이터 전송**: BLE를 통해 닉네임, 사용자 ID 해시 등 전송

#### 기능명세서 (04-ble-discovery.md)
- **방식**: Connection-less 브로드캐스팅만
- **Service UUID**: `0000YP00-0000-1000-8000-00805F9B34FB`
- **Manufacturer Data 사용**: App ID + Short UID만
- **데이터 전송**: BLE는 UID만, 실제 데이터는 서버

### 해결 방안

**기능명세서가 최신 설계이므로 아키텍처 문서를 업데이트해야 합니다.**

#### 수정 필요 사항:
1. `architecture.md`의 BLE 통신 설계 섹션 전체 수정
2. Service UUID 변경: `0000FEED-...` → `0000YP00-...`
3. GATT Connection 제거, 브로드캐스팅 방식으로 변경
4. Characteristic 제거, Manufacturer Data 방식으로 변경
5. Short UID 발급 시스템 추가

---

## 🔴 2. DB 스키마 누락

### 현재 상태

현재 `init.sql`에는 BLE 관련 테이블이 없습니다.

### 필요한 테이블

#### `ble_uids` 테이블 (필수)

```sql
CREATE TABLE yeope_schema.ble_uids (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    uid VARCHAR(16) UNIQUE NOT NULL, -- Short UID (예: "A1B2C3D4")
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    CONSTRAINT unique_user_active UNIQUE(user_id, is_active) WHERE is_active = true
);

-- 인덱스
CREATE INDEX idx_ble_uids_uid ON ble_uids(uid);
CREATE INDEX idx_ble_uids_user_id ON ble_uids(user_id);
CREATE INDEX idx_ble_uids_expires_at ON ble_uids(expires_at);
CREATE INDEX idx_ble_uids_active ON ble_uids(uid, is_active) WHERE is_active = true;
```

**목적**:
- 사용자 ID와 Short UID 매핑
- UID 만료 시간 관리
- 활성 UID 조회 최적화

### 권한 부여

```sql
GRANT ALL PRIVILEGES ON TABLE yeope_schema.ble_uids TO yeope_user;
```

---

## 🔴 3. API 누락

### 현재 구현된 API

#### 인증 API ✅
- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/logout`
- `POST /api/auth/refresh`
- `GET /api/auth/me`

#### 방 관리 API ✅
- `POST /api/rooms`
- `GET /api/rooms/nearby`
- `GET /api/rooms/my`
- `GET /api/rooms/:roomId`
- `POST /api/rooms/:roomId/join`
- `POST /api/rooms/:roomId/leave`
- `GET /api/rooms/:roomId/members`

#### 메시지 API ✅
- `GET /api/rooms/:roomId/messages`
- `POST /api/rooms/:roomId/messages`
- `DELETE /api/messages/:messageId`

### 누락된 API (BLE 관련)

#### 1. Short UID 발급 API ❌

**엔드포인트**: `POST /api/users/ble/uid`

**기능**: 사용자에게 Short UID 발급

**요청**:
```json
{
  // 본문 없음 (JWT 토큰에서 사용자 ID 추출)
}
```

**응답**:
```json
{
  "uid": "A1B2C3D4",
  "expiresAt": "2024-01-02T00:00:00.000Z"
}
```

**구현 필요**:
- `server/src/routes/users.js` 생성
- `server/src/services/bleService.js` 생성
- UID 생성 로직 (랜덤 4~8바이트)
- DB에 저장 및 만료 시간 설정

#### 2. UID 목록으로 사용자 정보 조회 API ❌

**엔드포인트**: `POST /api/users/ble/scan`

**기능**: UID 목록을 받아서 사용자 정보 반환

**요청**:
```json
{
  "uids": [
    {
      "uid": "A1B2C3D4",
      "rssi": -65,
      "timestamp": 1234567890
    }
  ]
}
```

**응답**:
```json
{
  "users": [
    {
      "uid": "A1B2C3D4",
      "nicknameMask": "김**",
      "distance": 15.5,
      "hasActiveRoom": true,
      "roomId": "550e8400-e29b-41d4-a716-446655440000",
      "roomName": "지하철 2호선"
    }
  ]
}
```

**구현 필요**:
- UID → 사용자 ID 매핑
- 사용자 정보 조회
- 활성 방 정보 조회
- 거리 정보 포함 (클라이언트에서 계산한 값)

---

## 🔴 4. 기획서 업데이트 필요

### 현재 기획서 (PROJECT_SPEC.md)

**3. 주요 기능**:
- "방 참여: BLE 탐색 결과 기반으로 근처 사용자에게 푸시 전송 → 승인 시 연결"

**5. 사용자 흐름**:
- "4️⃣ 푸시 승인 후 채팅방 입장"

### 문제점

기획서가 BLE를 통한 직접 초대 방식으로 기술되어 있으나, 실제 설계는 서버 기반입니다.

### 수정 필요

**3. 주요 기능**:
```
방 참여: BLE 탐색으로 주변 사용자 발견 → 서버를 통해 사용자 정보 조회 → 
활성 방이 있으면 참여 옵션 표시 → 서버 API로 방 참여
```

**5. 사용자 흐름**:
```
4️⃣ 주변 사용자 목록에서 방 참여 선택 → 서버 API로 방 참여 → 채팅방 입장
```

---

## ✅ 5. 일관성 있는 부분

### 인증 시스템
- ✅ 기획서: 이메일/구글/애플 로그인
- ✅ 아키텍처: JWT 기반 인증
- ✅ 기능명세서: 이메일 회원가입/로그인 상세 명세
- ✅ 구현: `auth.js` 라우트 완료

### 방 관리
- ✅ 기획서: 방 생성, 참여, 24시간 TTL
- ✅ 아키텍처: Room API 설계
- ✅ 기능명세서: 상세 명세 완료
- ✅ 구현: `rooms.js` 라우트 완료

### 실시간 채팅
- ✅ 기획서: 그룹 채팅, 텍스트/이미지/이모지
- ✅ 아키텍처: WebSocket 설계
- ✅ 기능명세서: 상세 명세 완료
- ✅ 구현: Socket.io 핸들러 완료

### TTL 정리
- ✅ 기획서: 24시간 후 자동 폐기
- ✅ 아키텍처: TTL 서비스 설계
- ✅ 기능명세서: 상세 명세 완료
- ✅ 구현: `ttlService.js` 완료

---

## 📝 6. 수정 작업 체크리스트

### 우선순위 1: 아키텍처 문서 수정
- [ ] `architecture.md` BLE 통신 설계 섹션 수정
- [ ] Service UUID 변경
- [ ] GATT Connection 제거, 브로드캐스팅 방식으로 변경
- [ ] Short UID 발급 시스템 추가

### 우선순위 2: DB 스키마 추가
- [ ] `ble_uids` 테이블 생성 SQL 작성
- [ ] 마이그레이션 스크립트 작성
- [ ] 인덱스 생성

### 우선순위 3: API 구현
- [ ] `server/src/routes/users.js` 생성
- [ ] `server/src/services/bleService.js` 생성
- [ ] `POST /api/users/ble/uid` 구현
- [ ] `POST /api/users/ble/scan` 구현

### 우선순위 4: 기획서 업데이트
- [ ] 방 참여 플로우 수정
- [ ] 사용자 흐름 수정

---

## 🎯 7. 최종 권장사항

### 즉시 수정 필요
1. **아키텍처 문서**: BLE 설계를 기능명세서에 맞게 수정
2. **DB 스키마**: `ble_uids` 테이블 추가
3. **API 구현**: BLE 관련 API 2개 추가

### 다음 단계
1. 기획서 업데이트 (문서 일관성)
2. API 테스트 작성
3. DB 마이그레이션 실행

---

## 📊 8. 문서 일관성 점수

| 항목 | 일관성 | 비고 |
|------|--------|------|
| 기본 아키텍처 | ✅ 95% | BLE 설계만 불일치 |
| 인증 시스템 | ✅ 100% | 완벽 일치 |
| 방 관리 | ✅ 100% | 완벽 일치 |
| 실시간 채팅 | ✅ 100% | 완벽 일치 |
| BLE 탐색 | ❌ 30% | 설계 방식 불일치 |
| DB 스키마 | ⚠️ 80% | BLE 테이블 누락 |
| API 구현 | ⚠️ 85% | BLE API 누락 |

**전체 일관성**: ⚠️ **85%** (BLE 관련 부분 수정 필요)

---

## 📚 참고

- [프로젝트 기획서](../planning/PROJECT_SPEC.md)
- [기술 설계서](../architecture/architecture.md)
- [기능 명세서](../functional-spec/FUNCTIONAL_SPEC.md)
- [BLE 탐색 기능 명세](./docs/functional-spec/04-ble-discovery.md)

