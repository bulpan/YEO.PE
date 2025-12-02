/**
 * 메시지 삭제 API 라우트
 */

const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const messageService = require('../services/messageService');

/**
 * DELETE /api/messages/:messageId
 * 메시지 삭제 (인증 필요, 본인만 가능)
 */
router.delete('/:messageId', authenticate, async (req, res, next) => {
  try {
    const { messageId } = req.params;
    const userId = req.user.userId;
    
    await messageService.deleteMessage(userId, messageId);
    
    res.json({ message: '메시지가 삭제되었습니다' });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
