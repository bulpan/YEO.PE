const logger = require('./logger');

// Basic bad words list (Expand as needed)
const BAD_WORDS_KO = [
    // 욕설 및 비하
    '시발', '씨발', '쉬발', '슈발', 'ㅅㅂ', '시이발', '씨이발',
    '개새끼', '개세끼', '개새키', '개색기', '개년', '개놈', '미친년', '미친놈',
    '병신', '빙신', '뷩신', 'ㅄ', 'ㅂㅅ',
    '지랄', '존나', '졸라', '썅', '씨발년', '씨발놈',
    '좆', '씹', '창녀', '걸레', '보지', '자지', '잠지', '섹스', '야동', '콘돔',
    '니애미', '느금마', '니기미', '애미', '애비', '엠창', '엄창',
    '나가뒤져', '자살', '살자', '칼로', '죽여', '죽어',
    '강간', '따먹', '몰카', '성폭행', '성추행',
    '맘충', '한남', '김치녀', '짱깨', '쪽발이', '흑형'
];

const BAD_WORDS_EN = [
    'fuck', 'shit', 'bitch', 'asshole', 'whore', 'cunt', 'dick', 'pussy', 'nigger', 'faggot', 'kill yourself', 'suicide',
    'sex', 'porn', 'cock', 'tits', 'slut', 'bastard', 'motherfucker'
];

const ALL_BAD_WORDS = [...BAD_WORDS_KO, ...BAD_WORDS_EN];

/**
 * Check if text contains bad words locally
 * @param {string} text 
 * @returns {boolean} true if bad word found
 */
const hasBadWords = (text) => {
    if (!text) return false;
    const normalized = text.toLowerCase().replace(/\s/g, ''); // Remove spaces for check
    return ALL_BAD_WORDS.some(word => normalized.includes(word));
};

/**
 * Mask bad words in text
 * @param {string} text 
 * @returns {string} masked text
 */
const maskBadWords = (text) => {
    if (!text) return text;
    let masked = text;
    ALL_BAD_WORDS.forEach(word => {
        const regex = new RegExp(word, 'gi');
        masked = masked.replace(regex, '*'.repeat(word.length));
    });
    return masked;
};

/**
 * Check text using OpenAI API (Optional, requires API Key)
 * @param {string} text 
 * @returns {Promise<boolean>} true if flagged as inappropriate
 */
const checkWithAI = async (text) => {
    if (!process.env.OPENAI_API_KEY) return false;

    try {
        const response = await fetch('https://api.openai.com/v1/moderations', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`
            },
            body: JSON.stringify({ input: text })
        });

        const data = await response.json();
        if (data.results && data.results.length > 0) {
            return data.results[0].flagged;
        }
        return false;
    } catch (error) {
        logger.error('OpenAI Moderation Error:', error);
        return false; // Fail open to avoid blocking legitimate messages on error
    }
};

module.exports = {
    hasBadWords,
    maskBadWords,
    checkWithAI
};
