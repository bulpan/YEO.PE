import SwiftUI
import Combine

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    // ObservedObjects
    @ObservedObject var languageManager = LanguageManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var appIconManager = AppIconManager.shared
    @ObservedObject var authViewModel: AuthViewModel
    
    // Local State
    @State private var pushNotificationsEnabled = true
    @State private var messageRetention = 24
    @State private var roomExitCondition = "24h"
    @State private var maskId = true
    @State private var showProfileEdit = false
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showBlockedUsers = false
    @State private var showPushPermissionAlert = false
    @State private var showOpenSource = false
    
    // Server Config
    @State private var selectedEnvironment: ServerEnvironment = .production
    @State private var tempLocalIP: String = ""
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        _pushNotificationsEnabled = State(initialValue: authViewModel.currentUser?.settings?.pushEnabled ?? true)
        _messageRetention = State(initialValue: authViewModel.currentUser?.settings?.messageRetention ?? 24)
        _roomExitCondition = State(initialValue: authViewModel.currentUser?.settings?.roomExitCondition ?? "24h")
        _maskId = State(initialValue: authViewModel.currentUser?.settings?.maskId ?? true)
        
        _selectedEnvironment = State(initialValue: ServerConfig.shared.environment)
        _tempLocalIP = State(initialValue: ServerConfig.shared.localIP)
    }
    
    var body: some View {
        ZStack {
            Color.theme.bgMain.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(spacing: 20) {
                        profileSection
                        uiSection
                        notificationSection
                        messageSection
                        privacySection
                        developerSection
                        legalSection
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        
        .sheet(isPresented: $showProfileEdit) {
            ProfileEditView(authViewModel: authViewModel)
        }
        .sheet(isPresented: $showTerms) {
            WebViewScreen(urlString: "https://yeo.pe/terms", title: "terms_of_service".localized)
        }
        .sheet(isPresented: $showPrivacy) {
            WebViewScreen(urlString: "https://yeo.pe/privacy", title: "privacy_policy".localized)
        }
        .sheet(isPresented: $showBlockedUsers) {
            NavigationView {
                BlockedUsersView(authViewModel: authViewModel)
            }
        }
        .sheet(isPresented: $showOpenSource) {
            OpenSourceLicensesView()
        }
        .alert(isPresented: $showPushPermissionAlert) {
            Alert(
                title: Text("permission_denied".localized),
                message: Text("push_permission_desc".localized),
                primaryButton: .default(Text("open_settings".localized), action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }),
                secondaryButton: .cancel()
            )
        }
        // Immediate Saving
        .onChange(of: pushNotificationsEnabled) { _ in saveSettings() }
        .onChange(of: messageRetention) { _ in saveSettings() }
        .onChange(of: roomExitCondition) { _ in saveSettings() }
        .onChange(of: maskId) { _ in saveSettings() }
        .onChange(of: selectedEnvironment) { _ in saveSettings() }
        .onChange(of: tempLocalIP) { _ in saveSettings() }
    }
    
    // MARK: - Subviews
    
    var headerView: some View {
        HStack {
            Text("settings".localized)
                .font(.radarHeadline)
                .foregroundColor(Color.theme.accentPrimary)
            Spacer()
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.theme.accentPrimary)
            }
        }
        .padding()
        .background(Color.theme.bgMain)
    }
    
    var profileSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("profile".localized)
                .font(.radarCaption)
                .foregroundColor(Color.theme.textSecondary)
                .padding(.leading, 4)
            
            Button(action: { showProfileEdit = true }) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.theme.accentPrimary.opacity(0.1))
                            .frame(width: 50, height: 50)
                            .overlay(Circle().stroke(Color.theme.accentPrimary, lineWidth: 1))
                        
                        Text(authViewModel.currentUser?.nickname?.prefix(1).uppercased() ?? "?")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color.theme.accentPrimary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(authViewModel.currentUser?.nickname ?? "Unknown")
                            .font(.radarBody)
                            .foregroundColor(Color.theme.textPrimary)
                        Text(authViewModel.currentUser?.email ?? "")
                            .font(.radarCaption)
                            .foregroundColor(.gray)
                    }
                    .padding(.leading, 8)
                    
                    Spacer()
                    
                    Image(systemName: "pencil")
                        .foregroundColor(Color.theme.accentPrimary)
                }
                .padding()
                .background(Color.theme.bgLayer1)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.theme.borderSubtle, lineWidth: 1))
            }
        }
        .padding(.horizontal)
    }
    
    var uiSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("appearance".localized)
                .font(.radarCaption)
                .foregroundColor(Color.theme.textSecondary)
                .padding(.leading, 4)
            
            // Dark Mode
            HStack {
                Text("dark_mode".localized)
                    .foregroundColor(Color.theme.textPrimary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { themeManager.isDarkMode },
                    set: { themeManager.isDarkMode = $0 }
                ))
                .toggleStyle(SwitchToggleStyle(tint: Color.theme.accentPrimary))
                .labelsHidden()
            }
            .padding()
            .background(Color.theme.bgLayer1)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.theme.borderSubtle, lineWidth: 1))
            
            // App Icon
            VStack(alignment: .leading, spacing: 10) {
                Text("app_icon".localized)
                    .font(.radarBody)
                    .foregroundColor(Color.theme.textPrimary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(AppIcon.allCases) { icon in
                            VStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(iconForColor(icon))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(appIconManager.currentIcon == icon ? Color.theme.accentPrimary : Color.clear, lineWidth: 3)
                                    )
                                    .onTapGesture {
                                        appIconManager.changeIcon(to: icon)
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .padding()
                .background(Color.theme.bgLayer1)
                .cornerRadius(12)
            }
            
            // Language
            HStack {
                Text("language".localized)
                    .foregroundColor(Color.theme.textPrimary)
                Spacer()
                Picker("language".localized, selection: $languageManager.currentLanguage) {
                    ForEach(Language.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .accentColor(Color.theme.accentPrimary)
            }
            .padding()
            .background(Color.theme.bgLayer1)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.theme.borderSubtle, lineWidth: 1))
        }
        .padding(.horizontal)
    }
    
    var notificationSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("notifications".localized) // "Notifications"
                .font(.radarCaption)
                .foregroundColor(Color.theme.textSecondary)
                .padding(.leading, 4)
            
            HStack {
                Text("push_notifications".localized)
                    .foregroundColor(Color.theme.textPrimary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { pushNotificationsEnabled },
                    set: { newValue in
                        if newValue {
                            checkPushAuth { granted in
                                if granted {
                                    pushNotificationsEnabled = true
                                } else {
                                    pushNotificationsEnabled = false
                                    showPushPermissionAlert = true
                                }
                            }
                        } else {
                            pushNotificationsEnabled = false
                        }
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: Color.theme.accentPrimary))
                .labelsHidden()
            }
            .padding()
            .background(Color.theme.bgLayer1)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.theme.borderSubtle, lineWidth: 1))
        }
        .padding(.horizontal)
    }
    
    var messageSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("message_settings".localized)
                .font(.radarCaption)
                .foregroundColor(Color.theme.textSecondary)
                .padding(.leading, 4)
            
            // Retention
            HStack {
                Text("message_retention".localized)
                    .foregroundColor(Color.theme.textPrimary)
                Spacer()
                Picker("Retention", selection: $messageRetention) {
                    Text("6_hours".localized).tag(6)
                    Text("12_hours".localized).tag(12)
                    Text("24_hours".localized).tag(24)
                }
                .pickerStyle(MenuPickerStyle())
                .accentColor(Color.theme.accentPrimary)
            }
            .padding()
            .background(Color.theme.bgLayer1)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.theme.borderSubtle, lineWidth: 1))
            
            // Room Exit
            HStack {
                Text("room_exit_condition".localized)
                    .foregroundColor(Color.theme.textPrimary)
                Spacer()
                Picker("Exit Condition", selection: $roomExitCondition) {
                    Text("24_hours".localized).tag("24h")
                    Text("off".localized).tag("off")
                    Text("activity_based".localized).tag("activity")
                }
                .pickerStyle(MenuPickerStyle())
                .accentColor(Color.theme.accentPrimary)
            }
            .padding()
            .background(Color.theme.bgLayer1)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.theme.borderSubtle, lineWidth: 1))
        }
        .padding(.horizontal)
    }
    
    var privacySection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("privacy_settings".localized)
                .font(.radarCaption)
                .foregroundColor(Color.theme.textSecondary)
                .padding(.leading, 4)
            
            // Mask ID
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("mask_id".localized)
                        .foregroundColor(Color.theme.textPrimary)
                    
                    if maskId, let nickname = authViewModel.currentUser?.nickname {
                        let maskedName = nickname.count > 2 
                            ? String(nickname.prefix(2)) + "****" 
                            : String(nickname.prefix(1)) + "****"
                        
                        HStack(spacing: 4) {
                            Image(systemName: "eye.slash.fill")
                                .font(.caption)
                            Text("ID: \(maskedName)")
                                .font(.caption)
                        }
                        .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: $maskId)
                    .toggleStyle(SwitchToggleStyle(tint: Color.theme.accentPrimary))
                    .labelsHidden()
            }
            .padding()
            .background(Color.theme.bgLayer1)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.theme.borderSubtle, lineWidth: 1))
            
            // Blocked Users
            Button(action: { showBlockedUsers = true }) {
                HStack {
                    Text("blocked_users".localized)
                        .foregroundColor(Color.theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.theme.bgLayer1)
            }
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.theme.borderSubtle, lineWidth: 1))
        }
        .padding(.horizontal)
    }
    
    var developerSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("developer_settings".localized)
                .font(.radarCaption)
                .foregroundColor(Color.theme.textSecondary)
                .padding(.leading, 4)
            
            // Environment
            HStack {
                Text("environment".localized)
                    .foregroundColor(Color.theme.textPrimary)
                Spacer()
                Picker("environment".localized, selection: $selectedEnvironment) {
                    ForEach(ServerEnvironment.allCases, id: \.self) { env in
                        Text(env.rawValue.capitalized).tag(env)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            .padding()
            .background(Color.theme.bgLayer1)
            .cornerRadius(12)
            
            // Local IP
            if selectedEnvironment == .local {
                VStack(alignment: .leading) {
                    Text("local_ip".localized)
                        .foregroundColor(.gray)
                        .font(.caption)
                    TextField("192.168.x.x", text: $tempLocalIP)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numbersAndPunctuation)
                }
                .padding()
                .background(Color.theme.bgLayer1)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
    
    var legalSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("legal".localized)
                .font(.radarCaption)
                .foregroundColor(Color.theme.textSecondary)
                .padding(.leading, 4)
            
            HStack(spacing: 0) {
                Button(action: { showTerms = true }) {
                    HStack {
                        Text("terms_of_service".localized)
                            .foregroundColor(Color.theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.theme.bgLayer1)
                }
            }
            .cornerRadius(12)
            
            Divider().background(Color.theme.borderSubtle)
            
            Button(action: { showPrivacy = true }) {
                HStack {
                    Text("privacy_policy".localized)
                        .foregroundColor(Color.theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.gray)
                }
                .padding()
                .background(Color.theme.bgLayer1)
            }
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.theme.borderSubtle, lineWidth: 1))
            
            Divider().background(Color.theme.borderSubtle)
            
            Button(action: { showOpenSource = true }) {
                HStack {
                    Text("open_source_licenses".localized)
                        .foregroundColor(Color.theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.gray)
                }
                .padding()
                .background(Color.theme.bgLayer1)
            }
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.theme.borderSubtle, lineWidth: 1))
        }
        .padding(.horizontal)
    }
    
    // MARK: - Functions
    
    func saveSettings() {
        var settings = authViewModel.currentUser?.settings ?? UserSettings(
            bleVisible: true,
            pushEnabled: true,
            messageRetention: 24,
            roomExitCondition: "24h",
            maskId: true
        )
        
        settings.pushEnabled = pushNotificationsEnabled
        settings.messageRetention = messageRetention
        settings.roomExitCondition = roomExitCondition
        settings.maskId = maskId
        
        authViewModel.updateSettings(settings)
        
        // Save Server Config
        ServerConfig.shared.setEnvironment(selectedEnvironment)
        if selectedEnvironment == .local && !tempLocalIP.isEmpty {
            ServerConfig.shared.setLocalIP(tempLocalIP)
        }
    }
    
    func checkPushAuth(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized {
                    completion(true)
                } else if settings.authorizationStatus == .denied {
                    completion(false)
                } else {
                    center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                        DispatchQueue.main.async { completion(granted) }
                    }
                }
            }
        }
    }
    
    func iconForColor(_ icon: AppIcon) -> Color {
        switch icon {
        case .primary: return Color.black
        case .dark: return Color.deepBlack
        case .neon: return Color.neonGreen
        }
    }
}
