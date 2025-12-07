/**
 * 방(Room) API 라우트
 */

const express = require('express');
const router = express.Router();
const { authenticate, optionalAuthenticate } = require('../middleware/auth');
const { roomCreationLimiter, messageLimiter } = require('../middleware/rateLimit');
const roomService = require('../services/roomService');
const messageService = require('../services/messageService');
const pushService = require('../services/pushService');
const { ValidationError } = require('../utils/errors');
const logger = require('../utils/logger');

/**
 * POST /api/rooms
 * 새 방 생성 (인증 필요)
 */
router.post('/', authenticate, roomCreationLimiter, async (req, res, next) => {
  try {
    const { name, category = 'general', nearbyUserIds, inviteeId } = req.body;
    const userId = req.user.userId;

    // 입력 검증
    if (!name || name.trim().length === 0) {
      throw new ValidationError('방 이름을 입력해주세요');
    }

    if (name.length > 255) {
      throw new ValidationError('방 이름은 255자 이하여야 합니다');
    }

    const validCategories = ['general', 'transport', 'event', 'venue', 'private'];
    if (!validCategories.includes(category)) {
      throw new ValidationError('유효하지 않은 카테고리입니다');
    }

    // 중복 방지 로직
    if (!inviteeId) {
      // 일반 방: 이름 중복 확인
      const checkUserIds = [userId, ...(nearbyUserIds || [])];
      if (checkUserIds.length > 0) {
        const duplicateRoom = await roomService.checkDuplicateRoom(name.trim(), checkUserIds);
        if (duplicateRoom) {
          throw new ValidationError('근처에 이미 같은 이름의 방이 있습니다. 해당 방에 참여해보세요!');
        }
      }
    } else {
      // 1:1 방: 이미 존재하는 방인지 확인
      // check if I already have a room with this invitee
      const myRooms = await roomService.getUserRooms(userId);
      const existingRoom = myRooms.find(r => {
        // Check metadata inviteeId and if it matches
        // Also check if I am the creator or the invitee
        // Logic: Return existing active room if found
        if (!r.metadata || !r.metadata.inviteeId) return false;

        // Case 1: I created the room for this invitee
        if (r.creatorId === userId && r.metadata.inviteeId === inviteeId) return true;

        // Case 2: I was invited to this room by the invitee (Bidirectional check)
        if (r.creatorId === inviteeId && r.metadata.inviteeId === userId) return true;

        return false;
      });

      if (existingRoom) {
        // 이미 존재하는 방이면 그 방 정보를 반환 (200 OK)
        return res.status(200).json({
          roomId: existingRoom.roomId,
          name: existingRoom.name,
          createdAt: existingRoom.createdAt,
          expiresAt: existingRoom.expiresAt,
          memberCount: existingRoom.memberCount,
          metadata: existingRoom.metadata,
          alreadyExists: true
        });
      }
    }

    // 방 생성
    const room = await roomService.createRoom(userId, name.trim(), category, inviteeId);

    logger.info(`방 생성: ${room.roomId} by user ${userId}`);

    // 주변 사용자에게 방 생성 알림 전송
    if (nearbyUserIds && Array.isArray(nearbyUserIds) && nearbyUserIds.length > 0) {
      // 1. Push Notification
      pushService.sendRoomCreatedNotification(
        room.roomId,
        room.name,
        userId,
        nearbyUserIds
      ).catch(err => {
        logger.error('방 생성 알림 전송 실패:', err);
      });

      // 2. Socket Event (Real-time update) - Global Broadcast (Receiver Filtered)
      // We emit to EVERYONE, and the client decides whether to show it based on their BLE radar.
      const io = req.app.get('io');
      if (io) {
        io.emit('room-created', {
          roomId: room.roomId,
          name: room.name,
          creatorId: userId,
          category: category,
          isActive: true,
          memberCount: 1,
          createdAt: room.createdAt,
          allowsMultiple: true
        });
      }
    }

    res.status(201).json({
      roomId: room.roomId,
      name: room.name,
      createdAt: room.createdAt,
      expiresAt: room.expiresAt,
      memberCount: room.memberCount,
      metadata: room.metadata
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/rooms/nearby
 * 근처 활성 방 목록 조회 (비회원도 접근 가능)
 */
router.get('/nearby', optionalAuthenticate, async (req, res, next) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const category = req.query.category;
    const before = req.query.before;

    if (limit > 50) {
      throw new ValidationError('limit은 50을 초과할 수 없습니다');
    }

    const rooms = await roomService.getActiveRooms({
      limit,
      category,
      before
    });

    res.json({ rooms });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/rooms/my
 * 내가 참여 중인 방 목록 조회 (인증 필요)
 */
router.get('/my', authenticate, async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const rooms = await roomService.getUserRooms(userId);

    res.json({ rooms });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/rooms/:roomId
 * 방 상세 정보 조회
 */
router.get('/:roomId', optionalAuthenticate, async (req, res, next) => {
  try {
    const { roomId } = req.params;
    const room = await roomService.getRoomDetails(roomId);

    res.json(room);
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/rooms/:roomId/join
 * 방 참여 (인증 필요)
 */
router.post('/:roomId/join', authenticate, async (req, res, next) => {
  try {
    const { roomId } = req.params;
    const userId = req.user.userId;

    const result = await roomService.joinRoom(userId, roomId);

    if (result.alreadyJoined) {
      return res.json({
        message: '이미 참여 중인 방입니다',
        roomId
      });
    }

    logger.info(`사용자 ${userId}가 방 ${roomId}에 참여`);

    // Socket Event Emission
    const io = req.app.get('io');
    if (io) {
      if (result.systemMessage) {
        io.to(`room:${roomId}`).emit('new-message', result.systemMessage);
      }

      // Emit member-joined to trigger client member refresh
      io.to(`room:${roomId}`).emit('member-joined', {
        roomId,
        userId,
        nickname: result.systemMessage.nickname || 'Unknown', // Helper to avoid another DB query if possible
        joinedAt: new Date()
      });
    }

    res.json({
      roomId,
      message: '방에 참여했습니다'
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/rooms/:roomId/leave
 * 방 나가기 (인증 필요)
 */
router.post('/:roomId/leave', authenticate, async (req, res, next) => {
  try {
    const { roomId } = req.params;
    const userId = req.user.userId;

    const result = await roomService.leaveRoom(userId, roomId);

    logger.info(`사용자 ${userId}가 방 ${roomId}에서 나감`);

    // Socket Event Emission
    const io = req.app.get('io');
    if (io) {
      // 1. Broadcast system message (User left/evaporated)
      if (result.systemMessage) {
        io.to(`room:${roomId}`).emit('new-message', result.systemMessage);
      }

      // 2. Broadcast evaporation event (Clients should remove messages from this user)
      if (result.leftUserId) {
        io.to(`room:${roomId}`).emit('evaporate_messages', {
          roomId: roomId,
          userId: result.leftUserId
        });

        // 3. Broadcast member-left event (Clients should update member list)
        io.to(`room:${roomId}`).emit('member-left', {
          roomId,
          userId: result.leftUserId,
          memberCount: result.systemMessage ? result.systemMessage.memberCount : 0 // memberCount pass if available, logic might need check
        });
      }
    }

    res.json({
      roomId,
      message: '방에서 나갔습니다'
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/rooms/:roomId/members
 * 방 멤버 목록 조회 (인증 필요)
 */
router.get('/:roomId/members', authenticate, async (req, res, next) => {
  try {
    const { roomId } = req.params;
    const members = await roomService.getRoomMembers(roomId);

    res.json({ members });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/rooms/:roomId/messages
 * 메시지 목록 조회 (비회원도 읽기 가능)
 */
router.get('/:roomId/messages', optionalAuthenticate, async (req, res, next) => {
  try {
    const { roomId } = req.params;
    const limit = parseInt(req.query.limit) || 50;
    const before = req.query.before;

    if (limit > 100) {
      throw new ValidationError('limit은 100을 초과할 수 없습니다');
    }

    const result = await messageService.getMessages(roomId, {
      limit,
      before
    });

    res.json(result);
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/rooms/:roomId/messages
 * 메시지 전송 (인증 필요)
 */
router.post('/:roomId/messages', authenticate, messageLimiter, async (req, res, next) => {
  try {
    const { roomId } = req.params;
    const userId = req.user.userId;
    const { type, content, imageUrl } = req.body;

    const message = await messageService.createMessage(
      userId,
      roomId,
      type,
      content,
      imageUrl
    );

    logger.info(`메시지 전송: ${message.messageId} in room ${roomId}`);

    res.status(201).json({
      messageId: message.messageId,
      createdAt: message.createdAt
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/rooms/:roomId/invite
 * 방 초대 (인증 필요)
 */
router.post('/:roomId/invite', authenticate, async (req, res, next) => {
  try {
    const { roomId } = req.params;
    const { userId: invitedUserId } = req.body;
    const inviterId = req.user.userId;

    if (!invitedUserId) {
      throw new ValidationError('초대할 사용자 ID가 필요합니다');
    }

    // 방 정보 조회
    const room = await roomService.findRoomByRoomId(roomId);
    if (!room) {
      throw new ValidationError('방을 찾을 수 없습니다');
    }

    // 초대자가 방 멤버인지 확인
    const members = await roomService.getRoomMembers(roomId);
    const isMember = members.some(m => m.userId === inviterId);
    if (!isMember) {
      throw new ValidationError('방 멤버만 초대할 수 있습니다');
    }

    // 초대자 닉네임 찾기
    const inviter = members.find(m => m.userId === inviterId);

    // 알림 전송
    pushService.sendRoomInviteNotification(
      invitedUserId,
      roomId,
      room.name,
      inviterId,
      inviter.nicknameMask
    ).catch(err => {
      logger.error('방 초대 알림 전송 실패:', err);
    });

    res.json({
      message: '초대를 보냈습니다'
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;

