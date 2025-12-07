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
    
    var userId: String? {
        return currentUser?.id
    }
    
    init() {
        self.isLoggedIn = TokenManager.shared.isLoggedIn
        if self.isLoggedIn {
            fetchProfile()
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
}
