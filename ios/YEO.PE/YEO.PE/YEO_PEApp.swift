//
//  YEO_PEApp.swift
//  YEO.PE
//
//  Created by sweet home on 11/28/25.
//

import SwiftUI

#if canImport(KakaoSDKAuth)
import KakaoSDKAuth
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(NaverThirdPartyLogin)
import NaverThirdPartyLogin
#endif

@main
struct YEO_PEApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    #if canImport(KakaoSDKAuth)
                    if (AuthApi.isKakaoTalkLoginUrl(url)) {
                        _ = AuthController.handleOpenUrl(url: url)
                    }
                    #endif
                    
                    #if canImport(GoogleSignIn)
                    _ = GIDSignIn.sharedInstance.handle(url)
                    #endif
                    
                    #if canImport(NaverThirdPartyLogin)
                    NaverThirdPartyLoginConnection.getSharedInstance().receiveAccessToken(url)
                    #endif
                }
        }
    }
}
