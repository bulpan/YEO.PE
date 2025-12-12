import Foundation
import Combine

class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var nickname = ""
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var keepLoggedIn = true // Default to true for better background experience
    @Published var currentUser: User?
    @Published var blockedUserIds: Set<String> = []
    
    var userId: String? {
        return currentUser?.id
    }
    
    init() {
        self.isLoggedIn = TokenManager.shared.isLoggedIn
        if self.isLoggedIn {
            fetchProfile()
            fetchBlockedUsers()
        }
    }
    
    func login() {
        isLoading = true
        errorMessage = nil
        
        let body = ["email": email, "password": password]
        
        APIService.shared.request("/auth/login", method: "POST", body: body) { (result: Result<AuthResponse, Error>) in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let response):
                    TokenManager.shared.save(accessToken: response.token, refreshToken: response.refreshToken, keepLoggedIn: self.keepLoggedIn)
                    self.isLoggedIn = true
                    self.currentUser = response.user
                    self.fetchBlockedUsers()
                    APIService.shared.registerFCMToken(token: nil) // Register cached token
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func register() {
        print("🔵 AuthViewModel.register() called")
        isLoading = true
        errorMessage = nil
        
        let body = ["email": email, "password": password, "nickname": nickname]
        
        APIService.shared.request("/auth/register", method: "POST", body: body) { (result: Result<AuthResponse, Error>) in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let response):
                    TokenManager.shared.save(accessToken: response.token, refreshToken: response.refreshToken, keepLoggedIn: self.keepLoggedIn)
                    self.isLoggedIn = true
                    self.currentUser = response.user
                    APIService.shared.registerFCMToken(token: nil) // Register cached token
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func socialLogin(provider: String, token: String) {
        isLoading = true
        errorMessage = nil
        
        let body = ["token": token]
        
        APIService.shared.request("/auth/social/\(provider.lowercased())", method: "POST", body: body) { (result: Result<AuthResponse, Error>) in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let response):
                    TokenManager.shared.save(accessToken: response.token, refreshToken: response.refreshToken, keepLoggedIn: self.keepLoggedIn)
                    self.isLoggedIn = true
                    self.currentUser = response.user
                    APIService.shared.registerFCMToken(token: nil) // Register cached token
                    
                    // Check for random nickname
                    if let nick = response.user.nickname {
                         if nick.hasPrefix("User_") || nick.hasPrefix("KakaoUser") || nick.hasPrefix("NaverUser") {
                             self.showRandomNicknameToast = true
                         }
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func fetchProfile() {
        APIService.shared.request("/users/me", method: "GET") { [weak self] (result: Result<UserResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.currentUser = response.user
                    print("✅ Profile fetched: \(response.user.nickname ?? "Unknown")")
                case .failure(let error):
                    print("⚠️ Failed to fetch profile: \(error)")
                }
            }
        }
    }
    
    func logout() {
        TokenManager.shared.clearTokens()
        isLoggedIn = false
        currentUser = nil
        blockedUserIds.removeAll()
        BLEManager.shared.blockedUserIds.removeAll()
    }
    
    // Check for random nickname pattern to show toast
    func checkRandomNickname() {
        guard let nick = currentUser?.nickname else { return }
        // Patterns: "User_XXXX", "KakaoUser_XXXX", "NaverUser_XXXX"
        if nick.hasPrefix("User_") || nick.hasPrefix("KakaoUser_") || nick.hasPrefix("NaverUser_") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.errorMessage = "random_nickname_notice".localized // Reusing errorMessage as Toast trigger or use generic warning.
                // Better: Use a dedicated published property for this specific toast
            }
        }
    }
    
    // Dedicated property for random nickname toast
    @Published var showRandomNicknameToast = false
    
    func updateProfile(nickname: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        APIService.shared.updateProfile(nickname: nickname) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let response):
                    self?.currentUser = response.user
                    completion(true)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(false)
                }
            }
        }
    }
    
    func updateSettings(_ settings: UserSettings) {
        isLoading = true
        APIService.shared.updateSettings(settings: settings) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let response):
                    self?.currentUser = response.user
                    print("✅ Settings updated successfully")
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ Failed to update settings: \(error.localizedDescription)")
                }
            }
        }
    }
    func randomizeMask() {
        isLoading = true
        APIService.shared.regenerateMask { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let response):
                    self?.currentUser = response.user
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func deleteAccount() {
        isLoading = true
        APIService.shared.deleteAccount { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    self?.logout()
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Block & Report
    func fetchBlockedUsers() {
        guard isLoggedIn else { return }
        APIService.shared.getBlockedUsers { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    // Store IDs in Set for easy filtering
                    let ids = response.blockedUsers.compactMap { $0.id }
                    self?.blockedUserIds = Set(ids)
                    BLEManager.shared.blockedUserIds = self?.blockedUserIds ?? []
                    print("🚫 Fetched \(ids.count) blocked users")
                case .failure(let error):
                    print("⚠️ Failed to fetch blocked blocked users: \(error)")
                }
            }
        }
    }
    
    func blockUser(userId: String, completion: @escaping (Bool) -> Void) {
        APIService.shared.blockUser(targetUserId: userId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.blockedUserIds.insert(userId)
                    BLEManager.shared.blockedUserIds.insert(userId)
                    completion(true)
                case .failure(let error):
                    self?.errorMessage = "Block failed: \(error.localizedDescription)"
                    completion(false)
                }
            }
        }
    }
    
    func unblockUser(userId: String) {
        APIService.shared.unblockUser(targetUserId: userId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.blockedUserIds.remove(userId)
                    BLEManager.shared.blockedUserIds.remove(userId)
                case .failure(let error):
                    self?.errorMessage = "Unblock failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func reportUser(userId: String, reason: String, details: String?, completion: @escaping (Bool) -> Void) {
        APIService.shared.reportUser(targetUserId: userId, reason: reason, details: details) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    completion(true)
                case .failure(let error):
                    self?.errorMessage = "Report failed: \(error.localizedDescription)"
                    completion(false)
                }
            }
        }
    }
}
