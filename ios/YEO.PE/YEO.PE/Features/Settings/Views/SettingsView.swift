import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var languageManager = LanguageManager.shared
    @ObservedObject var authViewModel: AuthViewModel // Inject AuthViewModel
    
    @State private var pushNotificationsEnabled = true
    @State private var messageRetention = 24
    @State private var roomExitCondition = "24h"
    @State private var maskId = true
    
    // Server Config States
    @State private var selectedEnvironment: ServerEnvironment = .production
    @State private var tempLocalIP: String = ""
    
    // Initialize with current user settings
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        _pushNotificationsEnabled = State(initialValue: authViewModel.currentUser?.settings?.pushEnabled ?? true)
        _messageRetention = State(initialValue: authViewModel.currentUser?.settings?.messageRetention ?? 24)
        _roomExitCondition = State(initialValue: authViewModel.currentUser?.settings?.roomExitCondition ?? "24h")
        _maskId = State(initialValue: authViewModel.currentUser?.settings?.maskId ?? true)
        
        // Initialize Server Config States
        _selectedEnvironment = State(initialValue: ServerConfig.shared.environment)
        _tempLocalIP = State(initialValue: ServerConfig.shared.localIP)
    }
    
    var body: some View {
        ZStack {
            Color.deepBlack.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("settings".localized)
                        .font(.radarHeadline)
                        .foregroundColor(.neonGreen)
                    
                    Spacer()
                    
                    Button(action: {
                        saveSettings()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("save".localized)
                            .font(.radarBody)
                            .foregroundColor(.neonGreen)
                    }
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // General Section
                        VStack(alignment: .leading, spacing: 15) {
                            Text("general".localized)
                                .font(.radarCaption)
                                .foregroundColor(.textSecondary)
                                .padding(.leading, 4)
                            
                            // Push Notifications
                            HStack {
                                Text("push_notifications".localized)
                                    .foregroundColor(.white)
                                Spacer()
                                Toggle("", isOn: $pushNotificationsEnabled)
                                    .toggleStyle(SwitchToggleStyle(tint: .neonGreen))
                                    .labelsHidden()
                            }
                            .padding()
                            .background(Color.glassBlack)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            
                            // Language
                            HStack {
                                Text("language".localized)
                                    .foregroundColor(.white)
                                Spacer()
                                
                                Picker("language".localized, selection: $languageManager.currentLanguage) {
                                    ForEach(Language.allCases, id: \.self) { language in
                                        Text(language.displayName).tag(language)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .accentColor(.neonGreen)
                            }
                            .padding()
                            .background(Color.glassBlack)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                        
                        // Message Settings
                        VStack(alignment: .leading, spacing: 15) {
                            Text("message_settings".localized)
                                .font(.radarCaption)
                                .foregroundColor(.textSecondary)
                                .padding(.leading, 4)
                            
                            // Message Retention
                            HStack {
                                Text("message_retention".localized)
                                    .foregroundColor(.white)
                                Spacer()
                                Picker("Retention", selection: $messageRetention) {
                                    Text("6 Hours").tag(6)
                                    Text("12 Hours").tag(12)
                                    Text("24 Hours").tag(24)
                                }
                                .pickerStyle(MenuPickerStyle())
                                .accentColor(.neonGreen)
                            }
                            .padding()
                            .background(Color.glassBlack)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            
                            // Room Exit Condition
                            HStack {
                                Text("room_exit_condition".localized)
                                    .foregroundColor(.white)
                                Spacer()
                                Picker("Exit Condition", selection: $roomExitCondition) {
                                    Text("24 Hours").tag("24h")
                                    Text("Off").tag("off")
                                    Text("Activity Based").tag("activity")
                                }
                                .pickerStyle(MenuPickerStyle())
                                .accentColor(.neonGreen)
                            }
                            .padding()
                            .background(Color.glassBlack)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                        
                        // Privacy Settings
                        VStack(alignment: .leading, spacing: 15) {
                            Text("privacy_settings".localized)
                                .font(.radarCaption)
                                .foregroundColor(.textSecondary)
                                .padding(.leading, 4)
                            
                            // Mask ID
                            HStack {
                                Text("mask_id".localized)
                                    .foregroundColor(.white)
                                Spacer()
                                Toggle("", isOn: $maskId)
                                    .toggleStyle(SwitchToggleStyle(tint: .neonGreen))
                                    .labelsHidden()
                            }
                            .padding()
                            .background(Color.glassBlack)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                        
                        // Developer Settings (Server Config)
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Developer Settings")
                                .font(.radarCaption)
                                .foregroundColor(.textSecondary)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 16) {
                                // Environment Picker
                                HStack {
                                    Text("Server Env")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Picker("Environment", selection: $selectedEnvironment) {
                                        ForEach(ServerEnvironment.allCases) { env in
                                            Text(env.rawValue).tag(env)
                                        }
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    .frame(width: 150)
                                }
                                
                                // Local IP Input
                                if selectedEnvironment == .local {
                                    Divider().background(Color.white.opacity(0.2))
                                    HStack {
                                        Text("Local IP")
                                            .foregroundColor(.white)
                                        Spacer()
                                        TextField("IP Address", text: $tempLocalIP)
                                            .multilineTextAlignment(.trailing)
                                            .foregroundColor(.neonGreen)
                                            .keyboardType(.numbersAndPunctuation)
                                            .autocapitalization(.none)
                                            .disableAutocorrection(true)
                                            .frame(width: 150)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.glassBlack)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    private func saveSettings() {
        // Detect Environment Change
        let previousEnv = ServerConfig.shared.environment
        let previousIP = ServerConfig.shared.localIP
        let envChanged = (previousEnv != selectedEnvironment) || 
                         (selectedEnvironment == .local && previousIP != tempLocalIP)
        
        // Save Server Config
        ServerConfig.shared.environment = selectedEnvironment
        ServerConfig.shared.localIP = tempLocalIP
        
        if envChanged {
            print("🔄 Server Environment changed. Resetting app state...")
            // 1. Clear Tokens & Logout
            authViewModel.logout()
            
            // 2. Clear BLE Manager State
            BLEManager.shared.stop()
            
            // 3. Dismiss Settings (Return to root, which should show LoginView)
            presentationMode.wrappedValue.dismiss()
            return
        }
        
        // Save User Settings (Only if logged in and env didn't change)
        let newSettings = UserSettings(
            bleVisible: true, // Keep existing or add UI for it
            pushEnabled: pushNotificationsEnabled,
            messageRetention: messageRetention,
            roomExitCondition: roomExitCondition,
            maskId: maskId
        )
        authViewModel.updateSettings(newSettings)
        
        presentationMode.wrappedValue.dismiss()
    }
}
