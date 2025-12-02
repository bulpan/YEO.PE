# 푸시 알림 발송 시점 타임라인

> **목적**: 앱 설치부터 최종 이용까지 푸시 알림이 발송되어야 하는 모든 시점을 시계열 순서로 정리

---

## 📱 사용자 여정별 푸시 알림 발송 시점

### Phase 1: 앱 설치 및 초기 설정

#### 1.1 앱 설치 및 실행
- **푸시 알림 발송**: ❌ 없음
- **설명**: 앱 설치 직후에는 알림 발송 없음

#### 1.2 푸시 알림 권한 요청
- **푸시 알림 발송**: ❌ 없음
- **설명**: 시스템 권한 요청 단계

---

### Phase 2: 회원가입 및 로그인

#### 2.1 회원가입/로그인
- **푸시 알림 발송**: ❌ 없음
- **설명**: 인증 단계

#### 2.2 푸시 토큰 등록
- **푸시 알림 발송**: ❌ 없음
- **API**: `POST /api/push/register`
- **설명**: FCM/APNs 토큰을 서버에 등록 (앱 시작 시 자동 호출)
- **구현 상태**: ✅ 완료

---

### Phase 3: BLE 탐색 시작

#### 3.1 BLE 권한 요청
- **푸시 알림 발송**: ❌ 없음
- **설명**: 시스템 권한 요청 단계

#### 3.2 BLE 탐색 시작
- **푸시 알림 발송**: ❌ 없음
- **설명**: 탐색 시작 단계

#### 3.3 Short UID 발급
- **푸시 알림 발송**: ❌ 없음
- **API**: `POST /api/users/ble/uid`
- **설명**: BLE 광고용 Short UID 발급
- **구현 상태**: 🚧 예정 (IMPLEMENTATION_GUIDE.md 참조)

---

### Phase 4: 주변 사용자 발견

#### 4.1 BLE 스캔 결과 전송
- **푸시 알림 발송**: ✅ **있음** (새로운 사용자 발견 시)
- **API**: `POST /api/users/ble/scan`
- **알림 타입**: `nearby_user_found`
- **발송 조건**:
  - 이전 스캔 결과에 없던 새로운 사용자가 발견되었을 때
  - 최소 간격: 5분
  - 사용자 설정에서 푸시 알림 활성화되어 있어야 함
- **알림 내용**:
  ```
  제목: "주변에 사용자가 있습니다"
  내용: "근처에 YEO.PE 사용자 N명이 있습니다"
  ```
- **구현 상태**: ✅ 서비스 구현 완료, 🚧 BLE 스캔 API에 통합 필요
- **통합 위치**: `server/src/routes/users.js` (BLE 스캔 API 구현 시)

---

### Phase 5: 방 생성

#### 5.1 방 생성 요청
- **푸시 알림 발송**: ✅ **있음** (주변 사용자에게)
- **API**: `POST /api/rooms`
- **알림 타입**: `room_created`
- **발송 조건**:
  - 방 생성 성공 시
  - 주변 사용자 목록 조회 (BLE 스캔 결과 기반)
  - 최소 간격: 10분 (같은 사용자에게)
- **알림 내용**:
  ```
  제목: "새로운 방이 생성되었습니다"
  내용: "{방 이름}"
  데이터: { roomId, roomName }
  ```
- **구현 상태**: ✅ 서비스 구현 완료, ❌ **roomService에 통합 안 됨**
- **통합 필요**: `server/src/routes/rooms.js` (방 생성 API)

---

### Phase 6: 방 참여

#### 6.1 방 참여 요청
- **푸시 알림 발송**: ❌ 없음 (또는 선택적)
- **API**: `POST /api/rooms/:roomId/join`
- **알림 타입**: `user_joined` (선택적, 우선순위 낮음)
- **설명**: 방 멤버에게 새 멤버 참여 알림 (선택 기능)
- **구현 상태**: ❌ 미구현 (선택 기능)

---

### Phase 7: 채팅 메시지 수신

#### 7.1 메시지 전송 (WebSocket)
- **푸시 알림 발송**: ✅ **있음** (수신자에게)
- **이벤트**: `send-message` (WebSocket)
- **알림 타입**: `new_message`
- **발송 조건**:
  - 메시지 전송 성공 시
  - 수신자가 WebSocket에 연결되어 있지 않거나 백그라운드 상태일 때만
  - 발신자 제외
  - 사용자 설정에서 푸시 알림 활성화되어 있어야 함
- **알림 내용**:
  ```
  제목: "{발신자 마스킹된 닉네임}"
  내용: "{메시지 내용}" (텍스트) 또는 "📷 이미지" (이미지) 또는 "이모지" (이모지)
  데이터: { roomId, roomName, messageId, senderNicknameMask }
  ```
- **구현 상태**: ✅ 완료 (`server/src/socket/messageHandler.js`)

---

### Phase 8: 방 초대

#### 8.1 BLE를 통한 방 초대
- **푸시 알림 발송**: ✅ **있음** (초대받은 사용자에게)
- **알림 타입**: `room_invite`
- **발송 조건**:
  - BLE를 통해 방 초대 수신 시
  - 초대자 정보 및 방 정보 포함
- **알림 내용**:
  ```
  제목: "방 초대"
  내용: "{초대자 닉네임}님이 {방 이름} 방에 초대했습니다"
  데이터: { roomId, roomName, inviterId }
  ```
