import Foundation

struct Room: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let roomId: String
    let name: String
    let memberCount: Int?
    let isActive: Bool?
    var unreadCount: Int?
    let lastMessage: String?
    let createdAt: String?
    
    // Dynamic Naming Fields
    let creatorId: String?
    let creatorNickname: String?
    let creatorNicknameMask: String?
    let creatorProfileImageUrl: String?
    let inviteeNickname: String?
    let inviteeNicknameMask: String?
    let inviteeProfileImageUrl: String?
    let metadata: RoomMetadata?
    
    enum CodingKeys: String, CodingKey {
        case id, roomId, name, memberCount, isActive, unreadCount, lastMessage, createdAt
        case creatorId, creatorNickname, creatorNicknameMask, creatorProfileImageUrl, inviteeNickname, inviteeNicknameMask, inviteeProfileImageUrl, metadata
    }
    
    // Helper to use either id or roomId
    var uniqueId: String {
        return roomId
    }
    
    // Dynamic Display Name
    var displayName: String {
        guard let currentUserId = TokenManager.shared.userId else { return name }
        
        // Check if it's a 1:1 room (has inviteeId)
        if let metadata = metadata, let inviteeId = metadata.inviteeId {
            if currentUserId == creatorId {
                // I am the creator, show invitee's name
                return inviteeNicknameMask ?? inviteeNickname ?? "Unknown User"
            } else if currentUserId == inviteeId {
                // I am the invitee, show creator's name
                return creatorNicknameMask ?? creatorNickname ?? "Unknown User"
            }
        }
        
        return name
    }
    
    // Dynamic Profile Image URL
    var displayProfileImageUrl: String? {
        guard let currentUserId = TokenManager.shared.userId else { return nil }
        
        // Check if it's a 1:1 room (has inviteeId)
        if let metadata = metadata, let inviteeId = metadata.inviteeId {
            if currentUserId == creatorId {
                // I am the creator, show invitee's image
                return inviteeProfileImageUrl
            } else if currentUserId == inviteeId {
                // I am the invitee, show creator's image
                return creatorProfileImageUrl
            }
        }
        
        // Default: If I am NOT the creator, show creator's image (for normal rooms)
        // If I AM the creator, show... placeholder? or invitee? (but normal rooms might have many members)
        if currentUserId != creatorId {
            return creatorProfileImageUrl
        }
        
        return nil 
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Robust Decoding: Handle both "id" and "roomId" from server
        // POST /rooms returns "roomId" but not "id". GET /rooms returns both (if using r.*) or specific aliases.
        // We ensure both properties are populated.
        let decodedId = try container.decodeIfPresent(String.self, forKey: .id)
        let decodedRoomId = try container.decodeIfPresent(String.self, forKey: .roomId)
        
        if let dId = decodedId {
            self.id = dId
            self.roomId = decodedRoomId ?? dId // Fallback to id if roomId missing
        } else if let dRId = decodedRoomId {
            self.id = dRId // Use roomId as id
            self.roomId = dRId
        } else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Both id and roomId are missing")
        }
        
        name = try container.decode(String.self, forKey: .name)
        
        memberCount = try container.decodeIfPresent(Int.self, forKey: .memberCount)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
        unreadCount = try container.decodeIfPresent(Int.self, forKey: .unreadCount)
        lastMessage = try container.decodeIfPresent(String.self, forKey: .lastMessage)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        
        creatorId = try container.decodeIfPresent(String.self, forKey: .creatorId)
        creatorNickname = try container.decodeIfPresent(String.self, forKey: .creatorNickname)
        creatorNicknameMask = try container.decodeIfPresent(String.self, forKey: .creatorNicknameMask)
        creatorProfileImageUrl = try container.decodeIfPresent(String.self, forKey: .creatorProfileImageUrl)
        inviteeNickname = try container.decodeIfPresent(String.self, forKey: .inviteeNickname)
        inviteeNicknameMask = try container.decodeIfPresent(String.self, forKey: .inviteeNicknameMask)
        inviteeProfileImageUrl = try container.decodeIfPresent(String.self, forKey: .inviteeProfileImageUrl)
        metadata = try container.decodeIfPresent(RoomMetadata.self, forKey: .metadata)
        
        // Defaults for server-fetched messages
        // localStatus is not in CodingKeys, so we don't decode it.
        // But since it's a property on the struct, we don't need to do anything if it has a default value in declaration.
        // Wait, 'let' properties must be init. 'var' with default is fine.
        // Check `struct Message` definition above. I changed it to `var localStatus`.
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(roomId, forKey: .roomId)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(memberCount, forKey: .memberCount)
        try container.encodeIfPresent(isActive, forKey: .isActive)
        try container.encodeIfPresent(unreadCount, forKey: .unreadCount)
        try container.encodeIfPresent(lastMessage, forKey: .lastMessage)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        
        try container.encodeIfPresent(creatorId, forKey: .creatorId)
        try container.encodeIfPresent(creatorNickname, forKey: .creatorNickname)
        try container.encodeIfPresent(creatorNicknameMask, forKey: .creatorNicknameMask)
        try container.encodeIfPresent(creatorProfileImageUrl, forKey: .creatorProfileImageUrl)
        try container.encodeIfPresent(inviteeNickname, forKey: .inviteeNickname)
        try container.encodeIfPresent(inviteeNicknameMask, forKey: .inviteeNicknameMask)
        try container.encodeIfPresent(inviteeProfileImageUrl, forKey: .inviteeProfileImageUrl)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
}

struct RoomMetadata: Codable, Hashable, Equatable {
    let category: String?
    let inviteeId: String?
}


struct RoomListResponse: Codable {
    let rooms: [Room]
}

struct Message: Codable, Identifiable {
    let messageId: String
    let roomId: String?
    let userId: String
    let nickname: String?
    let nicknameMask: String?
    let type: String // text, image
    let content: String?
    let imageUrl: String?
    let createdAt: String
    
    var id: String { messageId }
    
    // Local State
    var localStatus: MessageStatus? = .sent
    
    enum MessageStatus: String, Codable {
        case sending
        case sent
        case failed
    }
}

struct MessageListResponse: Codable {
    let messages: [Message]
    let hasMore: Bool?
}
