import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @ObservedObject private var bleManager = BLEManager.shared // Observe BLEManager
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @AppStorage("isDarkMode") var isDarkMode: Bool = true // Observe Theme
    @State private var debugMessage: String?
    @State private var showToast = false
    @State private var showProfileEditSheet = false // Triggered by Toast
    @State private var restrictionType: SuspensionView.RestrictionType? = nil // Unified Suspension/Ban Stated Check
    
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        ZStack {
            if !hasSeenOnboarding {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                    .transition(.move(edge: .trailing))
                    .zIndex(10) // Ensure it's on top
            } else if bleManager.authorizationStatus == .notDetermined {
                BluetoothPermissionView {
                    BLEManager.shared.setup()
                    // Prompt will appear. Delegate update will refresh view.
                }
            } else if bleManager.authorizationStatus == .denied || bleManager.authorizationStatus == .restricted {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    Text("permission_denied".localized)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("permission_denied_desc".localized)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .foregroundColor(.gray)
                    Button(action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("open_settings".localized)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    Spacer()
                }
                .background(Color.black.edgesIgnoringSafeArea(.all))
            } else {
                NavigationView {
                    MainView(authViewModel: authViewModel)
                }
                .environmentObject(authViewModel)
                .background(Color.deepBlack)
                .preferredColorScheme(isDarkMode ? .dark : .light) // Dynamic Scheme
                .navigationViewStyle(StackNavigationViewStyle())
                .onAppear {
                    // Ensure BLEManager is running if authorized
                    BLEManager.shared.setup()
                }
            }
            
            // Debug Toast Overlay
            if showToast, let message = debugMessage {
                VStack {
                    HStack {
                        Spacer()
                        Text(message)
                            .font(.system(size: 11, weight: .medium, design: .monospaced)) // Smaller font
                            .foregroundColor(.black) // High contrast text
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.95)) // High contrast bg
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .padding(.top, 60) // Position below status bar/settings (adjust as needed)
                    .padding(.trailing, 16) // Right align
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
                .onTapGesture {
                    showToast = false
                }
                .onTapGesture {
                    showToast = false
                }
            }
            
            // Random Nickname Notification Overlay
            if authViewModel.showRandomNicknameToast {
                ZStack {
                    Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 20) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 50))
                            .foregroundColor(.neonGreen)
                        
                        Text("random_nickname_title".localized)
                            .font(.radarHeadline)
                            .multilineTextAlignment(.center)
                        
                        Text("random_nickname_desc".localized)
                            .font(.radarBody)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        HStack(spacing: 15) {
                            Button(action: {
                                withAnimation {
                                    authViewModel.showRandomNicknameToast = false
                                }
                            }) {
                                Text("keep_it".localized)
                                    .font(.radarBody)
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                            
                            Button(action: {
                                withAnimation {
                                    authViewModel.showRandomNicknameToast = false
                                    showProfileEditSheet = true // Present Edit View
                                }
                            }) {
                                Text("change_nickname".localized)
                                    .font(.radarBody)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Color.neonGreen)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(30)
                    .background(Color.deepBlack) // Or glassBlack
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.neonGreen.opacity(0.5), lineWidth: 1)
                    )
                    .padding(40)
                    .shadow(radius: 20)
                }
                .transition(.opacity)
                .zIndex(200) // Above everything
            }

            // Suspension/Ban Overlay (Highest zIndex)
            if let type = restrictionType {
                SuspensionView(type: type)
                    .zIndex(999)
                    .transition(.opacity)
            }
        }
        // Listen for Suspension Notification
        .onReceive(NotificationCenter.default.publisher(for: .accountSuspended)) { notification in
            if let date = notification.userInfo?["date"] as? Date {
                let reasonAny = notification.userInfo?["reason"]
                var reasonContainer: SuspensionView.ReasonContainer? = nil
                
                if let dict = reasonAny as? [String: String] {
                    reasonContainer = .localized(dict)
                } else if let str = reasonAny as? String {
                    reasonContainer = .text(str)
                }
                
                let suspendedAt = notification.userInfo?["suspendedAt"] as? Date
                withAnimation {
                    self.restrictionType = .suspended(date, reasonContainer, suspendedAt)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .accountBanned)) { notification in
            let reasonAny = notification.userInfo?["reason"]
            var reasonContainer: SuspensionView.ReasonContainer? = nil
            
            if let dict = reasonAny as? [String: String] {
                reasonContainer = .localized(dict)
            } else if let str = reasonAny as? String {
                reasonContainer = .text(str)
            }

            let suspendedAt = notification.userInfo?["suspendedAt"] as? Date
            withAnimation {
                self.restrictionType = .banned(reasonContainer, suspendedAt)
            }
        }
        .onReceive(APIService.shared.debugMessageSubject) { message in
            self.debugMessage = message
            self.showToast = true
            
            // Auto hide after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if self.debugMessage == message {
                    self.showToast = false
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                print("📱 App became active")
                if authViewModel.isLoggedIn {
                    authViewModel.checkUserStatus() // Force check suspension status
                    SocketManager.shared.connect()
                }
            case .background:
                print("📱 App went to background")
                // Keep socket connected for BLE/App liveness
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .onChange(of: authViewModel.isLoggedIn) { isLoggedIn in
            if isLoggedIn {
                print("✅ User logged in - Connecting Socket")
                SocketManager.shared.connect()
            } else {
                print("👋 User logged out - Disconnecting Socket")
                SocketManager.shared.disconnect()
            }
        }
        .onAppear {
            if authViewModel.isLoggedIn {
                print("🚀 App Launched - Connecting Socket")
                SocketManager.shared.connect()
            }
        }
        .sheet(isPresented: $showProfileEditSheet) {
            ProfileEditView(authViewModel: authViewModel)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
