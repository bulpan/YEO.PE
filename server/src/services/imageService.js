/**
 * 이미지 처리 서비스
 * sharp 라이브러리를 사용하여 이미지 리사이징 및 최적화
 */

const sharp = require('sharp');
const logger = require('../utils/logger');

/**
 * 이미지 처리 (리사이징 및 WebP 변환)
 * @param {Buffer} fileBuffer - 원본 이미지 버퍼
 * @returns {Promise<object>} - 처리된 이미지 버퍼들 (원본용, 썸네일용)
 */
const processImage = async (fileBuffer) => {
    try {
        // 메타데이터 확인
        const metadata = await sharp(fileBuffer).metadata();

        logger.debug('이미지 처리 시작', {
            format: metadata.format,
            width: metadata.width,
            height: metadata.height
        });

        // 1. 원본용 (최대 1920px, WebP, 품질 80%)
        const originalBuffer = await sharp(fileBuffer)
            .resize({
                width: 1920,
                height: 1920,
                fit: 'inside', // 비율 유지하며 내부에 맞춤
                withoutEnlargement: true // 작은 이미지는 확대하지 않음
            })
            .webp({ quality: 80 })
            .toBuffer();

        // 2. 썸네일용 (최대 300px, WebP, 품질 70%)
        const thumbnailBuffer = await sharp(fileBuffer)
            .resize({
                width: 300,
                height: 300,
                fit: 'inside',
                withoutEnlargement: true
            })
            .webp({ quality: 70 })
            .toBuffer();

        return {
            original: originalBuffer,
            thumbnail: thumbnailBuffer,
            format: 'webp',
            originalSize: originalBuffer.length,
            thumbnailSize: thumbnailBuffer.length
        };
    } catch (error) {
        logger.error('이미지 처리 실패:', error);
        throw error;
    }
};

module.exports = {
    processImage
};
