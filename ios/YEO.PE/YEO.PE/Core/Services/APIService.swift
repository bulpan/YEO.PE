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
        
            // Debug: Request (Disabled for Toast by logic below, only print)
            print("🚀 [\(method)] \(endpoint)")
            // REMOVED: DispatchQueue.main.async { self.debugMessageSubject.send(debugReq) }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData // Fix: Always fetch fresh data from server
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
            
            // Handle non-200 responses systematically
            if !(200...299).contains(httpResponse.statusCode) {
                var errorMessage = "Server Error: \(httpResponse.statusCode)"
                
                // Try to parse error message from body
                if let data = data, let errorResponse = try? JSONDecoder().decode(StandardResponse.self, from: data), let msg = errorResponse.message {
                    errorMessage = msg
                } else if let data = data, let str = String(data: data, encoding: .utf8) {
                    // Fallback to string body if short
                    if str.count < 200 { errorMessage = str }
                }
                
                DispatchQueue.main.async { self.debugMessageSubject.send("⚠️ API Error: \(errorMessage)") }
                print("❌ API Error [\(httpResponse.statusCode)]: \(errorMessage)")
                
                // Map status codes to specific errors if needed
                if httpResponse.statusCode == 403 {
                    // Check for Suspension
                    if let data = data,
                       let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                        
                        if errorResponse.error.code == "USER_SUSPENDED" {
                            var suspendedDate: Date? = nil
                            var suspendedAtDate: Date? = nil
                            let formatter = ISO8601DateFormatter()
                            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                            
                            if let dateStr = errorResponse.error.details?.suspendedUntil {
                               suspendedDate = formatter.date(from: dateStr)
                            }
                            if let satStr = errorResponse.error.details?.suspendedAt {
                                suspendedAtDate = formatter.date(from: satStr)
                            }
                            
                                if let satStr = errorResponse.error.details?.suspendedAt {
                                    suspendedAtDate = formatter.date(from: satStr)
                                }
                            
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: .accountSuspended, object: nil, userInfo: [
                                    "date": suspendedDate as Any, 
                                    "date": suspendedDate as Any, 
                                    "reason": (errorResponse.error.details?.reasonDict ?? errorResponse.error.details?.reasonString) as Any,
                                    "suspendedAt": suspendedAtDate as Any
                                ])
                            }
                            
                            completion(.failure(APIError.serverError("Account Suspended")))
                            return
                        } else if errorResponse.error.code == "USER_BANNED" {
                            let reason = (errorResponse.error.details?.reasonDict ?? errorResponse.error.details?.reasonString)
                            var suspendedAtDate: Date? = nil
                            let formatter = ISO8601DateFormatter()
                            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                             
                            if let satStr = errorResponse.error.details?.suspendedAt {
                                suspendedAtDate = formatter.date(from: satStr)
                            }
                            
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: .accountBanned, object: nil, userInfo: [
                                    "reason": reason as Any,
                                    "suspendedAt": suspendedAtDate as Any
                                ])
                            }
                            completion(.failure(APIError.serverError("Account Banned")))
                            return
                        }
                    }
                    
                    completion(.failure(APIError.unauthorized)) // Treat other 403 as auth/unauthorized
                } else if httpResponse.statusCode == 401 {
                    completion(.failure(APIError.unauthorized))
                } else {
                    completion(.failure(APIError.serverError(errorMessage)))
                }
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            
            // Success 200: Do NOT send debug toast, just print
            if let str = String(data: data, encoding: .utf8) {
                print("API Response: \(str)") 
            }
            
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                print("❌ Decoding Error for \(T.self): \(error)")
                // Helpful debug print for decoding errors
                if let str = String(data: data, encoding: .utf8) {
                    print("⬇️ Received JSON: \(str)")
                }
                
                DispatchQueue.main.async { self.debugMessageSubject.send("❌ Decoding Error") }
                completion(.failure(APIError.decodingError))
            }
        }.resume()
    }
    
    func registerFCMToken(token: String?) {
        // Guard: Only register if logged in
        guard TokenManager.shared.isLoggedIn else { return }

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
    func regenerateMask(completion: @escaping (Result<UserResponse, Error>) -> Void) {
        request("/users/me/mask", method: "POST", completion: completion)
    }
    
    func deleteAccount(completion: @escaping (Result<StandardResponse, Error>) -> Void) {
        request("/users/me", method: "DELETE", completion: completion)
    }
    
    // MARK: - Block & Report
    func blockUser(targetUserId: String, completion: @escaping (Result<StandardResponse, Error>) -> Void) {
        let body = ["targetUserId": targetUserId]
        request("/users/block", method: "POST", body: body, completion: completion)
    }
    
    func unblockUser(targetUserId: String, completion: @escaping (Result<StandardResponse, Error>) -> Void) {
        let body = ["targetUserId": targetUserId]
        request("/users/unblock", method: "POST", body: body, completion: completion)
    }
    
    func getBlockedUsers(completion: @escaping (Result<BlockedUsersResponse, Error>) -> Void) {
        request("/users/blocked", method: "GET", completion: completion)
    }
    
    // MARK: - Image Upload
    func uploadImage(image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(AppConfig.apiBaseURL)/upload/image") else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if let token = TokenManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.7) ?? image.pngData() else {
            completion(.failure(APIError.serverError("Image data conversion failed")))
            return
        }
        
        var body = Data()
        let filename = "\(UUID().uuidString).jpg"
        let mimeType = "image/jpeg"
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(APIError.noData)) }
                return
            }
            
            DispatchQueue.main.async { 
                print("Image Upload Response: \(String(data: data, encoding: .utf8) ?? "nil")") 
            }
            
            // Expected Response: { "imageUrl": "..." }
            struct UploadResponse: Decodable {
                let imageUrl: String
            }
            
            do {
                let decoded = try JSONDecoder().decode(UploadResponse.self, from: data)
                DispatchQueue.main.async { completion(.success(decoded.imageUrl)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(APIError.decodingError)) }
            }
        }.resume()
    }

    func updateProfile(nickname: String? = nil, nicknameMask: String? = nil, profileImageUrl: String? = nil, completion: @escaping (Result<UserResponse, Error>) -> Void) {
        var body: [String: Any] = [:]
        if let nickname = nickname { body["nickname"] = nickname }
        if let nicknameMask = nicknameMask { body["nicknameMask"] = nicknameMask }
        if let profileImageUrl = profileImageUrl { body["profileImageUrl"] = profileImageUrl }
        request("/users/me", method: "PATCH", body: body, completion: completion)
    }
    
    func reportUser(targetUserId: String, reason: String, details: String?, completion: @escaping (Result<StandardResponse, Error>) -> Void) {
        var body = ["targetUserId": targetUserId, "reason": reason]
        if let details = details {
            body["details"] = details
        }
        request("/reports", method: "POST", body: body, completion: completion)
    }
    
    func appealSuspension(reason: String, completion: @escaping (Result<StandardResponse, Error>) -> Void) {
        let body = ["reason": reason]
        request("/users/appeal", method: "POST", body: body, completion: completion)
    }

    func fetchAppConfig(completion: @escaping (Result<AppConfigResponse, Error>) -> Void) {
        request("/config", method: "GET", completion: completion)
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
    let room: Room?
}

