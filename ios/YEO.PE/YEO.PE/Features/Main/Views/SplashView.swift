import SwiftUI

struct SplashView: View {
    @State private var isActive = false
    @State private var opacity = 0.0
    @State private var scale = 0.8
    
    var body: some View {
        if isActive {
            EmptyView() // Transitions to main content handled by parent, but this view disappears
        } else {
            ZStack {
                Color.theme.bgMain.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    // Logo Text
                    Text("YEO.PE")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundColor(Color.theme.accentPrimary)
                        .shadow(color: Color.theme.accentPrimary.opacity(0.5), radius: 10, x: 0, y: 0)
                    
                    // Subtitle
                    Text("app_subtitle".localized) // "Anonymous & Ephemeral"
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.theme.textSecondary)
                        .tracking(2)
                    
                    // Radar Pulse Effect (Simple Circle)
                    Circle()
                        .stroke(Color.theme.accentPrimary, lineWidth: 2)
                        .frame(width: 100, height: 100)
                        .scaleEffect(scale)
                        .opacity(2 - scale) // Fades as it grows
                        .animation(
                            Animation.easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: scale
                        )
                }
                .opacity(opacity)
                .onAppear {
                    // 1. Fade In
                    withAnimation(.easeIn(duration: 0.5)) {
                        self.opacity = 1.0
                    }
                    // 2. Start Pulse
                    self.scale = 2.0
                    
                    // 3. Exit after timer
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation {
                            self.isActive = true
                        }
                    }
                }
            }
        }
    }
}
