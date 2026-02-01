import Foundation

struct AppConfig {
    static var apiBaseURL: String {
        return ServerConfig.shared.apiBaseURL
    }
    
    static var baseURL: String {
        return ServerConfig.shared.socketURL // Use base domain (e.g. https://yeop3.com or http://ip:3000)
    }
    
    static var socketURL: String {
        return ServerConfig.shared.socketURL
    }
}
