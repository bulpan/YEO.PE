import SwiftUI

struct NeonButton: View {
    let title: String
    let action: () -> Void
    var color: Color = .neonGreen
    var textColor: Color? = nil // Optional to allow adaptive default
    
    private var effectiveTextColor: Color {
        if let textColor = textColor { return textColor }
        // If background is neonGreen (accentPrimary), use high contrast text
        if color == .neonGreen {
            return ThemeManager.shared.isDarkMode ? .black : .white
        }
        return Color.theme.textPrimary
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.radarBody)
                .fontWeight(.bold)
                .foregroundColor(effectiveTextColor)
                .padding()
                .frame(maxWidth: .infinity)
                .background(color)
                .cornerRadius(12)
                .shadow(color: color.opacity(0.3), radius: 6, x: 0, y: 0)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.theme.borderPrimary, lineWidth: 1)
                )
        }
    }
}
