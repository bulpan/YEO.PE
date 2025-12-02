import Foundation
import Combine
import UIKit

#if canImport(NaverThirdPartyLogin)
import NaverThirdPartyLogin
#endif

class NaverAuthManager: NSObject, ObservableObject {
    private var completionHandler: ((Result<String, Error>) -> Void)?
    
    #if canImport(NaverThirdPartyLogin)
    private let loginInstance = NaverThirdPartyLoginConnection.getSharedInstance()
    #endif
    
    override init() {
        super.init()
        #if canImport(NaverThirdPartyLogin)
        loginInstance?.delegate = self
        #endif
    }
    
    func signIn(completion: @escaping (Result<String, Error>) -> Void) {
        self.completionHandler = completion
        #if canImport(NaverThirdPartyLogin)
        loginInstance?.requestThirdPartyLogin()
        #else
        print("NaverThirdPartyLogin SDK not imported")
        completion(.failure(NSError(domain: "NaverAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Naver SDK not installed"])))
        #endif
    }
}

#if canImport(NaverThirdPartyLogin)
extension NaverAuthManager: NaverThirdPartyLoginConnectionDelegate {
    func oauth20ConnectionDidFinishRequestACTokenWithAuthCode() {
        guard let instance = loginInstance else { return }
        if let accessToken = instance.accessToken {
            completionHandler?(.success(accessToken))
        } else {
            completionHandler?(.failure(NSError(domain: "NaverAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get access token"])))
        }
    }
    
    func oauth20ConnectionDidFinishRequestACTokenWithRefreshToken() {
        guard let instance = loginInstance else { return }
        if let accessToken = instance.accessToken {
            completionHandler?(.success(accessToken))
        } else {
            completionHandler?(.failure(NSError(domain: "NaverAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to refresh token"])))
        }
    }
    
    func oauth20ConnectionDidFinishDeleteToken() {
        // Logout success
    }
    
    func oauth20Connection(_ oauthConnection: NaverThirdPartyLoginConnection!, didFailWithError error: Error!) {
        completionHandler?(.failure(error))
    }
}
#endif
