import Foundation
import Combine
import SwiftUI

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

class GoogleAuthManager: ObservableObject {
    
    func signIn(completion: @escaping (Result<String, Error>) -> Void) {
        #if canImport(GoogleSignIn)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            completion(.failure(NSError(domain: "GoogleAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Root View Controller not found"])))
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                completion(.failure(NSError(domain: "GoogleAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get ID Token"])))
                return
            }
            
            completion(.success(idToken))
        }
        #else
        print("GoogleSignIn SDK not imported")
        completion(.failure(NSError(domain: "GoogleAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "GoogleSignIn SDK not installed"])))
        #endif
    }
}
