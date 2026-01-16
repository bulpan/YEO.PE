import Foundation
import Combine

enum ServerEnvironment: String, CaseIterable, Identifiable {
    case production = "Production"
    case local = "Local"
    
    var id: String { self.rawValue }
}

class ServerConfig: ObservableObject {
    static let shared = ServerConfig()
    
    @Published var environment: ServerEnvironment {
        didSet {
            UserDefaults.standard.set(environment.rawValue, forKey: "serverEnvironment")
        }
    }
    
    @Published var localIP: String {
        didSet {
            UserDefaults.standard.set(localIP, forKey: "localServerIP")
        }
    }
    
    // Production Defaults
    // Production Defaults
    private let productionAPI = "https://yeop3.com/api"
    private let productionSocket = "https://yeop3.com" // Use https scheme for Socket.IO client to handle polling/WSS correctly
    
    // Default Local
    private let defaultLocalIP = "192.168.219.167"
    
    private init() {
        // 1. Try to load saved preference
        let savedEnvString = UserDefaults.standard.string(forKey: "serverEnvironment")
        
        if let savedEnvString = savedEnvString, let savedEnv = ServerEnvironment(rawValue: savedEnvString) {
            self.environment = savedEnv
        } else {
            // 2. Default if no preference (First Launch)
            self.environment = .production
        }
        
        // 3. Setup Local IP (Always load generated for Debug convenience, or saved for Release)
        #if DEBUG
        self.localIP = GeneratedConfig.localIP
        #else
        self.localIP = UserDefaults.standard.string(forKey: "localServerIP") ?? defaultLocalIP
        #endif
    }
    
    var apiBaseURL: String {
        switch environment {
        case .production:
            return productionAPI
        case .local:
            return "http://\(localIP):3000/api"
        }
    }
    
    var socketURL: String {
        switch environment {
        case .production:
            return productionSocket
        case .local:
            return "ws://\(localIP):3000"
        }
    }
    
    // MARK: - Setters
    
    func setEnvironment(_ environment: ServerEnvironment) {
        self.environment = environment
    }
    
    func setLocalIP(_ ip: String) {
        self.localIP = ip
    }
}
