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
    
    // Global State
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashView()
                        .environmentObject(themeManager)
                        .transition(.opacity) // Smooth fade out
                        .onAppear {
                            // Delay for splash screen duration
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation(.easeOut(duration: 0.5)) {
                                    showSplash = false
                                }
                            }
                        }
                } else {
                    ContentView()
                        .environmentObject(themeManager)
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
    }
}