struct BlockedUsersResponse: Decodable {
    let blockedUsers: [User]
}

struct ErrorResponse: Decodable {
    let error: ErrorObj
}

struct ErrorObj: Decodable {
    let message: String
    let code: String?
    let details: ErrorDetail?
}

// 1. Add suspendedAt to ErrorDetail struct
struct ErrorDetail: Decodable {
    let suspendedUntil: String?
    let suspendedAt: String?
    let reasonString: String?
    let reasonDict: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case suspendedUntil, suspendedAt, reason
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        suspendedUntil = try container.decodeIfPresent(String.self, forKey: .suspendedUntil)
        suspendedAt = try container.decodeIfPresent(String.self, forKey: .suspendedAt)
        
        if let str = try? container.decode(String.self, forKey: .reason) {
            reasonString = str
            reasonDict = nil
        } else if let dict = try? container.decode([String: String].self, forKey: .reason) {
            reasonString = nil
            reasonDict = dict
        } else {
            reasonString = nil
            reasonDict = nil
        }
    }
}

struct AppConfigResponse: Decodable {
    let notice: AppNotice
}

struct AppNotice: Decodable {
    let active: Bool
    let version: Int
    let content: LocalizedContent
}

struct LocalizedContent: Decodable {
    let ko: String
    let en: String
}

// 2. Update USER_SUSPENDED and USER_BANNED handling in APIService.swift (conceptually - using replace logic below)

extension Notification.Name {
    static let accountSuspended = Notification.Name("accountSuspended")
    static let accountBanned = Notification.Name("accountBanned")
}
