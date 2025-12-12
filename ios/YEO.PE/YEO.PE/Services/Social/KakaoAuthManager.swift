import Foundation
import Combine

#if canImport(KakaoSDKUser)
import KakaoSDKUser
import KakaoSDKAuth
import KakaoSDKCommon
#endif

class KakaoAuthManager: ObservableObject {
    
    func signIn(completion: @escaping (Result<String, Error>) -> Void) {
        #if canImport(KakaoSDKUser)
        if (UserApi.isKakaoTalkLoginAvailable()) {
            UserApi.shared.loginWithKakaoTalk {(oauthToken, error) in
                if let error = error {
                    print("KakaoTalk Login failed: \(error)")
                    // Fallback to Web Login
                    UserApi.shared.loginWithKakaoAccount {(oauthToken, error) in
                        if let error = error {
                            completion(.failure(error))
                        }
                        else {
                            if let token = oauthToken?.accessToken {
                                completion(.success(token))
                            } else {
                                completion(.failure(NSError(domain: "KakaoAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])))
                            }
                        }
                    }
                }
                else {
                    if let token = oauthToken?.accessToken {
                        completion(.success(token))
                    } else {
                        completion(.failure(NSError(domain: "KakaoAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])))
                    }
                }
            }
        } else {
            UserApi.shared.loginWithKakaoAccount {(oauthToken, error) in
                if let error = error {
                    completion(.failure(error))
                }
                else {
                    if let token = oauthToken?.accessToken {
                        completion(.success(token))
                    } else {
                        completion(.failure(NSError(domain: "KakaoAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])))
                    }
                }
            }
        }
        #else
        print("KakaoSDK not imported")
        completion(.failure(NSError(domain: "KakaoAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "KakaoSDK not installed"])))
        #endif
    }
}
