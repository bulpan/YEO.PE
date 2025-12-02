import Foundation

class TokenManager {
    static let shared = TokenManager()
    
    private let accessTokenKey = "accessToken"
    private let refreshTokenKey = "refreshToken"
    
    // In-memory storage for non-persistent sessions
    private var memoryAccessToken: String?
    private var memoryRefreshToken: String?
    
    // In a real app, use Keychain. For MVP, UserDefaults is acceptable but not secure.
    // TODO: Migrate to Keychain
    
    var accessToken: String? {
        get {
            return memoryAccessToken ?? UserDefaults.standard.string(forKey: accessTokenKey)
        }
        set {
            // Direct assignment only updates memory if not persisting, 
            // but for simplicity in this property, we might need to know the context.
            // Better to use save() method, but for compatibility:
            if let value = newValue {
                // If we have it in UserDefaults, update it there too
                if UserDefaults.standard.string(forKey: accessTokenKey) != nil {
                    UserDefaults.standard.set(value, forKey: accessTokenKey)
                }
                memoryAccessToken = value
            } else {
                UserDefaults.standard.removeObject(forKey: accessTokenKey)
                memoryAccessToken = nil
            }
        }
    }
    
    var refreshToken: String? {
        get {
            return memoryRefreshToken ?? UserDefaults.standard.string(forKey: refreshTokenKey)
        }
        set {
            if let value = newValue {
                if UserDefaults.standard.string(forKey: refreshTokenKey) != nil {
                    UserDefaults.standard.set(value, forKey: refreshTokenKey)
                }
                memoryRefreshToken = value
            } else {
                UserDefaults.standard.removeObject(forKey: refreshTokenKey)
                memoryRefreshToken = nil
            }
        }
    }
    
    func save(accessToken: String, refreshToken: String, keepLoggedIn: Bool) {
        self.memoryAccessToken = accessToken
        self.memoryRefreshToken = refreshToken
        
        if keepLoggedIn {
            UserDefaults.standard.set(accessToken, forKey: accessTokenKey)
            UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
        } else {
            UserDefaults.standard.removeObject(forKey: accessTokenKey)
            UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        }
    }
    
    func clearTokens() {
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        memoryAccessToken = nil
        memoryRefreshToken = nil
    }
    
    var isLoggedIn: Bool {
        return accessToken != nil
    }
    
    var userId: String? {
        guard let token = accessToken else { return nil }
        let parts = token.components(separatedBy: ".")
        guard parts.count > 1 else { return nil }
        
        // JWT payload is the second part
        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Pad with = if needed
        let length = Double(base64.lengthOfBytes(using: String.Encoding.utf8))
        let requiredLength = 4 * ceil(length / 4.0)
        let paddingLength = requiredLength - length
        if paddingLength > 0 {
            let padding = "".padding(toLength: Int(paddingLength), withPad: "=", startingAt: 0)
            base64 = base64 + padding
        }
        
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let payload = json as? [String: Any],
              let userId = payload["userId"] as? String else {
            return nil
        }
        
        return userId
    }
}
