import Foundation

struct User: Codable, Identifiable {
    let id: String
    let email: String?
    let nickname: String?
    let nicknameMask: String?
    let nickname_mask: String? // Support for snake_case response
    
    var resolvedMask: String? {
        return nicknameMask ?? nickname_mask
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
}

struct UserSettings: Codable {
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
