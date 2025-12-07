import UIKit
import SwiftUI
import UserNotifications

#if canImport(KakaoSDKCommon)
import KakaoSDKCommon
import KakaoSDKAuth
#endif

#if canImport(NaverThirdPartyLogin)
import NaverThirdPartyLogin
#endif

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Initialize Firebase
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif
        
        // Initialize Kakao SDK
        #if canImport(KakaoSDKCommon)
        // Replace with your native app key
        KakaoSDK.initSDK(appKey: "YOUR_KAKAO_APP_KEY")
        #endif
        
        // Initialize Naver SDK
        #if canImport(NaverThirdPartyLogin)
        let instance = NaverThirdPartyLoginConnection.getSharedInstance()
        // Replace with your settings
        instance?.isNaverAppOauthEnable = true
        instance?.isInAppOauthEnable = true
        instance?.setOnlyPortraitSupportInIphone(true)
        
        instance?.serviceUrlScheme = "yeope" // Must match Info.plist
        instance?.consumerKey = "YOUR_NAVER_CLIENT_ID"
        instance?.consumerSecret = "YOUR_NAVER_CLIENT_SECRET"
        instance?.appName = "YEO.PE"
        #endif
        
        // Register for remote notifications
        registerForPushNotifications(application)
        
        return true
    }
    
    private func registerForPushNotifications(_ application: UIApplication) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().delegate = self
        #endif
        
        UNUserNotificationCenter.current().delegate = self
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            if let error = error {
                print("❌ Push Notification Authorization Error: \(error)")
                return
            }
            print("✅ Push Notification Authorization Granted: \(granted)")
        }
        
        application.registerForRemoteNotifications()
    }
    
    // Handle URL callbacks (Legacy)
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
        var handled = false
        
        #if canImport(KakaoSDKAuth)
        if (AuthApi.isKakaoTalkLoginUrl(url)) {
            handled = AuthController.handleOpenUrl(url: url)
        }
        #endif
        
        #if canImport(NaverThirdPartyLogin)
        if !handled {
            if url.scheme == "yeope" { // Must match your URL Scheme
                NaverThirdPartyLoginConnection.getSharedInstance().receiveAccessToken(url)
                handled = true
            }
        }
        #endif
        
        #if canImport(GoogleSignIn)
        if !handled {
            handled = GIDSignIn.sharedInstance.handle(url)
        }
        #endif
        
        return handled
    }
    
    // MARK: - APNs Registration
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        #endif
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📲 APNs Device Token: \(tokenString)")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    // Receive notification while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("🔔 Foreground Notification: \(userInfo)")
        
        // Show banner and play sound even in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("👆 Notification Tapped: \(userInfo)")
        
        // Handle deep linking
        if let action = userInfo["action"] as? String,
           let targetScreen = userInfo["targetScreen"] as? String {
            
            let targetId = userInfo["targetId"] as? String
            NavigationManager.shared.handleDeepLink(action: action, targetScreen: targetScreen, targetId: targetId)
        }
        
        completionHandler()
    }
}

// MARK: - MessagingDelegate (FCM)
#if canImport(FirebaseMessaging)
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }
        print("🔥 Firebase Registration Token: \(fcmToken)")
        
        // Save token for later use
        TokenManager.shared.fcmToken = fcmToken
        
        // Try to register if logged in
        APIService.shared.registerFCMToken(token: fcmToken)
    }
}
#endif
