import SwiftUI

struct RadarPulseView: View {
    @State private var isPulsing = false
    @State private var zoomLevel: CGFloat = 1.0
    @State private var lastZoomLevel: CGFloat = 1.0
    @Environment(\.scenePhase) var scenePhase
    
    var nearbyUsers: [User] = []
    var nearbyRooms: [Room] = []
    var activeChatUserIds: Set<String> = [] // Add this parameter
    var onUserTap: ((User) -> Void)?
    var onRoomTap: ((Room) -> Void)?
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                // Background for gesture
                Color.black.opacity(0.001)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastZoomLevel
                                lastZoomLevel = value
                                zoomLevel = min(max(zoomLevel * delta, 0.5), 3.0)
                            }
                            .onEnded { _ in
                                lastZoomLevel = 1.0
                            }
                    )
                
                // Core
                Circle()
                    .fill(Color.neonGreen)
                    .frame(width: 20, height: 20)
                    .position(center)
                    .shadow(color: .neonGreen, radius: 10)
                
                // Pulse 1
                Circle()
                    .stroke(Color.neonGreen.opacity(0.5), lineWidth: 1)
                    .frame(width: (isPulsing ? 300 : 20) * zoomLevel, height: (isPulsing ? 300 : 20) * zoomLevel)
                    .position(center)
                    .opacity(isPulsing ? 0 : 1)
                    .animation(isPulsing ? Animation.easeOut(duration: 3).repeatForever(autoreverses: false) : .default, value: isPulsing)
                
                // Pulse 2
                Circle()
                    .stroke(Color.neonGreen.opacity(0.3), lineWidth: 1)
                    .frame(width: (isPulsing ? 300 : 20) * zoomLevel, height: (isPulsing ? 300 : 20) * zoomLevel)
                    .position(center)
                    .opacity(isPulsing ? 0 : 1)
                    .animation(isPulsing ? Animation.easeOut(duration: 3).repeatForever(autoreverses: false).delay(1) : .default, value: isPulsing)
                
                // Pulse 3
                Circle()
                    .stroke(Color.neonGreen.opacity(0.1), lineWidth: 1)
                    .frame(width: (isPulsing ? 300 : 20) * zoomLevel, height: (isPulsing ? 300 : 20) * zoomLevel)
                    .position(center)
                    .opacity(isPulsing ? 0 : 1)
                    .animation(isPulsing ? Animation.easeOut(duration: 3).repeatForever(autoreverses: false).delay(2) : .default, value: isPulsing)
                
                // Users
                ForEach(nearbyUsers) { user in
                    RadarUserNode(user: user, zoomLevel: zoomLevel, center: center, isChatting: activeChatUserIds.contains(user.id))
                        .onTapGesture {
                            onUserTap?(user)
                        }
                        .transition(.opacity.animation(.easeInOut))
                }
                
                // Rooms
                ForEach(nearbyRooms) { room in
                    RadarRoomNode(room: room, zoomLevel: zoomLevel, center: center)
                        .onTapGesture {
                            onRoomTap?(room)
                        }
                        .transition(.opacity.animation(.easeInOut))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
                isPulsing = true
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    isPulsing = true
                } else {
                    isPulsing = false
                }
            }
        }
    }
}

struct RadarUserNode: View {
    let user: User
    var zoomLevel: CGFloat
    var center: CGPoint
    var isChatting: Bool // Add property
    
    @State private var baseAngle: Double = 0.0
    @State private var baseDistance: CGFloat = 0.0
    
    var body: some View {
        VStack(spacing: 4) {
            // Avatar
            Circle()
                .fill(isChatting ? Color.lightBlue : Color.mysteryViolet)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String((user.nickname ?? user.nicknameMask ?? "?").prefix(1)))
                        .font(.radarBody)
                        .foregroundColor(.white)
                )
                .shadow(color: .mysteryViolet.opacity(0.5), radius: 5)
            
            // Name Label
            Text(user.nicknameMask ?? user.nickname ?? "Unknown")
                .font(.radarCaption)
                .foregroundColor(.white)
                .padding(4)
                .background(Color.black.opacity(0.5))
                .cornerRadius(4)
        }
        .position(
            x: cos(baseAngle) * baseDistance * zoomLevel + center.x,
            y: sin(baseAngle) * baseDistance * zoomLevel + center.y
        )
        .onAppear {
            if baseDistance == 0 { // Initialize only once
                baseAngle = Double.random(in: 0...(2 * .pi))
                baseDistance = CGFloat.random(in: 50...150)
            }
        }
    }
}

struct RadarRoomNode: View {
    let room: Room
    var zoomLevel: CGFloat
    var center: CGPoint
    
    @State private var baseAngle: Double = 0.0
    @State private var baseDistance: CGFloat = 0.0
    
    var body: some View {
        VStack(spacing: 4) {
            // Hexagon-like shape (using RoundedRectangle for simplicity or custom shape)
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.signalRed, lineWidth: 2)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black))
                .overlay(
                    Image(systemName: "bubble.left.fill")
                        .font(.caption)
                        .foregroundColor(.signalRed)
                )
            
            Text(room.name)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.signalRed)
        }
        .position(
            x: cos(baseAngle) * baseDistance * zoomLevel + center.x,
            y: sin(baseAngle) * baseDistance * zoomLevel + center.y
        )
        .onAppear {
            if baseDistance == 0 { // Initialize only once
                baseAngle = Double.random(in: 0...(2 * .pi))
                baseDistance = CGFloat.random(in: 50...150)
            }
        }
    }
}
