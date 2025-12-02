# 푸시 알림 설정 가이드

## 1. Firebase 프로젝트 설정

### 1.1 Firebase 프로젝트 생성

1. [Firebase Console](https://console.firebase.google.com/) 접속
2. 새 프로젝트 생성 또는 기존 프로젝트 선택
3. 프로젝트 설정 > 서비스 계정 탭으로 이동

### 1.2 서비스 계정 키 생성

1. "새 비공개 키 생성" 클릭
2. JSON 파일 다운로드
3. 서버에 안전하게 저장 (예: `/opt/yeope/config/firebase-service-account.json`)

### 1.3 환경 변수 설정

서버의 `.env` 파일에 다음 중 하나를 추가:

**방법 1: 파일 경로 사용**
```bash
FCM_SERVICE_ACCOUNT_PATH=/opt/yeope/config/firebase-service-account.json
```

**방법 2: JSON 문자열 사용 (환경 변수로 직접 설정)**
```bash
FCM_SERVICE_ACCOUNT_JSON='{"type":"service_account","project_id":"...","private_key":"..."}'
```

## 2. 데이터베이스 마이그레이션

```bash
# 서버에 접속
ssh -i yeope-ssh-key.key opc@152.67.208.177

# PostgreSQL 접속
sudo -u postgres psql -d yeope

# 마이그레이션 실행
\i /opt/yeope/server/database/migration_add_push_tokens.sql
```

또는 직접 실행:

```bash
sudo -u postgres psql -d yeope -f /opt/yeope/server/database/migration_add_push_tokens.sql
```

## 3. 서버 의존성 설치

```bash
cd /opt/yeope/server
npm install
```

## 4. 서버 재시작

```bash
# 서버 재시작 (PM2 사용 시)
pm2 restart yeope-server

# 또는 직접 실행 시
# 프로세스 종료 후 재시작
```

## 5. 테스트

### 5.1 푸시 토큰 등록

```bash
# 로그인하여 토큰 발급
TOKEN=$(curl -X POST https://yeop3.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}' \
  | jq -r '.token')

# 푸시 토큰 등록
curl -X POST https://yeop3.com/api/push/register \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "deviceToken": "test_fcm_token_here",
    "platform": "android",
    "deviceId": "device123"
  }'
```

### 5.2 푸시 토큰 목록 조회

```bash
curl -X GET https://yeop3.com/api/push/tokens \
  -H "Authorization: Bearer $TOKEN"
```

## 6. 알림 발송 시나리오

### 6.1 메시지 알림

메시지가 전송되면 자동으로 푸시 알림이 발송됩니다.
- WebSocket에 연결되지 않은 사용자에게만 발송
- 앱이 백그라운드에 있을 때만 발송

### 6.2 주변 사용자 발견 알림

BLE 스캔 API (`POST /api/users/ble/scan`) 구현 시, 새로운 사용자가 발견되면 자동으로 알림이 발송됩니다.

**통합 방법**:
```javascript
// server/src/routes/users.js (BLE 스캔 API)
const pushService = require('../services/pushService');

// ... BLE 스캔 처리 후 ...

// 새로운 사용자 발견 시
if (newUsers.length > 0) {
  pushService.sendNearbyUserFoundNotification(
    userId, // 현재 사용자 ID
    newUsers.length // 발견된 사용자 수
  ).catch(err => {
    logger.error('주변 사용자 발견 알림 전송 실패:', err);
  });
}
```

## 7. 문제 해결

### 7.1 Firebase 초기화 실패

- 서비스 계정 키 파일 경로 확인
- 파일 권한 확인 (읽기 가능해야 함)
- JSON 형식 확인

### 7.2 푸시 알림이 발송되지 않음

- Firebase 프로젝트 설정 확인
- 푸시 토큰이 올바르게 등록되었는지 확인
- 서버 로그 확인 (`logger.info`로 푸시 발송 상태 확인)

### 7.3 만료된 토큰 처리

만료된 토큰은 자동으로 비활성화됩니다. 클라이언트에서 토큰 갱신 시 다시 등록하면 됩니다.

## 참고

- [Firebase Cloud Messaging 문서](https://firebase.google.com/docs/cloud-messaging)
- [기능 명세서 - 푸시 알림](../functional-spec/06-push-notification.md)



