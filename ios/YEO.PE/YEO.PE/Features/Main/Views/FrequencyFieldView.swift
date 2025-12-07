import SwiftUI

struct FrequencyFieldView: View {
    @ObservedObject var bleManager = BLEManager.shared
    
    var body: some View {
        ZStack {
            // 1. Background Grid
            GridBackground()
            
            // 2. Pulse Animation (when scanning)
            if bleManager.isScanning {
                PulseLayer()
            }
            
            // 3. Center Node (Me)
            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)
                .shadow(color: .white.opacity(0.5), radius: 10, x: 0, y: 0)
            
            // 4. Nearby Users
            ForEach(bleManager.discoveredUsers) { user in
                UserNode(user: user)
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .onAppear {
            bleManager.start()
        }
        .onDisappear {
            bleManager.stop()
        }
    }
}

struct GridBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let spacing: CGFloat = 40
                
                // Vertical lines
                for x in stride(from: 0, to: width, by: spacing) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
                
                // Horizontal lines
                for y in stride(from: 0, to: height, by: spacing) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        }
    }
}

struct PulseLayer: View {
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 1.0
    
    var body: some View {
        Circle()
            .stroke(Color.green, lineWidth: 1)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(Animation.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                    self.scale = 2.0
                    self.opacity = 0.0
                }
            }
    }
}

struct UserNode: View {
    let user: User
    @State private var position: CGPoint = .zero
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .stroke(Color.green, lineWidth: 2)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.black))
                .overlay(
                    Text(String((user.nickname ?? user.nicknameMask ?? "?").prefix(1)))
                        .font(.caption)
                        .foregroundColor(.green)
                )
            
            Text(user.nicknameMask ?? user.nickname ?? "Unknown")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.green)
        }
        .position(position)
        .onAppear {
            // Random position for now (since we don't have angle)
            // In real app, persist this angle for the same user
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = CGFloat((user.distance ?? 10) * 10) // Scale distance
            // Clamp distance to screen bounds roughly
            let clampedDistance = min(max(distance, 50), 150)
            
            let x = cos(angle) * clampedDistance + UIScreen.main.bounds.width / 2
            let y = sin(angle) * clampedDistance + UIScreen.main.bounds.height / 2
            
            self.position = CGPoint(x: x, y: y)
        }
    }
}
