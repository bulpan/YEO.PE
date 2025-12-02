/**
 * 테스트 헬퍼 함수
 */

const request = require('supertest');
const { app } = require('../src/index');

/**
 * 테스트용 사용자 생성 및 토큰 받기
 */
const createTestUser = async (email = `test${Date.now()}@example.com`, nickname = '테스트유저') => {
  const response = await request(app)
    .post('/api/auth/register')
    .send({
      email,
      password: 'testpassword123',
      nickname
    });
  
  if (response.status !== 201) {
    throw new Error(`사용자 생성 실패: ${response.body.error?.message}`);
  }
  
  return {
    token: response.body.token,
    refreshToken: response.body.refreshToken,
    user: response.body.user
  };
};

/**
 * 테스트용 방 생성
 */
const createTestRoom = async (token, name = '테스트 방', category = 'general') => {
  const response = await request(app)
    .post('/api/rooms')
    .set('Authorization', `Bearer ${token}`)
    .send({ name, category });
  
  if (response.status !== 201) {
    throw new Error(`방 생성 실패: ${response.body.error?.message}`);
  }
  
  return response.body;
};

/**
 * 테스트용 메시지 전송
 */
const sendTestMessage = async (token, roomId, content = '테스트 메시지') => {
  const response = await request(app)
    .post(`/api/rooms/${roomId}/messages`)
    .set('Authorization', `Bearer ${token}`)
    .send({
      type: 'text',
      content
    });
  
  if (response.status !== 201) {
    throw new Error(`메시지 전송 실패: ${response.body.error?.message}`);
  }
  
  return response.body;
};

module.exports = {
  createTestUser,
  createTestRoom,
  sendTestMessage
};





