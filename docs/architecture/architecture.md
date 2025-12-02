# 🏗️ YEO.PE 기술 설계서

> **프로젝트**: YEO.PE  
> **버전**: 1.0  
> **작성일**: 2024  
> **참조**: [프로젝트 기획서](../planning/PROJECT_SPEC.md)

---

## 목차

1. [시스템 아키텍처 개요](#1-시스템-아키텍처-개요)
2. [기술 스택 상세](#2-기술-스택-상세)
3. [시스템 구조](#3-시스템-구조)
4. [데이터베이스 설계](#4-데이터베이스-설계)
5. [API 설계](#5-api-설계)
6. [BLE 통신 설계](#6-ble-통신-설계)
7. [실시간 통신 설계](#7-실시간-통신-설계)
8. [보안 설계](#8-보안-설계)
9. [인프라 설계](#9-인프라-설계)
10. [배포 전략](#10-배포-전략)
11. [확장성 고려사항](#11-확장성-고려사항)

---

## 1. 시스템 아키텍처 개요

### 1.1 아키텍처 패턴
**하이브리드 아키텍처**: BLE 탐색(클라이언트) + 서버 경유 채팅(클라우드)

```
┌─────────────────┐         ┌─────────────────┐
│   iOS/Android   │         │   iOS/Android   │
│     Client      │         │     Client      │
│                 │         │                 │
│  ┌───────────┐  │         │  ┌───────────┐  │
│  │   BLE     │  │◄───────►│  │   BLE     │  │
│  │ Explorer  │  │  BLE    │  │ Explorer  │  │
│  └───────────┘  │         │  └───────────┘  │
│        │        │         │        │        │
│        │        │         │        │        │
│  ┌───────────┐  │         │  ┌───────────┐  │
│  │ WebSocket │  │         │  │ WebSocket │  │
│  │  Client   │  │         │  │  Client   │  │
│  └─────┬─────┘  │         │  └─────┬─────┘  │
└────────┼─────────┘         └────────┼─────────┘
         │                            │
         └────────────┬───────────────┘
                      │
         ┌────────────▼──────────────┐
         │   Backend Server          │
         │  ┌─────────────────────┐  │
         │  │  WebSocket Server   │  │
         │  │  (Socket.io/ws)     │  │
         │  └──────────┬──────────┘  │
         │             │               │
         │  ┌──────────▼──────────┐  │
         │  │   REST API Server   │  │
         │  │   (Express.js)      │  │
         │  └──────────┬──────────┘  │
         └─────────────┼──────────────┘
                       │
         ┌─────────────┼──────────────┐
         │             │               │
    ┌────▼────┐   ┌────▼────┐   ┌────▼────┐
    │PostgreSQL│   │  Redis  │   │OCI Object│
    │   DB     │   │  Cache  │   │ Storage  │
    └─────────┘   └─────────┘   └─────────┘
```

### 1.2 핵심 설계 원칙
- **BLE는 탐색용**: 사용자 발견 및 근접성 확인만 수행
- **서버는 채팅용**: 모든 메시지는 서버 경유로 안정성 확보
- **휘발성 보장**: 24시간 TTL 자동 관리
- **익명성 보호**: UUID 무작위화, 닉네임 마스킹

---

## 2. 기술 스택 상세

### 2.1 클라이언트 (Mobile App)

#### iOS
- **언어**: Swift 5.0+
- **BLE**: CoreBluetooth Framework
- **네트워킹**: URLSession, WebSocket (Starscream)
- **인증**: AuthenticationServices (Apple Sign In)
- **푸시**: UserNotifications, APNs
- **아키텍처**: MVVM + Combine
- **의존성 관리**: Swift Package Manager

#### Android
- **언어**: Kotlin 1.8+
- **BLE**: Android Bluetooth Low Energy API
- **네트워킹**: Retrofit, OkHttp, WebSocket (okhttp-ws)
- **인증**: Firebase Auth (Google Sign In)
- **푸시**: Firebase Cloud Messaging (FCM)
- **아키텍처**: MVVM + LiveData/Flow
- **의존성 관리**: Gradle

### 2.2 백엔드 서버

#### 런타임
- **Node.js**: 18.x LTS ✅
- **프레임워크**: Express.js 4.x ✅
- **실시간 통신**: Socket.io 4.x ✅
- **인증**: jsonwebtoken, bcrypt ✅
- **암호화**: crypto (AES-256) ✅

#### 데이터베이스
- **PostgreSQL**: 13+ ✅ (Oracle Cloud VM에 설치)
- **Redis**: 6+ ✅ (세션 관리, 캐싱)

#### 배포 환경
- **인프라**: Oracle Cloud Infrastructure (Free Tier) ✅
- **웹 서버**: Nginx (리버스 프록시) ✅
- **도메인**: yeop3.com ✅
- **SSL/TLS**: Cloudflare Flexible 모드 (임시 자체 서명 인증서)

#### 데이터베이스
- **PostgreSQL**: 13+ (주 데이터베이스) ✅
  - 채팅방, 메시지, 사용자 정보 저장
  - TTL 인덱스로 자동 삭제 관리
- **Redis**: 7.0+ (캐시 및 세션)
  - 실시간 세션 관리
  - 사용자 온라인 상태
  - BLE 탐색 결과 캐싱
  - TTL 기반 자동 만료

#### 스토리지
- **OCI Object Storage**: 이미지, 이모지 파일 저장 (예정)
- **CDN**: CloudFront (이미지 전송 최적화)

#### 푸시 알림
- **FCM**: Android 푸시 알림
- **APNs**: iOS 푸시 알림
- **서비스**: Firebase Admin SDK

#### 인증 서비스
- **Firebase Auth**: 이메일, Google 로그인
- **Apple Sign In**: iOS 네이티브 인증

### 2.3 인프라 및 DevOps

#### 클라우드
- **OCI**: Compute VM, Object Storage, Load Balancer
- **또는**: Google Cloud Platform (Firebase 기반)

#### 모니터링
- **로깅**: Winston (Node.js), CloudWatch
- **에러 추적**: Sentry
- **성능 모니터링**: New Relic / Datadog

#### CI/CD
- **GitHub Actions**: 자동 빌드 및 배포
- **Docker**: 컨테이너화
- **Kubernetes** (선택): 스케일링 관리

---

## 3. 시스템 구조

### 3.1 클라이언트 구조

#### iOS 앱 구조
```
YEO.PE iOS/
├── App/
│   ├── AppDelegate.swift
│   └── SceneDelegate.swift
├── Models/
│   ├── User.swift
│   ├── Room.swift
│   ├── Message.swift
│   └── BLEDevice.swift
├── ViewModels/
│   ├── BLEExplorerViewModel.swift
│   ├── ChatViewModel.swift
│   └── AuthViewModel.swift
├── Views/
│   ├── MainView.swift
│   ├── ChatView.swift
│   └── SettingsView.swift
├── Services/
│   ├── BLEService.swift
│   ├── WebSocketService.swift
│   ├── APIService.swift
│   └── PushService.swift
└── Utils/
    ├── Encryption.swift
    └── TokenManager.swift
```

#### Android 앱 구조
```
YEO.PE Android/
├── app/
│   ├── src/main/java/com/yeope/
│   │   ├── MainActivity.kt
│   │   ├── models/
│   │   │   ├── User.kt
│   │   │   ├── Room.kt
│   │   │   └── Message.kt
│   │   ├── viewmodels/
│   │   │   ├── BLEViewModel.kt
│   │   │   └── ChatViewModel.kt
│   │   ├── views/
│   │   │   ├── MainFragment.kt
│   │   │   └── ChatFragment.kt
│   │   ├── services/
│   │   │   ├── BLEService.kt
│   │   │   ├── WebSocketService.kt
│   │   │   └── PushService.kt
│   │   └── utils/
│   │       └── Encryption.kt
```

### 3.2 서버 구조

```
server/
├── src/
│   ├── index.js              # 서버 진입점
│   ├── config/
│   │   ├── database.js       # PostgreSQL 연결 ✅
│   │   ├── redis.js          # Redis 연결 ✅
│   │   ├── auth.js           # JWT 설정 ✅
│   │   └── oci.js            # OCI Object Storage 설정 (예정)
│   ├── models/               # PostgreSQL 스키마 (database/init.sql) ✅
│   │   └── (SQL 스키마로 구현됨)
│   ├── routes/
│   │   ├── auth.js           # 인증 API ✅
│   │   ├── rooms.js          # 방 관련 API ✅
│   │   └── messages.js       # 메시지 API ✅
│   ├── socket/
│   │   ├── socketHandler.js  # WebSocket 핸들러 ✅
│   │   ├── roomHandler.js    # 방 관련 소켓 이벤트 ✅
│   │   └── messageHandler.js # 메시지 소켓 이벤트 ✅
│   ├── services/
│   │   ├── userService.js    # 사용자 서비스 ✅
│   │   ├── roomService.js    # 방 관리 서비스 ✅
│   │   ├── messageService.js # 메시지 서비스 ✅
│   │   ├── ttlService.js     # TTL 관리 서비스 ✅
│   │   ├── bleService.js     # BLE 탐색 로직 (예정)
│   │   ├── pushService.js    # 푸시 알림 서비스 (예정)
│   │   └── encryption.js     # 암호화 서비스 (예정)
│   ├── middleware/
│   │   ├── auth.js           # JWT 인증 미들웨어 ✅
│   │   ├── validation.js     # 입력 검증 ✅
│   │   └── rateLimit.js      # Rate Limiting ✅
│   └── utils/
│       ├── logger.js         # Winston 로깅 유틸 ✅
│       ├── errors.js         # 커스텀 에러 클래스 ✅
│       └── nickname.js       # 닉네임 마스킹 유틸 ✅
├── database/
│   ├── init.sql              # PostgreSQL 스키마 초기화 ✅
│   └── ttl_cleanup.sql       # TTL 정리 함수 ✅
├── nginx/
│   ├── yeop3.com.conf        # Nginx 설정 파일 ✅
│   └── README.md             # Nginx 설정 가이드 ✅
├── tests/
│   ├── api.test.js           # API 통합 테스트 ✅
│   ├── websocket.test.js     # WebSocket 테스트 ✅
│   ├── websocket-client.js   # WebSocket 클라이언트 테스트 도구 ✅
│   ├── websocket-test.html   # 브라우저 WebSocket 테스트 ✅
│   ├── manual-test.md        # 수동 테스트 가이드 ✅
│   └── test-helper.js        # 테스트 헬퍼 ✅
└── package.json
```

---

## 4. 데이터베이스 설계

### 4.1 PostgreSQL 스키마 ✅

**데이터베이스**: `yeope`  
**스키마**: `yeope_schema`  
**사용자**: `yeope_user`

> **참고**: 초기 설계는 MongoDB였으나, Oracle Cloud Free Tier 최적화를 위해 PostgreSQL로 변경되었습니다.

#### Users 테이블 ✅
```sql
CREATE TABLE yeope_schema.users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  auth_provider VARCHAR(50) NOT NULL, -- 'email', 'google', 'apple'
  provider_id VARCHAR(255),
  nickname VARCHAR(100) NOT NULL,
  nickname_mask VARCHAR(100) NOT NULL,
  password_hash VARCHAR(255), -- 이메일 로그인 시에만 사용
  created_at TIMESTAMP DEFAULT NOW(),
  last_login_at TIMESTAMP,
  is_active BOOLEAN DEFAULT true,
  settings JSONB DEFAULT '{"bleVisible": true, "pushEnabled": true}'::jsonb,
  CONSTRAINT unique_provider_id UNIQUE(auth_provider, provider_id)
);
```

**인덱스**:
- `idx_users_email`: email (UNIQUE)
- `idx_users_created_at`: created_at
- `idx_users_provider`: auth_provider, provider_id

#### Rooms 테이블 ✅
```sql
CREATE TABLE yeope_schema.rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id VARCHAR(36) UNIQUE NOT NULL, -- UUID 문자열
  name VARCHAR(255) NOT NULL,
  creator_id UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  expires_at TIMESTAMP NOT NULL,
  member_count INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  metadata JSONB DEFAULT '{"category": "general"}'::jsonb
);
```

**인덱스**:
- `idx_rooms_room_id`: room_id (UNIQUE)
- `idx_rooms_expires_at`: expires_at
- `idx_rooms_created_at`: created_at
- `idx_rooms_creator_id`: creator_id
- `idx_rooms_active`: is_active, expires_at (부분 인덱스)

#### Messages 테이블 ✅
```sql
CREATE TABLE yeope_schema.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  type VARCHAR(50) NOT NULL, -- 'text', 'image', 'emoji'
  content TEXT, -- 암호화된 메시지
  encrypted_content TEXT, -- AES-256 암호화된 원본
  image_url TEXT, -- Object Storage 이미지 URL
  created_at TIMESTAMP DEFAULT NOW(),
  expires_at TIMESTAMP NOT NULL,
  is_deleted BOOLEAN DEFAULT false
);
```

**인덱스**:
- `idx_messages_room_created`: room_id, created_at DESC
- `idx_messages_expires_at`: expires_at
- `idx_messages_user_id`: user_id
- `idx_messages_room_active`: room_id, created_at DESC (부분 인덱스, is_deleted = false)

#### RoomMembers 테이블 (참여자 관리) ✅
```sql
CREATE TABLE yeope_schema.room_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  joined_at TIMESTAMP DEFAULT NOW(),
  left_at TIMESTAMP,
  role VARCHAR(50) DEFAULT 'member', -- 'member', 'creator'
  last_seen_at TIMESTAMP DEFAULT NOW(),
  CONSTRAINT unique_room_user_active UNIQUE(room_id, user_id, left_at)
);
```

**인덱스**:
- `idx_room_members_room_user`: room_id, user_id
- `idx_room_members_user_active`: user_id, left_at (부분 인덱스, left_at IS NULL)
- `idx_room_members_room_active`: room_id, left_at (부분 인덱스, left_at IS NULL)

### 4.2 TTL 자동 정리 ✅

PostgreSQL 함수를 사용하여 만료된 데이터를 자동으로 정리합니다:

```sql
CREATE OR REPLACE FUNCTION yeope_schema.cleanup_expired_data()
RETURNS void AS $$
BEGIN
    -- 만료된 방 삭제 (CASCADE로 메시지, 멤버도 삭제)
    DELETE FROM yeope_schema.rooms
    WHERE expires_at < NOW();

    -- 만료된 메시지 삭제
    DELETE FROM yeope_schema.messages
    WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;
```

Node.js cron 작업으로 1시간마다 실행됩니다 (`src/services/ttlService.js`).

### 4.3 Redis 구조

#### 세션 관리
```
Key: session:{userId}
Value: {
  token: String,
  lastActiveAt: Timestamp,
  deviceInfo: Object
}
TTL: 7일
```

#### 사용자 온라인 상태
```
Key: online:{userId}
Value: timestamp
TTL: 5분 (주기적 갱신 필요)
```

#### BLE 탐색 결과 캐시
```
Key: ble:scan:{userId}
Value: [{
  deviceId: String,
  nickname: String,
  rssi: Number,
  timestamp: Number
}]
TTL: 30초
```

#### 활성 방 목록 (지역별)
```
Key: rooms:active:{region}
Value: Set of roomIds
TTL: 1시간
```

#### 방 참여자 목록 (실시간)
```
Key: room:members:{roomId}
Value: Set of userIds
TTL: 방 만료 시 자동 삭제
```

---

## 5. API 설계

### 5.1 인증 API

#### POST /api/auth/register
**요청**:
```json
{
  "email": "user@example.com",
  "password": "hashedPassword",
  "nickname": "사용자닉네임"
}
```

**응답**:
```json
{
  "token": "jwt_token",
  "user": {
    "id": "user_id",
    "nickname": "사용자닉네임",
    "nicknameMask": "사용**"
  }
}
```

#### POST /api/auth/login
**요청**:
```json
{
  "email": "user@example.com",
  "password": "hashedPassword"
}
```

#### POST /api/auth/oauth/google
**요청**:
```json
{
  "idToken": "google_id_token"
}
```

#### POST /api/auth/oauth/apple
**요청**:
```json
{
  "identityToken": "apple_identity_token",
  "authorizationCode": "authorization_code"
}
```

#### POST /api/auth/logout
**헤더**: `Authorization: Bearer {token}`

#### DELETE /api/auth/account
**헤더**: `Authorization: Bearer {token}`  
**설명**: 회원 탈퇴

### 5.2 방 (Room) API

#### POST /api/rooms
**설명**: 새 방 생성 (인증 필요)  
**헤더**: `Authorization: Bearer {token}`  
**요청**:
```json
{
  "name": "방 이름",
  "category": "general"
}
```

**응답**:
```json
{
  "roomId": "uuid",
  "name": "방 이름",
  "createdAt": "2024-01-01T00:00:00Z",
  "expiresAt": "2024-01-02T00:00:00Z"
}
```

#### GET /api/rooms/nearby
**설명**: 근처 활성 방 목록 조회  
**헤더**: `Authorization: Bearer {token}` (선택)  
**쿼리 파라미터**:
- `limit`: 10 (기본값)
- `category`: "general" | "transport" | "event" | "venue"

**응답**:
```json
{
  "rooms": [
    {
      "roomId": "uuid",
      "name": "방 이름",
      "memberCount": 5,
      "createdAt": "2024-01-01T00:00:00Z"
    }
  ]
}
```

#### POST /api/rooms/:roomId/join
**설명**: 방 참여 (인증 필요)  
**헤더**: `Authorization: Bearer {token}`

**응답**:
```json
{
  "roomId": "uuid",
  "joinedAt": "2024-01-01T00:00:00Z"
}
```

#### POST /api/rooms/:roomId/leave
**설명**: 방 나가기  
**헤더**: `Authorization: Bearer {token}`

#### GET /api/rooms/:roomId
**설명**: 방 상세 정보 조회

**응답**:
```json
{
  "roomId": "uuid",
  "name": "방 이름",
  "memberCount": 5,
  "createdAt": "2024-01-01T00:00:00Z",
  "expiresAt": "2024-01-02T00:00:00Z"
}
```

#### GET /api/rooms/:roomId/members
**설명**: 방 멤버 목록 조회  
**헤더**: `Authorization: Bearer {token}`

**응답**:
```json
{
  "members": [
    {
      "userId": "user_id",
      "nicknameMask": "김**",
      "joinedAt": "2024-01-01T00:00:00Z"
    }
  ]
}
```

### 5.3 메시지 API

#### GET /api/rooms/:roomId/messages
**설명**: 메시지 목록 조회  
**헤더**: `Authorization: Bearer {token}` (선택, 비회원도 읽기 가능)  
**쿼리 파라미터**:
- `before`: 메시지 ID (페이징)
- `limit`: 50 (기본값)

**응답**:
```json
{
  "messages": [
    {
      "messageId": "msg_id",
      "userId": "user_id",
      "nicknameMask": "김**",
      "type": "text",
      "content": "암호화 해제된 메시지",
      "createdAt": "2024-01-01T00:00:00Z"
    }
  ],
  "hasMore": true
}
```

#### POST /api/rooms/:roomId/messages
**설명**: 메시지 전송 (인증 필요)  
**헤더**: `Authorization: Bearer {token}`  
**요청**:
```json
{
  "type": "text",
  "content": "메시지 내용"
}
```

또는 이미지:
```json
{
  "type": "image",
  "imageUrl": "https://objectstorage.{region}.oraclecloud.com/..."
}
```

**응답**:
```json
{
  "messageId": "msg_id",
  "createdAt": "2024-01-01T00:00:00Z"
}
```

#### DELETE /api/messages/:messageId
**설명**: 메시지 삭제 (본인만 가능)  
**헤더**: `Authorization: Bearer {token}`

### 5.4 파일 업로드 API

#### POST /api/upload/image
**설명**: 이미지 업로드 (인증 필요)  
**헤더**: `Authorization: Bearer {token}`  
**Content-Type**: `multipart/form-data`

**요청**: FormData
- `image`: File (max 5MB)
- `roomId`: String (선택)

**응답**:
```json
{
  "imageUrl": "https://objectstorage.{region}.oraclecloud.com/n/{namespace}/b/{bucket}/o/images/{roomId}/{messageId}.jpg",
  "thumbnailUrl": "https://objectstorage.{region}.oraclecloud.com/n/{namespace}/b/{bucket}/o/images/{roomId}/{messageId}_thumb.jpg"
}
```

### 5.5 사용자 API

#### GET /api/users/me
**설명**: 현재 사용자 정보 조회  
**헤더**: `Authorization: Bearer {token}`

**응답**:
```json
{
  "userId": "user_id",
  "email": "user@example.com",
  "nickname": "사용자닉네임",
  "nicknameMask": "사용**",
  "settings": {
    "bleVisible": true,
    "pushEnabled": true
  }
}
```

#### PATCH /api/users/me
**설명**: 사용자 정보 수정  
**헤더**: `Authorization: Bearer {token}`  
**요청**:
```json
{
  "nickname": "새닉네임",
  "settings": {
    "bleVisible": false
  }
}
```

#### GET /api/users/ble/scan
**설명**: BLE 탐색 결과 조회 (캐시된 결과)  
**헤더**: `Authorization: Bearer {token}`  
**설명**: 클라이언트에서 BLE 스캔 후 결과를 서버에 업로드한 경우

### 5.6 푸시 알림 API

#### POST /api/push/register
**설명**: FCM/APNs 토큰 등록  
**헤더**: `Authorization: Bearer {token}`  
**요청**:
```json
{
  "deviceToken": "fcm_or_apns_token",
  "platform": "ios" | "android"
}
```

---

## 6. BLE 통신 설계

### 6.1 BLE 역할 분담

- **Central (스캐너)**: 주변 장치 탐색
- **Peripheral (광고자)**: 자신을 광고

**모든 클라이언트는 두 역할을 동시 수행**:
- 주변 사용자 탐색 (Central)
- 자신의 존재 알림 (Peripheral)

### 6.2 BLE 서비스 및 특성 정의

#### Service UUID
```
Service UUID: 0000FEED-0000-1000-8000-00805F9B34FB
```

#### Characteristics

##### 1. Device Info (읽기 전용)
```
UUID: 0000FEED-0001-1000-8000-00805F9B34FB
Value: {
  "deviceId": "random_uuid",    // 매 세션마다 변경
  "userId": "hashed_user_id",   // 해시된 사용자 ID
  "nickname": "김**",            // 마스킹된 닉네임
  "timestamp": 1234567890
}
```

##### 2. Room Invite (읽기/쓰기)
```
UUID: 0000FEED-0002-1000-8000-00805F9B34FB
Value: {
  "roomId": "uuid",
  "roomName": "방 이름",
  "inviterId": "user_id",
  "timestamp": 1234567890
}
```

### 6.3 BLE 탐색 프로토콜

#### 1단계: 주변 장치 스캔
```swift
// iOS 예시
let serviceUUID = CBUUID(string: "0000FEED-0000-1000-8000-00805F9B34FB")
centralManager.scanForPeripherals(
  withServices: [serviceUUID],
  options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
)
```

#### 2단계: 발견된 장치 정보 수집
- **RSSI**: 신호 강도로 거리 추정
- **Device Info**: 닉네임, 사용자 ID 해시
- **타임스탬프**: 탐색 시간 기록

#### 3단계: 서버에 탐색 결과 전송
클라이언트는 주기적으로(30초마다) 탐색 결과를 서버에 전송:
```json
POST /api/users/ble/scan
{
  "devices": [
    {
      "deviceId": "random_uuid",
      "userId": "hashed_user_id",
      "nickname": "김**",
      "rssi": -65,
      "timestamp": 1234567890
    }
  ]
}
```

#### 4단계: 서버가 근처 사용자 매칭
- 서버는 BLE 탐색 결과를 기반으로 근처 사용자 그룹을 생성
- 같은 방에 참여 가능한 사용자 목록 제공

### 6.4 방 초대 프로토콜 (BLE)

#### 시나리오: 사용자 A가 방을 생성하고 사용자 B를 초대

1. **사용자 A**: 방 생성 후 BLE로 Room Invite 특성에 데이터 쓰기
2. **사용자 B**: BLE 스캔 중 Room Invite 특성 변경 감지
3. **사용자 B**: 서버에 푸시 알림 요청
4. **서버**: 사용자 B에게 푸시 알림 전송
5. **사용자 B**: 푸시 알림 수신 후 방 참여 승인

### 6.5 BLE 보안 고려사항

- **UUID 무작위화**: 매 앱 세션마다 새로운 UUID 생성
- **사용자 ID 해싱**: 실제 사용자 ID는 해시값으로만 전송
- **RSSI 임계값**: 너무 약한 신호(-90dBm 이하)는 무시
- **타임스탬프 검증**: 오래된 데이터는 무시

---

## 7. 실시간 통신 설계

### 7.1 WebSocket 연결

#### 연결 엔드포인트
```
wss://api.yeo.pe/socket?token={jwt_token}
```

#### 인증
- **쿼리 파라미터**: JWT 토큰
- **연결 실패 시**: 401 Unauthorized → 재로그인 필요

### 7.2 WebSocket 이벤트

#### 클라이언트 → 서버

##### join-room
```json
{
  "event": "join-room",
  "data": {
    "roomId": "uuid"
  }
}
```

##### leave-room
```json
{
  "event": "leave-room",
  "data": {
    "roomId": "uuid"
  }
}
```

##### send-message
```json
{
  "event": "send-message",
  "data": {
    "roomId": "uuid",
    "type": "text",
    "content": "메시지 내용"
  }
}
```

##### typing
```json
{
  "event": "typing",
  "data": {
    "roomId": "uuid",
    "isTyping": true
  }
}
```

#### 서버 → 클라이언트

##### room-joined
```json
{
  "event": "room-joined",
  "data": {
    "roomId": "uuid",
    "memberCount": 5
  }
}
```

##### room-left
```json
{
  "event": "room-left",
  "data": {
    "roomId": "uuid"
  }
}
```

##### new-message
```json
{
  "event": "new-message",
  "data": {
    "messageId": "msg_id",
    "roomId": "uuid",
    "userId": "user_id",
    "nicknameMask": "김**",
    "type": "text",
    "content": "메시지 내용",
    "createdAt": "2024-01-01T00:00:00Z"
  }
}
```

##### user-joined
```json
{
  "event": "user-joined",
  "data": {
    "roomId": "uuid",
    "userId": "user_id",
    "nicknameMask": "김**",
    "memberCount": 6
  }
}
```

##### user-left
```json
{
  "event": "user-left",
  "data": {
    "roomId": "uuid",
    "userId": "user_id",
    "memberCount": 5
  }
}
```

##### typing-indicator
```json
{
  "event": "typing-indicator",
  "data": {
    "roomId": "uuid",
    "userId": "user_id",
    "nicknameMask": "김**",
    "isTyping": true
  }
}
```

##### room-expired
```json
{
  "event": "room-expired",
  "data": {
    "roomId": "uuid"
  }
}
```

### 7.3 실시간 상태 관리

#### Redis Pub/Sub 구조
서버는 여러 인스턴스로 확장 가능하도록 Redis Pub/Sub 사용:

```
Channel: room:{roomId}
Message: {
  "event": "new-message",
  "data": {...}
}
```

#### Socket.io Rooms
```javascript
// 서버 측
socket.join(`room:${roomId}`);
socket.to(`room:${roomId}`).emit('new-message', data);
```

---

## 8. 보안 설계

### 8.1 인증 및 인가

#### JWT 토큰 구조
```json
{
  "userId": "user_id",
  "email": "user@example.com",
  "iat": 1234567890,
  "exp": 1234654290,  // 7일
  "type": "access"
}
```

#### 토큰 갱신
- **Access Token**: 7일 (짧은 만료)
- **Refresh Token**: 30일 (Redis 저장)
- **갱신 엔드포인트**: `POST /api/auth/refresh`

### 8.2 암호화

#### 메시지 암호화 (AES-256)
- **알고리즘**: AES-256-GCM
- **키 관리**: 방별로 고유 키 생성 (Room 생성 시)
- **키 저장**: 서버에서 암호화하여 저장 (PostgreSQL)
- **전송**: 클라이언트는 암호화된 메시지만 수신

#### 전송 암호화
- **HTTPS/WSS**: 모든 통신은 TLS 1.3
- **인증서**: Let's Encrypt (무료) + Certbot 자동 갱신
- **OCI SSL/TLS**: Load Balancer SSL 인증서 (선택적)

### 8.3 개인정보 보호

#### 닉네임 마스킹 규칙
```javascript
// 예: "김철수" → "김**"
function maskNickname(nickname) {
  if (nickname.length <= 2) return nickname[0] + '*';
  return nickname[0] + '*'.repeat(nickname.length - 1);
}
```

#### BLE UUID 무작위화
- 매 앱 실행 시 새로운 UUID 생성
- 서버에 저장하지 않음
- 세션 종료 시 즉시 폐기

### 8.4 악용 방지

#### Rate Limiting
- **메시지 전송**: 초당 5개, 분당 30개
- **방 생성**: 시간당 10개
- **API 호출**: 분당 100회

#### 콘텐츠 필터링
- **부적절한 단어 필터링**: 정규식 + 키워드 리스트
- **이미지 검증**: 외부 API 사용 (예: Google Cloud Vision API - 무료 플랜) 또는 오픈소스 라이브러리
- **자동 차단**: 신고 누적 시 자동 차단

#### 로깅 및 모니터링
- **의심스러운 활동 로깅**: 과도한 메시지 전송, 다중 계정
- **자동 알림**: 이상 패턴 감지 시 관리자 알림

---

## 9. 인프라 설계 (Oracle Cloud Infrastructure)

> **참고**: 본 설계는 Oracle Cloud 무료 티어(Always Free) 기준으로 작성되었습니다.

### 9.1 Oracle Cloud 무료 티어 제한사항

#### 제공되는 무료 리소스
- **Compute VM**: AMD 기반 2개 (각 1/8 OCPU, 1GB RAM) 또는 ARM Ampere A1 4개 (각 1 OCPU, 6GB RAM)
- **Object Storage**: 10GB 무료
- **Load Balancer**: 10Mbps 무료 (제한적)
- **Block Volume**: 200GB 무료
- **VCN (Virtual Cloud Network)**: 무료
- **Monitoring**: 기본 메트릭 무료

#### 제한사항
- **대역폭**: 월 10TB (무료 티어)
- **Load Balancer**: 10Mbps 제한 (무료 티어)
- **Compute**: 24시간 활성화 제한 없음 (무료 티어)
- **리전**: 한 리전 내에서만 무료 리소스 사용 가능

### 9.2 서버 아키텍처

#### 초기 구조 (MVP) - Oracle Cloud 무료 티어
```
┌─────────────────────┐
│   Load Balancer      │
│ (OCI LB - 10Mbps)    │
│   [선택사항]          │
└──────────┬───────────┘
           │
      ┌────┴────┐
      │         │
┌─────▼───┐ ┌──▼─────┐
│  App    │ │  App   │
│ Server  │ │ Server │
│ (VM)    │ │ (VM)   │
│1/8 OCPU │ │1/8 OCPU│
│ 1GB RAM │ │ 1GB RAM│
└────┬────┘ └──┬─────┘
     │         │
     └────┬────┘
          │
    ┌─────▼─────┐
    │  MongoDB  │
    │ (VM 설치) │
    │ 또는 Atlas│
    └───────────┘
```

#### 권장 구조 (ARM Ampere A1 사용 시)
```
┌─────────────────┐
│  Load Balancer   │
│  (OCI LB - 선택) │
└────────┬─────────┘
         │
    ┌────┴────┐
    │         │
┌───▼───┐ ┌──▼───┐
│  App  │ │  App │
│Server │ │Server│
│(VM)   │ │(VM)  │
│1 OCPU │ │1 OCPU│
│6GB RAM│ │6GB RAM│
└───┬───┘ └──┬───┘
    │        │
    └───┬────┘
        │
   ┌────▼────┐
   │PostgreSQL│
   │  + Redis│
   │ (VM 설치)│
   └─────────┘
```

#### 확장 구조 (유료 전환 시)
```
┌─────────────────┐
│   CDN (선택)     │
│  Cloudflare     │
│   (무료 플랜)    │
└────────┬────────┘
         │
┌────────▼────────┐
│   Load Balancer │
│  (OCI LB)       │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
┌───▼───┐ ┌──▼───┐
│  App  │ │  App │
│Server │ │Server│
│(VM)   │ │(VM)  │
└───┬───┘ └──┬───┘
    │        │
    └───┬────┘
        │
   ┌────▼────┐
   │  Redis  │
   │ (VM 설치)│
   └────┬────┘
        │
   ┌────▼────┐
   │PostgreSQL│
   │ (VM 설치)│
   └─────────┘
```

### 9.3 스토리지 구조

#### OCI Object Storage 버킷 구조
```
yeope-media/
├── images/
│   ├── {roomId}/
│   │   ├── {messageId}.jpg
│   │   └── {messageId}_thumb.jpg
│   └── avatars/ (향후 확장)
└── temp/ (임시 업로드)
```

#### Object Storage 설정
- **네임스페이스**: 고유한 네임스페이스 사용
- **버킷 타입**: Standard (자주 접근)
- **버전 관리**: 활성화 (선택적)
- **라이프사이클 정책**: 24시간 후 자동 삭제 (TTL과 동일)

#### CDN 설정 (선택)
- **Cloudflare**: 무료 플랜 사용 (Object Storage와 연동)
- **또는**: Object Storage 직접 사용 (직접 URL 제공)
- **캐시 정책**: 이미지는 24시간 캐시 (방 만료와 동일)

### 9.4 데이터베이스 설정

#### 옵션 1: VM에 직접 설치 (현재 사용 중) ✅
**Compute VM에 PostgreSQL 및 Redis 설치**
- **PostgreSQL**: 13+ (무료, 오픈소스)
- **Redis**: 6+ (무료, 오픈소스)
- **설치 방법**: 직접 설치 (yum/dnf)
- **백업**: Cron 작업으로 자동 백업 (Object Storage에 저장 예정)
- **리소스**: VM 리소스 공유 사용

**장점**: 완전 무료, 유연한 설정, Oracle Cloud Free Tier 최적화  
**단점**: 관리 필요, 백업 직접 구성

#### 옵션 2: Oracle Autonomous Database (무료 티어)
- **타입**: Always Free (20GB)
- **리전**: ap-seoul-1 (서울 리전)
- **백업**: 자동 백업 (무료 티어)
- **제한**: 20GB 스토리지, OCPU 제한

**장점**: 관리형 서비스, 자동 백업, 확장성  
**단점**: 초기 설정 복잡, 무료 티어 제한

**현재 상태**: VM에 직접 설치된 PostgreSQL 사용 중 ✅

#### Redis 설정 (VM 설치)
- **모드**: Standalone (초기) → Sentinel (고가용성)
- **메모리**: VM 메모리 할당 (1-2GB 권장)
- **영속성**: RDB + AOF 활성화
- **백업**: Object Storage에 주기적 백업

### 9.5 모니터링 및 로깅

#### OCI Monitoring
- **메트릭**: CPU, Memory, Network, Disk I/O
- **알람**: CPU > 80%, Memory > 90%
- **대시보드**: 커스텀 대시보드 생성
- **비용**: 기본 메트릭 무료, 상세 메트릭은 유료

#### OCI Logging
- **로그 수집**: 애플리케이션 로그 수집
- **저장**: Object Storage 또는 Logging 서비스
- **비용**: 일일 10GB 무료 (무료 티어)

#### 외부 모니터링 (무료)
- **Sentry**: 에러 추적 (무료 플랜)
- **Uptime Robot**: 서버 가동 시간 모니터링 (무료)
- **Grafana Cloud**: 메트릭 시각화 (무료 플랜)

---

## 10. 배포 전략

### 10.1 개발 환경

#### 로컬 개발
- **Docker Compose**: PostgreSQL, Redis 로컬 실행 (선택적)
- **환경 변수**: `.env` 파일 관리
- **Hot Reload**: nodemon 사용

### 10.2 CI/CD 파이프라인

#### GitHub Actions 워크플로우 (OCI)
```yaml
# .github/workflows/deploy.yml
name: Deploy to OCI
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Node.js
        uses: actions/setup-node@v2
      - name: Install dependencies
        run: npm ci
      - name: Run tests
        run: npm test
      - name: Build Docker image
        run: docker build -t yeope:latest .
      - name: Deploy to OCI VM
        uses: oracle-actions/oci-cli@v1
        env:
          OCI_CLI_USER: ${{ secrets.OCI_CLI_USER }}
          OCI_CLI_TENANCY: ${{ secrets.OCI_CLI_TENANCY }}
          OCI_CLI_FINGERPRINT: ${{ secrets.OCI_CLI_FINGERPRINT }}
          OCI_CLI_KEY: ${{ secrets.OCI_CLI_KEY }}
        run: |
          # OCI VM에 SSH로 접속하여 배포
          ssh user@vm-ip "cd /opt/yeope && git pull && npm install && pm2 restart yeope"
```

### 10.3 배포 단계

#### 1. Staging 환경
- **브랜치**: `staging`
- **자동 배포**: PR 머지 시
- **테스트**: 자동화된 테스트 실행

#### 2. Production 환경
- **브랜치**: `main`
- **수동 승인**: 배포 전 승인 필요
- **롤백 계획**: 이전 버전으로 즉시 롤백 가능

### 10.4 환경 변수 관리

#### OCI Vault (선택)
- **비밀 관리**: 민감한 정보 저장 (JWT Secret, DB Password)
- **비용**: 무료 티어 제한적 (유료 전환 시 권장)

#### 초기 설정 (무료 티어)
- **환경 변수 파일**: `.env` 파일 사용 (VM에 저장)
- **보안**: 파일 권한 제한 (chmod 600)
- **백업**: Object Storage에 암호화하여 백업

```
/opt/yeope/.env
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=yeope
POSTGRES_USER=yeope_user
POSTGRES_PASSWORD=your_password
REDIS_URI=redis://localhost:6379
JWT_SECRET=your_secret_key
OCI_OBJECT_STORAGE_NAMESPACE=your_namespace
OCI_BUCKET_NAME=yeope-media
```

---

## 11. 확장성 고려사항

### 11.1 수평 확장

#### 서버 확장
- **로드 밸런서**: OCI Load Balancer로 자동 분산
- **세션 관리**: Redis를 통한 세션 공유
- **WebSocket**: Socket.io Redis Adapter 사용
- **Auto Scaling**: OCI Auto Scaling (유료 전환 시)

#### 데이터베이스 확장
- **PostgreSQL**: Read Replica (읽기 분산), 또는 Oracle Autonomous Database로 마이그레이션
- **Redis**: Sentinel (고가용성) 또는 Cluster Mode (메모리 확장)

### 11.2 성능 최적화

#### 캐싱 전략
- **Redis**: 활성 방 목록, 사용자 세션
- **CDN**: 이미지 파일 (Cloudflare 무료 플랜 또는 Object Storage 직접)
- **인메모리 캐시**: Node.js 메모리 캐시 (짧은 TTL)
- **Object Storage**: 이미지 직접 제공 (퍼블릭 URL)

#### 데이터베이스 최적화
- **인덱스**: 자주 조회되는 필드에 인덱스 ✅
- **TTL 정리**: PostgreSQL 함수 및 cron 작업으로 자동 삭제 ✅
- **쿼리 최적화**: EXPLAIN ANALYZE 활용, 인덱스 튜닝

### 11.3 비용 최적화 (Oracle Cloud)

#### 무료 티어 최적화
- **VM 리소스 효율화**: PostgreSQL과 Redis를 동일 VM에 설치 (현재 상태) ✅
- **Object Storage**: 10GB 무료 한도 내에서 사용
- **이미지 압축**: 업로드 시 자동 리사이징 (용량 절약)
- **TTL 정책**: Object Storage Lifecycle로 24시간 후 자동 삭제

#### 유료 전환 시 최적화
- **OCI Functions**: 이미지 리사이징 (서버리스)
- **OCI Events**: TTL 관리 스케줄러
- **Reserved Instances**: 장기 사용 시 할인
- **Cost Management**: 사용량 모니터링 및 알림 설정

#### 스토리지 최적화
- **Object Storage Lifecycle**: 24시간 후 이미지 자동 삭제
- **이미지 압축**: Sharp 라이브러리로 업로드 시 자동 리사이징
- **썸네일 생성**: 원본과 썸네일 분리 저장 (용량 절약)

---

## 12. 개발 우선순위 및 진행 상황

### ✅ Phase 1: 핵심 기능 (완료)
1. ✅ 프로젝트 기본 구조 설정
2. ✅ PostgreSQL 데이터베이스 설정 및 스키마 생성
3. ✅ Node.js 서버 기본 설정 (Express.js, Socket.io)
4. ✅ 사용자 인증 (이메일 회원가입/로그인, JWT)
5. ✅ 방 생성 및 참여 API
6. ✅ 실시간 채팅 (WebSocket, Socket.io)
7. ✅ 휘발성 방 정책 (24시간 TTL 자동 정리)
8. ✅ 닉네임 마스킹 기능
9. ✅ 서버 배포 (Oracle Cloud Infrastructure)
10. ✅ 도메인 설정 (yeop3.com, Nginx 리버스 프록시)

### 🚧 Phase 2: 부가 기능 (진행 중)
1. 🚧 이미지 업로드 (OCI Object Storage 연동 예정)
2. 🚧 푸시 알림 (Firebase Cloud Messaging 연동 예정)
3. ✅ 닉네임 마스킹 (완료)
4. 📋 비회원 모드 (예정)
5. 📋 Google/Apple 소셜 로그인 (예정)
6. 📋 BLE 탐색 기능 (모바일 앱 개발 시 구현)

### 📋 Phase 3: 최적화 (예정)
1. 📋 성능 최적화 (Redis 캐싱 강화, 쿼리 최적화)
2. 📋 보안 강화 (메시지 암호화, Rate Limiting 강화)
3. 📋 모니터링 구축 (로깅 시스템, 에러 추적)
4. 📋 PM2 프로세스 관리 설정
5. 📋 Let's Encrypt SSL 인증서 발급 (Full 모드 전환)

---

## 14. 배포 정보 ✅

### 프로덕션 환경

- **서버**: Oracle Cloud Infrastructure (Free Tier)
  - **인스턴스 IP**: 152.67.208.177
  - **OS**: Oracle Linux 9
  - **Node.js**: 18.x
  - **PostgreSQL**: 13+ (VM에 직접 설치)
  - **Redis**: 6+ (VM에 직접 설치)

- **웹 서버**: Nginx
  - **포트**: 80 (HTTP), 443 (HTTPS)
  - **리버스 프록시**: localhost:3000 (Node.js 서버)
  - **설정 파일**: `/etc/nginx/conf.d/yeop3.com.conf`

- **도메인**: yeop3.com
  - **DNS**: Cloudflare
  - **SSL/TLS**: Flexible 모드 (임시 자체 서명 인증서)
  - **프록시**: Cloudflare 프록시 활성화

- **서버 디렉토리**: `/opt/yeope/server`
- **데이터베이스**: PostgreSQL `yeope` 데이터베이스, `yeope_schema` 스키마

### 접속 정보

- **API 엔드포인트**: https://yeop3.com/api
- **Health Check**: https://yeop3.com/health
- **WebSocket**: wss://yeop3.com/socket.io

### 테스트 결과 ✅

- ✅ REST API 테스트 완료 (회원가입, 로그인, 방 생성, 메시지 전송/조회)
- ✅ WebSocket 테스트 완료 (연결, 방 참여, 메시지 전송/수신)
- ✅ TTL 자동 정리 시스템 정상 동작
- ✅ 외부 접속 테스트 완료

---

---

## 13. 참고 자료

- **BLE 스펙**: Bluetooth SIG Core Specification
- **Socket.io**: https://socket.io/docs/
- **PostgreSQL**: https://www.postgresql.org/docs/
- **PostgreSQL JSONB**: https://www.postgresql.org/docs/current/datatype-json.html
- **OCI Object Storage**: https://docs.oracle.com/en-us/iaas/Content/Object/Concepts/objectstorageoverview.htm
- **OCI 무료 티어**: https://www.oracle.com/cloud/free/
- **Let's Encrypt**: https://letsencrypt.org/

---

**작성 완료일**: 2024  
**최종 업데이트**: 2024년 11월 21일 (MVP Phase 1-6 완료, 프로덕션 배포 완료)

