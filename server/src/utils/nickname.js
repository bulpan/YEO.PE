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
  return nickname;
};

module.exports = {
  maskNickname
};





