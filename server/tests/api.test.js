/**
 * API 통합 테스트
 * 
 * 실행 방법:
 * 1. 서버 실행: npm run dev
 * 2. 다른 터미널에서: npm test
 */

const request = require('supertest');
const { app } = require('../src/index');

describe('YEO.PE API 테스트', () => {
  let authToken;
  let userId;
  let roomId;
  
  describe('인증 API', () => {
    test('POST /api/auth/register - 회원가입', async () => {
      const response = await request(app)
        .post('/api/auth/register')
        .send({
          email: 'test@example.com',
          password: 'testpassword123',
          nickname: '테스트유저'
        });
      
      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('token');
      expect(response.body).toHaveProperty('user');
      expect(response.body.user.nicknameMask).toBe('테**');
      
      authToken = response.body.token;
      userId = response.body.user.id;
    });
    
    test('POST /api/auth/login - 로그인', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          password: 'testpassword123'
        });
      
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('token');
      authToken = response.body.token;
    });
    
    test('GET /api/auth/me - 현재 사용자 정보', async () => {
      const response = await request(app)
        .get('/api/auth/me')
        .set('Authorization', `Bearer ${authToken}`);
      
      expect(response.status).toBe(200);
      expect(response.body.user).toHaveProperty('email');
    });
  });
  
  describe('방 API', () => {
    test('POST /api/rooms - 방 생성', async () => {
      const response = await request(app)
        .post('/api/rooms')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          name: '테스트 방',
          category: 'general'
        });
      
      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('roomId');
      roomId = response.body.roomId;
    });
    
    test('GET /api/rooms/nearby - 근처 방 목록', async () => {
      const response = await request(app)
        .get('/api/rooms/nearby');
      
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('rooms');
      expect(Array.isArray(response.body.rooms)).toBe(true);
    });
    
    test('GET /api/rooms/:roomId - 방 상세 정보', async () => {
      const response = await request(app)
        .get(`/api/rooms/${roomId}`);
      
      expect(response.status).toBe(200);
      expect(response.body.roomId).toBe(roomId);
    });
    
    test('POST /api/rooms/:roomId/join - 방 참여', async () => {
      const response = await request(app)
        .post(`/api/rooms/${roomId}/join`)
        .set('Authorization', `Bearer ${authToken}`);
      
      expect(response.status).toBe(200);
    });
  });
  
  describe('메시지 API', () => {
    test('POST /api/rooms/:roomId/messages - 메시지 전송', async () => {
      const response = await request(app)
        .post(`/api/rooms/${roomId}/messages`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          type: 'text',
          content: '테스트 메시지'
        });
      
      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('messageId');
    });
    
    test('GET /api/rooms/:roomId/messages - 메시지 목록', async () => {
      const response = await request(app)
        .get(`/api/rooms/${roomId}/messages`);
      
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('messages');
      expect(Array.isArray(response.body.messages)).toBe(true);
    });
  });
});





