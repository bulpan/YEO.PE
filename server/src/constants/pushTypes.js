/**
 * 푸시 알림 타입 정의
 */
const PushType = {
    NEW_MESSAGE: 'NEW_MESSAGE',
    NEARBY_USER: 'NEARBY_USER',
    ROOM_INVITE: 'ROOM_INVITE',
    ROOM_CREATED: 'ROOM_CREATED',
    QUICK_QUESTION: 'QUICK_QUESTION'
};

/**
 * 푸시 알림 페이로드 생성 팩토리
 * @param {string} type - PushType 중 하나
 * @param {object} context - 알림 생성에 필요한 데이터
 * @returns {object} { notification, data }
 */
const createPushPayload = (type, context) => {
    const timestamp = String(Date.now());
    let notification = {};
    let data = {
        type: type,
        timestamp: timestamp
    };

    switch (type) {
        case PushType.NEW_MESSAGE:
            // context: { senderNicknameMask, messageContent, messageType, roomId, messageId }
            notification = {
                title: context.senderNicknameMask,
                body: context.messageType === 'text' ? context.messageContent : context.messageType === 'image' ? '📷 이미지' : '이모지'
            };
            data = {
                ...data,
                roomId: context.roomId,
                messageId: context.messageId || '',
                senderNicknameMask: context.senderNicknameMask,
                action: 'DEEP_LINK',
                targetScreen: 'CHAT_ROOM',
                targetId: context.roomId
            };
            break;

        case PushType.NEARBY_USER:
            // context: { userCount, userId }
            notification = {
                title: '주변에 사용자가 있습니다',
                body: `근처에 YEO.PE 사용자 ${context.userCount}명이 있습니다`
            };
            data = {
                ...data,
                userCount: String(context.userCount),
                action: 'DEEP_LINK',
                targetScreen: 'MAIN_MAP',
                targetId: context.userId // 포커스할 사용자 ID (옵션)
            };
            break;

        case PushType.ROOM_CREATED:
            // context: { roomName, roomId }
            notification = {
                title: '새로운 방이 생성되었습니다',
                body: context.roomName
            };
            data = {
                ...data,
                roomId: context.roomId,
                roomName: context.roomName,
                action: 'DEEP_LINK',
                targetScreen: 'CHAT_ROOM', // 방 생성 알림 누르면 해당 방으로 이동? 혹은 메인에서 방 보기?
                targetId: context.roomId
            };
            break;

        case PushType.ROOM_INVITE:
            // context: { inviterNicknameMask, roomName, roomId, inviterId }
            notification = {
                title: '방 초대',
                body: `${context.inviterNicknameMask}님이 ${context.roomName} 방에 초대했습니다`
            };
            data = {
                ...data,
                roomId: context.roomId,
                roomName: context.roomName,
                inviterId: context.inviterId,
                action: 'DEEP_LINK',
                targetScreen: 'CHAT_ROOM',
                targetId: context.roomId
            };
            break;

        case PushType.QUICK_QUESTION:
            // context: { content }
            notification = {
                title: '급질문',
                body: context.content
            };
            data = {
                ...data,
                content: context.content,
                action: 'DEEP_LINK',
                targetScreen: 'MAIN_MAP'
            };
            break;

        default:
            throw new Error(`Unknown PushType: ${type}`);
    }

    return { notification, data };
};

module.exports = {
    PushType,
    createPushPayload
};
