import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var languageManager = LanguageManager.shared
    @State private var pushNotificationsEnabled = true // Mock state for now
    
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
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.textSecondary)
                            .padding()
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
                        .padding()
                    }
                }
            }
        }
    }
}
