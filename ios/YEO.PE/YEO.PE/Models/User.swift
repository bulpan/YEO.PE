import Foundation

struct User: Codable, Identifiable {
    let id: String
    let email: String?
    let nickname: String?
    let nicknameMask: String?
    let settings: UserSettings?
    let createdAt: String?
    let lastLoginAt: String?
    
    // For BLE discovery
    var distance: Double?
    var hasActiveRoom: Bool?
    var roomId: String?
    var roomName: String?
}

struct UserSettings: Codable {
    var bleVisible: Bool
    var pushEnabled: Bool
}

struct AuthResponse: Codable {
    let token: String
    let refreshToken: String
    let user: User
}
