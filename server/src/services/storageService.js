/**
 * 저장소 서비스
 * 파일 저장 및 관리를 담당 (현재는 로컬 스토리지 사용)
 */

const fs = require('fs');
const path = require('path');
const logger = require('../utils/logger');

// 업로드 디렉토리 설정
const UPLOAD_DIR = path.join(__dirname, '../../public/uploads');

// 디렉토리가 없으면 생성
if (!fs.existsSync(UPLOAD_DIR)) {
    fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

/**
 * 파일 저장
 * @param {Buffer} buffer - 파일 버퍼
 * @param {string} filename - 파일명
 * @param {string} folder - 하위 폴더 (예: 'images', 'profiles')
 * @returns {Promise<string>} - 저장된 파일의 공개 URL
 */
const saveFile = async (buffer, filename, folder = '') => {
    try {
        const targetDir = folder ? path.join(UPLOAD_DIR, folder) : UPLOAD_DIR;

        // 하위 디렉토리가 없으면 생성
        if (!fs.existsSync(targetDir)) {
            fs.mkdirSync(targetDir, { recursive: true });
        }

        const filePath = path.join(targetDir, filename);

        // 파일 쓰기
        await fs.promises.writeFile(filePath, buffer);

        // URL 생성 (프로덕션 환경에서는 도메인 포함 필요)
        // 현재는 상대 경로 반환
        const publicPath = folder ? `/uploads/${folder}/${filename}` : `/uploads/${filename}`;

        logger.info(`파일 저장 완료: ${filePath}`);

        return publicPath;
    } catch (error) {
        logger.error('파일 저장 실패:', error);
        throw error;
    }
};

/**
 * 파일 삭제
 * @param {string} filename - 파일명
 * @param {string} folder - 하위 폴더
 */
const deleteFile = async (filename, folder = '') => {
    try {
        const targetDir = folder ? path.join(UPLOAD_DIR, folder) : UPLOAD_DIR;
        const filePath = path.join(targetDir, filename);

        if (fs.existsSync(filePath)) {
            await fs.promises.unlink(filePath);
            logger.info(`파일 삭제 완료: ${filePath}`);
            return true;
        }
        return false;
    } catch (error) {
        logger.error('파일 삭제 실패:', error);
        throw error;
    }
};

module.exports = {
    saveFile,
    deleteFile
};
