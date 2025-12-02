/**
 * WebSocket 테스트
 * 
 * 실행 방법:
 * 1. 서버 실행: npm run dev
 * 2. 다른 터미널에서: node tests/websocket.test.js
 */

const { io } = require('socket.io-client');

const SERVER_URL = process.env.TEST_SERVER_URL || 'http://localhost:3000';
const TEST_TOKEN = process.env.TEST_TOKEN || 'your_test_token_here';

describe('WebSocket 테스트', () => {
  let socket;
  
  beforeAll((done) => {
    socket = io(SERVER_URL, {
      auth: {
        token: TEST_TOKEN
      },
      transports: ['websocket']
    });
    
    socket.on('connect', () => {
      console.log('✅ WebSocket 연결 성공');
      done();
    });
    
    socket.on('connect_error', (error) => {
      console.error('❌ WebSocket 연결 실패:', error.message);
      done(error);
    });
  });
  
  afterAll(() => {
    if (socket) {
      socket.disconnect();
    }
  });
  
  test('join-room 이벤트', (done) => {
    const testRoomId = 'test-room-id';
    
    socket.emit('join-room', { roomId: testRoomId });
    
    socket.once('room-joined', (data) => {
      expect(data).toHaveProperty('roomId');
      expect(data).toHaveProperty('memberCount');
      console.log('✅ 방 참여 성공:', data);
      done();
    });
    
    setTimeout(() => {
      done(new Error('방 참여 응답 타임아웃'));
    }, 5000);
  });
  
  test('send-message 이벤트', (done) => {
    const testRoomId = 'test-room-id';
    const testMessage = {
      roomId: testRoomId,
      type: 'text',
      content: '테스트 메시지'
    };
    
    socket.emit('send-message', testMessage);
    
    socket.once('new-message', (data) => {
      expect(data).toHaveProperty('messageId');
      expect(data).toHaveProperty('content');
      expect(data.content).toBe(testMessage.content);
      console.log('✅ 메시지 전송 성공:', data);
      done();
    });
    
    setTimeout(() => {
      done(new Error('메시지 전송 응답 타임아웃'));
    }, 5000);
  });
});





