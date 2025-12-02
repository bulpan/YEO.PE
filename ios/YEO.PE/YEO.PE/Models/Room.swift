import Foundation

struct Room: Codable, Identifiable {
    let id: String // This maps to "id" from JSON, but we might use "roomId"
    let roomId: String
    let name: String
    let memberCount: Int?
    let isActive: Bool?
    let createdAt: String?
    
    // Helper to use either id or roomId
    var uniqueId: String { roomId }
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
}

struct MessageListResponse: Codable {
    let messages: [Message]
    let hasMore: Bool?
}
