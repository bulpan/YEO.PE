import SwiftUI

struct PremiumCardModifier: ViewModifier {
    @ObservedObject var themeManager = ThemeManager.shared
    
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(themeManager.isDarkMode ? Color.theme.bgLayer2 : Color.theme.bgLayer1)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.theme.borderSubtle, lineWidth: themeManager.isDarkMode ? 0.5 : 0)
            )
            .shadow(color: Color.black.opacity(themeManager.isDarkMode ? 0.2 : 0.03), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func premiumCardStyle() -> some View {
        self.modifier(PremiumCardModifier())
    }
}
