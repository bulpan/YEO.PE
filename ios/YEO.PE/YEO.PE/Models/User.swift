import Foundation

struct User: Codable, Identifiable, Equatable {
    let id: String
    let email: String?
    let nickname: String?
    let nicknameMask: String?
    let nickname_mask: String? // Support for snake_case response
    
    enum CodingKeys: String, CodingKey {
        case id, userId // Map both id and userId to id property logic manually in init
        case email, nickname
        case nicknameMask = "nicknameMask" // Keep camel for internal/legacy if needed
        case nickname_mask // Matches server snake_case
        case settings
        case createdAt = "created_at"
        case lastLoginAt = "last_login_at"
        case distance, hasActiveRoom
        case roomId, roomName, uid
        case profileImageUrl // CamelCase (Server Standard)
        case profile_image_url // SnakeCase (DB/Legacy)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Try 'id' first, then 'userId'
        if let idVal = try? container.decode(String.self, forKey: .id) {
            id = idVal
        } else {
            id = try container.decode(String.self, forKey: .userId)
        }
        
        email = try container.decodeIfPresent(String.self, forKey: .email)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        nicknameMask = try container.decodeIfPresent(String.self, forKey: .nicknameMask)
        nickname_mask = try container.decodeIfPresent(String.self, forKey: .nickname_mask)
        settings = try container.decodeIfPresent(UserSettings.self, forKey: .settings)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        lastLoginAt = try container.decodeIfPresent(String.self, forKey: .lastLoginAt)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        hasActiveRoom = try container.decodeIfPresent(Bool.self, forKey: .hasActiveRoom)
        roomId = try container.decodeIfPresent(String.self, forKey: .roomId)
        roomName = try container.decodeIfPresent(String.self, forKey: .roomName)
        uid = try container.decodeIfPresent(String.self, forKey: .uid)
        profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl) 
                          ?? container.decodeIfPresent(String.self, forKey: .profile_image_url)
    }
    
    // Encodable conformance
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(nickname, forKey: .nickname)
        try container.encodeIfPresent(nicknameMask, forKey: .nicknameMask)
        try container.encodeIfPresent(nickname_mask, forKey: .nickname_mask)
        try container.encodeIfPresent(settings, forKey: .settings)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(lastLoginAt, forKey: .lastLoginAt)
        try container.encodeIfPresent(distance, forKey: .distance)
        try container.encodeIfPresent(hasActiveRoom, forKey: .hasActiveRoom)
        try container.encodeIfPresent(roomId, forKey: .roomId)
        try container.encodeIfPresent(roomName, forKey: .roomName)
        try container.encodeIfPresent(uid, forKey: .uid)
        try container.encodeIfPresent(profileImageUrl, forKey: .profileImageUrl)
    }
    
    // Explicit init for memberwise creation (lost when adding custom init)
    init(id: String, email: String? = nil, nickname: String? = nil, nicknameMask: String? = nil, nickname_mask: String? = nil, settings: UserSettings? = nil, createdAt: String? = nil, lastLoginAt: String? = nil, distance: Double? = nil, hasActiveRoom: Bool? = nil, roomId: String? = nil, roomName: String? = nil, uid: String? = nil, profileImageUrl: String? = nil) {
        self.id = id
        self.email = email
        self.nickname = nickname
        self.nicknameMask = nicknameMask
        self.nickname_mask = nickname_mask
        self.settings = settings
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
        self.distance = distance
        self.hasActiveRoom = hasActiveRoom
        self.roomId = roomId
        self.roomName = roomName
        self.uid = uid
        self.profileImageUrl = profileImageUrl
    }
    
    var resolvedMask: String? {
        return nicknameMask ?? nickname_mask
    }

    // Guest Logic: No nickname means Guest
    var isGuest: Bool {
        return (nickname == nil || nickname == "") && (nicknameMask == nil && nickname_mask == nil)
    }
    
    // Primary Display Name (Public Identity)
    var displayName: String {
        if isGuest { return "Guest" }
        return resolvedMask ?? nickname ?? "Unknown"
    }

    let settings: UserSettings?
    let createdAt: String?
    let lastLoginAt: String?
    
    // For BLE discovery
    var distance: Double?
    var hasActiveRoom: Bool?
    var roomId: String?
    var roomName: String?
    var uid: String? // BLE Short UID
    var profileImageUrl: String? // URL string
    
    var fullProfileFileURL: URL? {
        guard let path = profileImageUrl else { return nil }
        if path.hasPrefix("http") {
            return URL(string: path)
        }
        // Use socketURL (Root Domain) to leverage Nginx static file serving
        // Fix: AsyncImage requires http/https, but socketURL might be ws/wss in local dev
        var base = AppConfig.socketURL
        if base.hasPrefix("ws://") { base = base.replacingOccurrences(of: "ws://", with: "http://") }
        else if base.hasPrefix("wss://") { base = base.replacingOccurrences(of: "wss://", with: "https://") }
        
        return URL(string: "\(base)\(path)")
    }
    
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id &&
               lhs.nickname == rhs.nickname &&
               lhs.nicknameMask == rhs.nicknameMask &&
               lhs.nickname_mask == rhs.nickname_mask &&
               lhs.distance == rhs.distance &&
               lhs.hasActiveRoom == rhs.hasActiveRoom &&
               lhs.profileImageUrl == rhs.profileImageUrl
    }
}

struct UserSettings: Codable, Equatable {
    var bleVisible: Bool
    var pushEnabled: Bool
    var messageRetention: Int? // 6, 12, 24 (hours)
    var roomExitCondition: String? // "24h", "off", "activity"
    var maskId: Bool? // Mask ID on/off
}

struct AuthResponse: Codable {
    let token: String
    let refreshToken: String
    let user: User
}
