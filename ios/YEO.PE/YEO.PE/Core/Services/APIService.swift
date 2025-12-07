import Foundation
import Combine
import UIKit

enum APIError: Error {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
    case unauthorized
}

class APIService {
    static let shared = APIService()
    
    // Debug Subject
    let debugMessageSubject = PassthroughSubject<String, Never>()
    
    private init() {}
    
    func request<T: Decodable>(_ endpoint: String, method: String = "GET", body: [String: Any]? = nil, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(AppConfig.apiBaseURL)\(endpoint)") else {
            print("❌ Invalid URL: \(AppConfig.apiBaseURL)\(endpoint)")
            completion(.failure(APIError.invalidURL))
            return
        }
        
        // Debug: Request
        let debugReq = "🚀 [\(method)] \(endpoint)"
        print(debugReq)
        DispatchQueue.main.async { self.debugMessageSubject.send(debugReq) }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = TokenManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            } catch {
                completion(.failure(error))
                return
            }
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network Error: \(error.localizedDescription)")
                DispatchQueue.main.async { self.debugMessageSubject.send("❌ Error: \(error.localizedDescription)") }
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid Response: Not HTTP")
                completion(.failure(APIError.serverError("Invalid response")))
                return
            }
            
            print("✅ Response Status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 401 {
                // Handle token expiration
                DispatchQueue.main.async { self.debugMessageSubject.send("⚠️ 401 Unauthorized") }
                completion(.failure(APIError.unauthorized))
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            
            // Debug print
            if let str = String(data: data, encoding: .utf8) {
                print("API Response: \(str)")
                // Truncate long responses for toast
                let displayStr = str.count > 100 ? String(str.prefix(100)) + "..." : str
                DispatchQueue.main.async { self.debugMessageSubject.send("✅ [\(httpResponse.statusCode)] \(displayStr)") }
            }
            
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(APIError.decodingError))
            }
        }.resume()
    }
    
    func registerFCMToken(token: String?) {
        // If token is nil, try to get from UserDefaults or just return
        // Use TokenManager if available, otherwise fallback to direct UserDefaults
        let savedToken = TokenManager.shared.fcmToken ?? UserDefaults.standard.string(forKey: "fcmToken")
        
        print("🔍 registerFCMToken called. Input token: \(token ?? "nil"), Saved token: \(savedToken ?? "nil")")
        
        guard let token = token ?? savedToken else {
            print("⚠️ No FCM token to register (Both input and saved tokens are nil)")
            return
        }
        
        print("📲 Registering FCM Token: \(token)")
        
        let body: [String: Any] = [
            "deviceToken": token,
            "platform": "ios",
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "",
            "deviceInfo": [
                "systemName": UIDevice.current.systemName,
                "systemVersion": UIDevice.current.systemVersion,
                "model": UIDevice.current.model
            ]
        ]
        
        request("/push/register", method: "POST", body: body) { (result: Result<StandardResponse, Error>) in
            switch result {
            case .success:
                print("✅ FCM Token registered successfully")
            case .failure(let error):
                print("❌ Failed to register FCM token: \(error)")
            }
        }
    }
    
    func boostSignal(uids: [String], completion: @escaping (Result<BoostResponse, Error>) -> Void) {
        let body: [String: Any] = ["uids": uids]
        request("/users/boost", method: "POST", body: body, completion: completion)
    }
    
    func sendQuickQuestion(uids: [String], content: String, completion: @escaping (Result<QuickQuestionResponse, Error>) -> Void) {
        let body: [String: Any] = ["uids": uids, "content": content]
        request("/users/quick_question", method: "POST", body: body, completion: completion)
    }
    
    func updateSettings(settings: UserSettings, completion: @escaping (Result<UserResponse, Error>) -> Void) {
        do {
            let data = try JSONEncoder().encode(settings)
            let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            let body: [String: Any] = ["settings": dict ?? [:]]
            request("/users/me", method: "PATCH", body: body, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }
}

struct UserResponse: Decodable {
    let user: User
}

struct StandardResponse: Decodable {
    let success: Bool?
    let message: String?
}

struct BoostResponse: Decodable {
    let success: Bool?
    let boostedCount: Int?
    let message: String?
}

struct QuickQuestionResponse: Decodable {
    let success: Bool?
    let sentCount: Int?
    let message: String?
}
