import Foundation
import Combine

class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var nickname = ""
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var keepLoggedIn = false // Default to false
    
    init() {
        self.isLoggedIn = TokenManager.shared.isLoggedIn
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
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func logout() {
        TokenManager.shared.clearTokens()
        isLoggedIn = false
    }
}
