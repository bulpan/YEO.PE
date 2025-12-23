import Foundation
import Combine
import UIKit

class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var nickname = ""
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var keepLoggedIn = true // Default to true for better background experience
    @Published var currentUser: User? {
        didSet {
            if let visible = currentUser?.settings?.bleVisible {
                BLEManager.shared.isStealthMode = !visible
            }
        }
    }
    @Published var blockedUserIds: Set<String> = []
    @Published var blockedUsers: [User] = [] // Added for UI List
    @Published var showIdentityRegeneratedAlert = false
    
    var userId: String? {
        return currentUser?.id
    }
    
    init() {
        self.isLoggedIn = TokenManager.shared.isLoggedIn
        if self.isLoggedIn {
            fetchProfile()
            fetchBlockedUsers()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleIdentityUpdate), name: .identityUpdated, object: nil)
    }

// ... existing login/register methods ...

    // MARK: - Block & Report
    func fetchBlockedUsers() {
        guard isLoggedIn else { return }
        isLoading = true
        APIService.shared.getBlockedUsers { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let response):
                    // Store IDs for filtering
                    let ids = response.blockedUsers.compactMap { $0.id }
                    self?.blockedUserIds = Set(ids)
                    
                    // Store full objects for UI list
                    self?.blockedUsers = response.blockedUsers
                    
                    BLEManager.shared.blockedUserIds = self?.blockedUserIds ?? []
                    print("🚫 Fetched \(ids.count) blocked users")
                case .failure(let error):
                    print("⚠️ Failed to fetch blocked blocked users: \(error)")
                }
            }
        }
    }
    
    @objc private func handleIdentityUpdate(_ notification: Notification) {
        DispatchQueue.main.async {
            if self.isLoggedIn {
                self.fetchProfile()
                self.showIdentityRegeneratedAlert = true
            }
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
        // [Logout Cleanup] Notify server first
        APIService.shared.request("/auth/logout", method: "POST") { [weak self] (result: Result<[String: String], Error>) in
            DispatchQueue.main.async {
                // Clear tokens regardless of server success/failure
                TokenManager.shared.clearTokens()
                
                // Stop BLE to prevent ghost user (User disappears from Radar)
                BLEManager.shared.stop()
                BLEManager.shared.discoveredUsers.removeAll()
                
                self?.isLoggedIn = false
                self?.currentUser = nil
                self?.blockedUserIds.removeAll()
                BLEManager.shared.blockedUserIds.removeAll()
                
                // [Logout Cleanup] Notify other ViewModels
                NotificationCenter.default.post(name: NSNotification.Name("UserDidLogout"), object: nil)
            }
        }
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
    
    func updateProfile(nickname: String? = nil, nicknameMask: String? = nil, completion: @escaping (Bool) -> Void) {
        isLoading = true
        APIService.shared.updateProfile(nickname: nickname, nicknameMask: nicknameMask) { [weak self] result in
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
    
    func uploadProfileImage(_ image: UIImage) {
        isLoading = true
        APIService.shared.uploadImage(image: image) { [weak self] result in
            switch result {
            case .success(let imageUrl):
                print("✅ Image uploaded: \(imageUrl). Updating profile...")
                // Now update profile with this URL
                APIService.shared.updateProfile(profileImageUrl: imageUrl) { [weak self] profileResult in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        switch profileResult {
                        case .success(let response):
                            self?.currentUser = response.user
                            print("✅ Profile image updated!")
                        case .failure(let error):
                            self?.errorMessage = error.localizedDescription
                        }
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.errorMessage = error.localizedDescription
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
