import SwiftUI

struct GlassmorphismView: ViewModifier {
    @ObservedObject private var themeManager = ThemeManager.shared
    var cornerRadius: CGFloat = 20
    
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(Color.glassBlack)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

extension View {
    func glassmorphism(cornerRadius: CGFloat = 20) -> some View {
        self.modifier(GlassmorphismView(cornerRadius: cornerRadius))
    }
}