- **구현 상태**: ❌ **미구현** (기능 명세서에만 있음)
- **통합 필요**: BLE 초대 기능 구현 시

---

### Phase 9: 방 나가기 및 종료

#### 9.1 방 나가기
- **푸시 알림 발송**: ❌ 없음
- **API**: `POST /api/rooms/:roomId/leave`

#### 9.2 BLE 거리 이탈
- **푸시 알림 발송**: ❌ 없음
- **설명**: 자동 퇴장 처리

#### 9.3 방 만료 (24시간 후)
- **푸시 알림 발송**: ❌ 없음
- **설명**: TTL 정리 시스템에 의해 자동 삭제

---

## 📊 푸시 알림 발송 시점 요약

| 순서 | 시점 | 알림 타입 | 구현 상태 | 통합 위치 |
|------|------|----------|----------|----------|
| 1 | 주변 사용자 발견 (새로운 사용자) | `nearby_user_found` | ✅ 서비스 완료 | 🚧 BLE 스캔 API 필요 |
| 2 | 방 생성 (주변 사용자에게) | `room_created` | ✅ 서비스 완료 | ❌ **roomService 통합 필요** |
| 3 | 메시지 수신 | `new_message` | ✅ 완료 | ✅ messageHandler |
| 4 | 방 초대 수신 | `room_invite` | ❌ 미구현 | 🚧 BLE 초대 기능 필요 |
| 5 | 사용자 참여 (선택) | `user_joined` | ❌ 미구현 | 선택 기능 |

---

## ⚠️ 빠진 부분 및 통합 필요 사항

### 1. 방 생성 알림 통합 (우선순위: 높음)

**현재 상태**: `sendRoomCreatedNotification` 함수는 구현되어 있으나, 방 생성 API에 통합되지 않음

**통합 필요 위치**: `server/src/routes/rooms.js` (방 생성 API)

**통합 방법**:
```javascript
// server/src/routes/rooms.js
const pushService = require('../services/pushService');

router.post('/', authenticate, async (req, res, next) => {
  try {
    // ... 방 생성 로직 ...
    const room = await roomService.createRoom(userId, name, category);
    
    // 주변 사용자 조회 (BLE 스캔 결과 기반)
    // TODO: BLE 스캔 결과에서 주변 사용자 ID 목록 가져오기
    const nearbyUserIds = []; // BLE 스캔 결과에서 가져와야 함
    
    // 주변 사용자에게 방 생성 알림 전송
    if (nearbyUserIds.length > 0) {
      pushService.sendRoomCreatedNotification(
        room.roomId,
        room.name,
        userId,
        nearbyUserIds
      ).catch(err => {
        logger.error('방 생성 알림 전송 실패:', err);
      });
    }
    
    res.json(room);
  } catch (error) {
    next(error);
  }
});
```

**문제점**: 주변 사용자 목록을 어떻게 가져올지 결정 필요
- 옵션 1: BLE 스캔 결과를 Redis에 캐시하고 조회
- 옵션 2: 클라이언트에서 방 생성 시 주변 사용자 ID 목록을 함께 전송
- 옵션 3: 최근 활성 사용자 조회 (정확도 낮음)

---

### 2. 방 초대 알림 구현 (우선순위: 중간)

**현재 상태**: 기능 명세서에만 있고 구현되지 않음

**구현 필요**:
- BLE 초대 기능 구현 시 함께 구현
- 또는 서버 API로 방 초대 기능 추가 시 구현

**구현 방법**:
```javascript
// server/src/services/pushService.js에 추가 필요
const sendRoomInviteNotification = async (invitedUserId, roomId, roomName, inviterId, inviterNicknameMask) => {
  // ... 구현 ...
};
```

---

### 3. 주변 사용자 발견 알림 통합 (우선순위: 높음)

**현재 상태**: 서비스는 구현되어 있으나, BLE 스캔 API가 아직 구현되지 않음

**통합 필요 위치**: `server/src/routes/users.js` (BLE 스캔 API 구현 시)

**통합 방법**: `IMPLEMENTATION_GUIDE.md`에 가이드 제공됨

---

### 4. 사용자 참여 알림 (우선순위: 낮음)

**현재 상태**: 선택 기능으로 미구현

**설명**: 방에 새 멤버가 참여했을 때 기존 멤버에게 알림 (선택 기능)

---

## ✅ 완료된 통합

1. **메시지 알림**: `server/src/socket/messageHandler.js`에 통합 완료
   - WebSocket 연결 상태 확인
   - 백그라운드 사용자에게만 발송

---

## 📝 체크리스트

### 즉시 통합 필요
- [ ] 방 생성 알림을 `roomService.createRoom` 또는 `routes/rooms.js`에 통합
- [ ] 주변 사용자 목록 조회 방법 결정 및 구현

### BLE 기능 구현 시 통합
- [ ] BLE 스캔 API 구현 시 주변 사용자 발견 알림 통합
- [ ] BLE 초대 기능 구현 시 방 초대 알림 구현

### 선택 기능
- [ ] 사용자 참여 알림 구현 (우선순위 낮음)

---

## 참고

- [푸시 알림 기능 명세서](../functional-spec/06-push-notification.md)
- [푸시 알림 설정 가이드](./PUSH_NOTIFICATION_SETUP.md)
- [BLE 탐색 기능 명세](../functional-spec/04-ble-discovery.md)
- [구현 가이드](./IMPLEMENTATION_GUIDE.md)



