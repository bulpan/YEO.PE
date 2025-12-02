# 수동 테스트 가이드

## 1. 서버 실행

```bash
cd server
npm run dev
```

서버가 `http://localhost:3000`에서 실행됩니다.

## 2. API 테스트 (curl 또는 Postman)

### 2.1 회원가입

```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "testpassword123",
    "nickname": "테스트유저"
  }'
```

**예상 응답:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "...",
  "user": {
    "id": "uuid",
    "email": "test@example.com",
    "nickname": "테스트유저",
    "nicknameMask": "테**"
  }
}
```

### 2.2 로그인

```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "testpassword123"
  }'
```

### 2.3 방 생성

```bash
curl -X POST http://localhost:3000/api/rooms \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "name": "테스트 방",
    "category": "general"
  }'
```

**예상 응답:**
```json
{
  "roomId": "uuid",
  "name": "테스트 방",
  "createdAt": "2024-01-01T00:00:00Z",
  "expiresAt": "2024-01-02T00:00:00Z",
  "memberCount": 1
}
```

### 2.4 근처 방 목록 조회

```bash
curl http://localhost:3000/api/rooms/nearby
```

### 2.5 방 참여

```bash
curl -X POST http://localhost:3000/api/rooms/ROOM_ID/join \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 2.6 메시지 전송

```bash
curl -X POST http://localhost:3000/api/rooms/ROOM_ID/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "type": "text",
    "content": "안녕하세요!"
  }'
```

### 2.7 메시지 목록 조회

```bash
curl http://localhost:3000/api/rooms/ROOM_ID/messages
```

## 3. WebSocket 테스트 (브라우저 콘솔)

### 3.1 Socket.io 클라이언트 연결

브라우저 개발자 도구 콘솔에서:

```javascript
// Socket.io 클라이언트 라이브러리 로드
const script = document.createElement('script');
script.src = 'https://cdn.socket.io/4.7.2/socket.io.min.js';
document.head.appendChild(script);

// 연결
const socket = io('http://localhost:3000', {
  auth: {
    token: 'YOUR_JWT_TOKEN'
  }
});

socket.on('connect', () => {
  console.log('✅ 연결 성공:', socket.id);
});

socket.on('disconnect', () => {
  console.log('❌ 연결 해제');
});

socket.on('error', (error) => {
  console.error('에러:', error);
});
```

### 3.2 방 참여

```javascript
socket.emit('join-room', { roomId: 'ROOM_ID' });

socket.on('room-joined', (data) => {
  console.log('방 참여:', data);
});

socket.on('user-joined', (data) => {
  console.log('사용자 참여:', data);
});
```

### 3.3 메시지 전송

```javascript
socket.emit('send-message', {
  roomId: 'ROOM_ID',
  type: 'text',
  content: '안녕하세요!'
});

socket.on('new-message', (data) => {
  console.log('새 메시지:', data);
});
```

### 3.4 타이핑 인디케이터

```javascript
socket.emit('typing', {
  roomId: 'ROOM_ID',
  isTyping: true
});

socket.on('typing-indicator', (data) => {
  console.log('타이핑 중:', data);
});
```

## 4. 전체 플로우 테스트

1. **회원가입** → 토큰 받기
2. **방 생성** → roomId 받기
3. **WebSocket 연결** → 토큰으로 인증
4. **방 참여** (WebSocket)
5. **메시지 전송** (WebSocket)
6. **메시지 목록 조회** (REST API)
7. **방 나가기** (WebSocket)

## 5. 에러 케이스 테스트

- 잘못된 토큰으로 API 호출
- 만료된 토큰으로 API 호출
- 존재하지 않는 방에 참여
- 참여하지 않은 방에 메시지 전송
- Rate Limiting 테스트 (과도한 요청)





