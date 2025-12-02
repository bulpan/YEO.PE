/**
 * 입력 검증 미들웨어
 */

const { ValidationError } = require('../utils/errors');

/**
 * 이메일 형식 검증
 */
const validateEmail = (email) => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

/**
 * 비밀번호 강도 검증
 */
const validatePassword = (password) => {
  if (password.length < 8) {
    return { valid: false, message: '비밀번호는 8자 이상이어야 합니다' };
  }
  return { valid: true };
};

/**
 * 닉네임 검증
 */
const validateNickname = (nickname) => {
  if (!nickname || nickname.length < 2 || nickname.length > 20) {
    return { valid: false, message: '닉네임은 2자 이상 20자 이하여야 합니다' };
  }
  return { valid: true };
};

module.exports = {
  validateEmail,
  validatePassword,
  validateNickname
};





