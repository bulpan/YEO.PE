import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Animation States
    @State private var isPulsing = false
    @State private var showLogoutAlert = false
    @State private var showDeleteAlert = false
    
    @State private var activeTooltip: String? = nil
    
    // Computed Properties for Settings
    private var bleVisibleBinding: Binding<Bool> {
        Binding(
            get: { viewModel.currentUser?.settings?.bleVisible ?? true },
            set: { newValue in
                var settings = viewModel.currentUser?.settings ?? UserSettings(bleVisible: true, pushEnabled: true, messageRetention: 24, roomExitCondition: "24h", maskId: true)
                settings.bleVisible = newValue
                viewModel.updateSettings(settings)
            }
        )
    }
    
    private var pushEnabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.currentUser?.settings?.pushEnabled ?? true },
            set: { newValue in
                var settings = viewModel.currentUser?.settings ?? UserSettings(bleVisible: true, pushEnabled: true, messageRetention: 24, roomExitCondition: "24h", maskId: true)
                settings.pushEnabled = newValue
                viewModel.updateSettings(settings)
            }
        )
    }
    
    var body: some View {
        ZStack {
            Color.theme.bgMain.edgesIgnoringSafeArea(.all) // Deep Black / Concrete Gray
            
            ScrollView {
                VStack(spacing: 28) { // Reduced to 70% of 40
                    
                    // 1. Header & Dismiss
                    HStack {
                        Spacer()
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                    
                    // 2. Identity Card section
                    VStack(spacing: 20) {
                        // Pulsing Avatar
                        ZStack {
                            Circle()
                                .stroke(Color.neonGreen.opacity(0.3), lineWidth: 1)
                                .frame(width: 140, height: 140)
                                .scaleEffect(isPulsing ? 1.2 : 1.0)
                                .opacity(isPulsing ? 0 : 1)
                                .animation(Animation.easeOut(duration: 2).repeatForever(autoreverses: false), value: isPulsing)
                            
                            Circle()
                                .stroke(Color.neonGreen, lineWidth: 2)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.neonGreen)
                                )
                                .shadow(color: .neonGreen.opacity(0.8), radius: 20)
                        }
                        .onAppear { isPulsing = true }
                        
                        // User Info
                        VStack(spacing: 8) {
                            Text(viewModel.currentUser?.nickname ?? "Anonymous")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.textPrimary)
                            
                            // Email Display
                            if let email = viewModel.currentUser?.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            HStack(spacing: 6) {
                                Image(systemName: "theatermasks.fill")
                                    .font(.caption)
                                Text("ID : \(viewModel.currentUser?.resolvedMask ?? "****")")
                                    .font(.system(size: 14, design: .monospaced))
                            }
                            .foregroundColor(.gray)
                        }
                        
                        // Status Badge
                        HStack(spacing: 6) {
                            Circle()
                                .fill(bleVisibleBinding.wrappedValue ? Color.neonGreen : Color.gray)
                                .frame(width: 8, height: 8)
                            
                            Text(bleVisibleBinding.wrappedValue ? "on_air".localized : "ghost_mode".localized)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(bleVisibleBinding.wrappedValue ? .neonGreen : .gray)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.textPrimary.opacity(0.05))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.textPrimary.opacity(0.1), lineWidth: 1)
                        )
                    }
                    
                    // 3. Control Grid (Bento Style)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        
                        // Cell 1: Ghost Mode
                        ControlCell(
                            icon: "eye.slash.fill",
                            title: "ghost_mode".localized,
                            subtitle: bleVisibleBinding.wrappedValue ? "visible".localized : "invisible".localized,
                            isOn: Binding(
                                get: { !bleVisibleBinding.wrappedValue },
                                set: { bleVisibleBinding.wrappedValue = !$0 }
                            ),
                            onInfoTap: { activeTooltip = "ghost_mode_tooltip" }
                        )
                        
                        // Cell 2: Notifications
                        ControlCell(
                            icon: "bell.fill",
                            title: "radar_alert".localized,
                            subtitle: pushEnabledBinding.wrappedValue ? "on".localized : "off".localized,
                            isOn: pushEnabledBinding.wrappedValueBinding,
                            onInfoTap: { activeTooltip = "radar_alert_tooltip" }
                        )
                        
                        // Cell 3: Change Mask
                        Button(action: {
                            viewModel.randomizeMask()
                        }) {
                            ZStack(alignment: .bottomTrailing) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "dice.fill")
                                            .font(.title2)
                                            .foregroundColor(Color.theme.accentSecondary)
                                        Spacer()
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        Text("new_mask".localized)
                                            .font(.headline)
                                            .foregroundColor(Color.theme.textPrimary)
                                        Text("randomize_identity".localized)
                                            .font(.caption)
                                            .foregroundColor(Color.theme.textSecondary)
                                    }
                                }
                                .padding()
                                
                                Button(action: { activeTooltip = "new_mask_tooltip" }) {
                                    Image(systemName: "info.circle")
                                        .font(.body)
                                        .foregroundColor(Color.theme.textSecondary)
                                        .padding(8)
                                }
                                .padding([.bottom, .trailing], 8)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.theme.bgLayer1)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.theme.borderPrimary, lineWidth: 1)
                            )
                        }
                        
                        // Cell 4: Retention (Cycle)
                        Button(action: {
                            var settings = viewModel.currentUser?.settings ?? UserSettings(bleVisible: true, pushEnabled: true, messageRetention: 24, roomExitCondition: "24h", maskId: true)
                            let current = settings.messageRetention ?? 24
                            let next = current == 6 ? 12 : (current == 12 ? 24 : 6)
                            settings.messageRetention = next
                            viewModel.updateSettings(settings)
                        }) {
                            ZStack(alignment: .bottomTrailing) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "hourglass")
                                            .font(.title2)
                                            .foregroundColor(.orange)
                                        Spacer()
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        Text("retention".localized)
                                            .font(.headline)
                                            .foregroundColor(Color.theme.textPrimary)
                                        Text("\(viewModel.currentUser?.settings?.messageRetention ?? 24) " + "hours".localized)
                                            .font(.caption)
                                            .foregroundColor(Color.theme.textSecondary)
                                    }
                                }
                                .padding()
                                
                                Button(action: { activeTooltip = "retention_tooltip" }) {
                                    Image(systemName: "info.circle")
                                        .font(.body)
                                        .foregroundColor(Color.theme.textSecondary)
                                        .padding(8)
                                }
                                .padding([.bottom, .trailing], 8)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.theme.bgLayer1)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.theme.borderPrimary, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // 4. Account Actions
                    VStack(spacing: 16) {
                        Button(action: { showLogoutAlert = true }) {
                            Text("logout".localized)
                                .font(.headline)
                                .foregroundColor(Color.theme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.theme.textPrimary.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        Button(action: { showDeleteAlert = true }) {
                            Text("delete_account".localized)
                                .font(.subheadline)
                                .foregroundColor(Color.theme.signalRed.opacity(0.8))
                        }
                    }
                }
                .padding(.vertical, 18) // Reduced to 60% of 30
                .padding(.horizontal, 30)
                
                // 5. Footer Info
                VStack(spacing: 4) {
                    Text("YEO.PE v1.0.1")
                        .font(.caption2)
                        .foregroundColor(Color.theme.textSecondary.opacity(0.5))
                    Text("app_subtitle".localized)
                        .font(.caption2)
                        .foregroundColor(Color.theme.textSecondary.opacity(0.3))
                }
                .padding(.bottom, 20)
            }
            
            // Tooltip Overlay
            if let tooltip = activeTooltip {
                ZStack {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            activeTooltip = nil
                        }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .font(.title3)
                                .foregroundColor(.neonGreen)
                                .padding(.top, 2)
                            
                            Text(tooltip.localized)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(4)
                            
                            Spacer()
                            
                            Button(action: { activeTooltip = nil }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.neonGreen.opacity(0.5), lineWidth: 1)
                    )
                    .padding(40)
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .alert(isPresented: $showLogoutAlert) {
            Alert(
                title: Text("logout_confirm_title".localized),
                message: Text("logout_confirm_message".localized),
                primaryButton: .destructive(Text("logout".localized)) {
                    viewModel.logout()
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel(Text("cancel".localized))
            )
        }
        
        // Using a background element to attach the second alert to avoid conflict
        .background(
            Color.clear
                .alert(isPresented: $showDeleteAlert) {
                    Alert(
                        title: Text("delete_confirm_title".localized),
                        message: Text("delete_confirm_message".localized),
                        primaryButton: .destructive(Text("delete".localized)) {
                            viewModel.deleteAccount()
                            presentationMode.wrappedValue.dismiss()
                        },
                        secondaryButton: .cancel(Text("cancel".localized))
                    )
                }
        )
        .onAppear {
            viewModel.fetchProfile()
        }
    }
}



// Helper Binding Extension
extension Binding where Value == Bool {
    var wrappedValueBinding: Binding<Bool> {
        self
    }
}

// Helper Component: Control Cell
struct ControlCell: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var onInfoTap: () -> Void
    
    var body: some View {
        Button(action: { isOn.toggle() }) {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(isOn ? Color.theme.accentPrimary : Color.theme.textSecondary)
                        
                        Spacer()
                        
                        Toggle("", isOn: $isOn)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: Color.theme.accentPrimary))
                    }
                    
                    VStack(alignment: .leading) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(Color.theme.textPrimary)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(Color.theme.textSecondary)
                    }
                }
                .padding()
                
                Button(action: onInfoTap) {
                    Image(systemName: "info.circle")
                        .font(.body)
                        .foregroundColor(Color.theme.textSecondary)
                        .padding(8) // increase tap area
                }
                .padding([.bottom, .trailing], 8)
            }
            .background(Color.theme.bgLayer1)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isOn ? Color.theme.accentPrimary.opacity(0.3) : Color.theme.borderPrimary, lineWidth: 1)
            )
        }
    }
}

// Helper Extension for Hex Color
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
