/**
 * 닉네임 마스킹 유틸리티
 */

/**
 * 닉네임 마스킹 함수
 * 예: "김철수" → "김**"
 * 
 * @param {string} nickname - 원본 닉네임
 * @returns {string} - 마스킹된 닉네임
 */
const maskNickname = (nickname) => {
  if (!nickname || nickname.length === 0) {
    return '*';
  }
  
  if (nickname.length <= 2) {
    return nickname[0] + '*';
  }
  
  // 첫 글자 + 나머지는 모두 *
  return nickname[0] + '*'.repeat(nickname.length - 1);
};

module.exports = {
  maskNickname
};





