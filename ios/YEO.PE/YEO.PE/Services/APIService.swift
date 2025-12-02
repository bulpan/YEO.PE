import Foundation
import Combine

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
}
