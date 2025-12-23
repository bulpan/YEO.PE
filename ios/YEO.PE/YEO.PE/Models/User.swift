import Foundation

struct User: Codable, Identifiable, Equatable {
    let id: String
    let email: String?
    let nickname: String?
    let nicknameMask: String?
    let nickname_mask: String? // Support for snake_case response
    
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
        // apiBaseURL includes '/api', which routes through Node.js
        return URL(string: "\(AppConfig.socketURL)\(path)")
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
