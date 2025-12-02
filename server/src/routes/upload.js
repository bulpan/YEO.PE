/**
 * 파일 업로드 API 라우트
 */

const express = require('express');
const router = express.Router();
const multer = require('multer');
const crypto = require('crypto');
const { authenticate } = require('../middleware/auth');
const imageService = require('../services/imageService');
const storageService = require('../services/storageService');
const { ValidationError } = require('../utils/errors');
const logger = require('../utils/logger');

// Multer 설정 (메모리에 임시 저장)
const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 5 * 1024 * 1024, // 5MB 제한
    },
    fileFilter: (req, file, cb) => {
        // 이미지 파일만 허용
        if (file.mimetype.startsWith('image/')) {
            cb(null, true);
        } else {
            cb(new ValidationError('이미지 파일만 업로드 가능합니다'), false);
        }
    }
});

/**
 * POST /api/upload/image
 * 이미지 업로드
 */
router.post('/image', authenticate, upload.single('image'), async (req, res, next) => {
    try {
        if (!req.file) {
            throw new ValidationError('이미지 파일을 선택해주세요');
        }

        const userId = req.user.userId;
        const { roomId } = req.body;

        // 파일명 생성 (UUID)
        const fileId = crypto.randomUUID();
        const folder = roomId ? `images/${roomId}` : `images/temp`;

        // 이미지 처리 (리사이징 및 변환)
        const processed = await imageService.processImage(req.file.buffer);

        // 파일 저장 (원본 및 썸네일)
        const originalFilename = `${fileId}.webp`;
        const thumbnailFilename = `${fileId}_thumb.webp`;

        const [imageUrl, thumbnailUrl] = await Promise.all([
            storageService.saveFile(processed.original, originalFilename, folder),
            storageService.saveFile(processed.thumbnail, thumbnailFilename, folder)
        ]);

        logger.info(`이미지 업로드 성공: ${fileId} by user ${userId}`);

        res.json({
            imageUrl,
            thumbnailUrl,
            messageId: fileId, // 메시지 ID로 사용 가능
            size: processed.originalSize,
            format: processed.format
        });
    } catch (error) {
        next(error);
    }
});

module.exports = router;
