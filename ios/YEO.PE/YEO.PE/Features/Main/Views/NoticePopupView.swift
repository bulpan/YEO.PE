import SwiftUI

struct NoticePopupView: View {
    let content: LocalizedContent
    let version: Int
    let onClose: () -> Void
    
    @AppStorage("lastSeenNoticeVersion") private var lastSeenNoticeVersion = 0
    @Environment(\.locale) var locale
    
    var body: some View {
        VStack(spacing: 0) {
            // Spacer to push content to bottom
            Spacer()
            
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text("notification".localized) // Use localization key or "Notice"
                        .font(.radarHeadline)
                        .foregroundColor(Color.theme.textPrimary)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                            .foregroundColor(Color.theme.textSecondary)
                    }
                }
                .padding(.bottom, 10)
                
                // Content
                ScrollView {
                    Text(displayContent)
                        .font(.radarBody)
                        .foregroundColor(Color.theme.textPrimary)
                        .lineSpacing(4)
                }
                .frame(maxHeight: UIScreen.main.bounds.height * 0.25) // Scrollable content area
                
                // Buttons
                HStack(spacing: 12) {
                    Button(action: {
                        lastSeenNoticeVersion = version
                        onClose()
                    }) {
                        Text("dont_show_again".localized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Color.theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.theme.bgLayer2)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(ThemeManager.shared.isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.5), lineWidth: 1)
                            )
                    }
                    
                    Button(action: onClose) {
                        Text("close".localized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Color.theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.theme.bgLayer2)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(ThemeManager.shared.isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.5), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(24)
            .background(
                ThemeManager.shared.isDarkMode ? Color(white: 0.15) : Color.white
            )
            .cornerRadius(24, corners: [.topLeft, .topRight])
            .overlay(
                RoundedCorner(radius: 24, corners: [.topLeft, .topRight])
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: -5)
        }
        .edgesIgnoringSafeArea(.bottom)
        .transition(.move(edge: .bottom))
    }
    
    var displayContent: String {
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        return languageCode == "ko" ? content.ko : content.en
    }
}

// Helper for corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
