/**
 * WebSocket 클라이언트 테스트 스크립트
 * 
 * 사용법:
 * node tests/websocket-client.js <TOKEN> <ROOM_ID>
 */

const { io } = require('socket.io-client');

const SERVER_URL = process.env.SERVER_URL || 'http://152.67.208.177:3000';
const TOKEN = process.argv[2];
const ROOM_ID = process.argv[3];

if (!TOKEN) {
  console.error('❌ 사용법: node websocket-client.js <TOKEN> <ROOM_ID>');
  console.error('예: node websocket-client.js eyJhbGci... 6b996540-5656-4e89-a664-791f928b6e55');
  process.exit(1);
}

console.log('🔌 WebSocket 연결 시도...');
console.log(`서버: ${SERVER_URL}`);
console.log(`토큰: ${TOKEN.substring(0, 50)}...`);
if (ROOM_ID) {
  console.log(`방 ID: ${ROOM_ID}`);
}

const socket = io(SERVER_URL, {
  auth: {
    token: TOKEN
  },
  transports: ['websocket']
});

socket.on('connect', () => {
  console.log('✅ WebSocket 연결 성공!');
  console.log(`Socket ID: ${socket.id}`);
  
  if (ROOM_ID) {
    console.log(`\n📥 방 참여 중: ${ROOM_ID}`);
    socket.emit('join-room', { roomId: ROOM_ID });
  }
});

socket.on('disconnect', (reason) => {
  console.log(`❌ 연결 해제: ${reason}`);
});

socket.on('connect_error', (error) => {
  console.error('❌ 연결 오류:', error.message);
  process.exit(1);
});

socket.on('error', (error) => {
  console.error('❌ 에러:', error);
});

// 방 관련 이벤트
socket.on('room-joined', (data) => {
  console.log('✅ 방 참여 성공:', data);
});

socket.on('room-left', (data) => {
  console.log('👋 방 나감:', data);
});

socket.on('user-joined', (data) => {
  console.log(`👤 사용자 참여: ${data.nicknameMask} (멤버 수: ${data.memberCount})`);
});

socket.on('user-left', (data) => {
  console.log(`👋 사용자 나감 (멤버 수: ${data.memberCount})`);
});

// 메시지 이벤트
socket.on('new-message', (data) => {
  console.log(`\n💬 새 메시지 [${data.nicknameMask}]: ${data.content}`);
  console.log(`   메시지 ID: ${data.messageId}`);
  console.log(`   시간: ${new Date(data.createdAt).toLocaleString()}`);
});

// 타이핑 이벤트
socket.on('typing-indicator', (data) => {
  if (data.isTyping) {
    console.log(`⌨️  ${data.nicknameMask} 타이핑 중...`);
  }
});

// 명령어 입력 처리
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => {
  const input = chunk.trim();
  
  if (!input) return;
  
  if (input === '/exit' || input === '/quit') {
    console.log('연결 종료...');
    socket.disconnect();
    process.exit(0);
  } else if (input.startsWith('/join ')) {
    const roomId = input.substring(6);
    console.log(`방 참여: ${roomId}`);
    socket.emit('join-room', { roomId });
  } else if (input.startsWith('/leave')) {
    if (ROOM_ID) {
      console.log(`방 나가기: ${ROOM_ID}`);
      socket.emit('leave-room', { roomId: ROOM_ID });
    }
  } else if (input.startsWith('/msg ')) {
    if (!ROOM_ID) {
      console.log('❌ 먼저 방에 참여하세요: /join <ROOM_ID>');
      return;
    }
    const message = input.substring(5);
    socket.emit('send-message', {
      roomId: ROOM_ID,
      type: 'text',
      content: message
    });
    console.log(`📤 메시지 전송: ${message}`);
  } else if (input.startsWith('/typing')) {
    if (!ROOM_ID) {
      console.log('❌ 먼저 방에 참여하세요');
      return;
    }
    socket.emit('typing', { roomId: ROOM_ID, isTyping: true });
    setTimeout(() => {
      socket.emit('typing', { roomId: ROOM_ID, isTyping: false });
    }, 3000);
  } else {
    // 기본적으로 메시지로 처리
    if (ROOM_ID) {
      socket.emit('send-message', {
        roomId: ROOM_ID,
        type: 'text',
        content: input
      });
      console.log(`📤 메시지 전송: ${input}`);
    } else {
      console.log('❌ 먼저 방에 참여하세요: /join <ROOM_ID>');
    }
  }
});

console.log('\n📝 명령어:');
console.log('  /join <ROOM_ID>  - 방 참여');
console.log('  /leave           - 방 나가기');
console.log('  /msg <메시지>    - 메시지 전송');
console.log('  /typing          - 타이핑 인디케이터 테스트');
console.log('  /exit            - 종료');
console.log('  또는 그냥 입력하면 메시지로 전송\n');





