import Foundation

struct AppConfig {
    static var apiBaseURL: String {
        return ServerConfig.shared.apiBaseURL
    }
    
    static var socketURL: String {
        return ServerConfig.shared.socketURL
    }
}
