import SwiftUI

struct RadarPulseView: View {
    @State private var isPulsing = false
    @State private var zoomLevel: CGFloat = 1.0
    @State private var lastZoomLevel: CGFloat = 1.0
    @Environment(\.scenePhase) var scenePhase
    
    var nearbyUsers: [User] = []
    var nearbyRooms: [Room] = []
    var activeChatUserIds: Set<String> = []
    var highlightedUserId: String? // Add this property
    var onUserTap: ((User) -> Void)?
    var onUserLongPress: ((User) -> Void)?
    var onRoomTap: ((Room) -> Void)?
    
    var body: some View {
        ZStack {
            // Background for gesture
            Color.black.opacity(0.001)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            
            // Core Pulse Center
            Circle()
                .fill(Color.neonGreen)
                .frame(width: 20, height: 20)
                .shadow(color: .neonGreen, radius: 10)
            
            // Pulse 1
            Circle()
                .stroke(Color.neonGreen.opacity(0.5), lineWidth: 1)
                .frame(width: (isPulsing ? 300 : 20) * zoomLevel, height: (isPulsing ? 300 : 20) * zoomLevel)
                .opacity(isPulsing ? 0 : 1)
                .animation(isPulsing ? Animation.easeOut(duration: 3).repeatForever(autoreverses: false) : .default, value: isPulsing)
            
            // Pulse 2
            Circle()
                .stroke(Color.neonGreen.opacity(0.3), lineWidth: 1)
                .frame(width: (isPulsing ? 300 : 20) * zoomLevel, height: (isPulsing ? 300 : 20) * zoomLevel)
                .opacity(isPulsing ? 0 : 1)
                .animation(isPulsing ? Animation.easeOut(duration: 3).repeatForever(autoreverses: false).delay(1) : .default, value: isPulsing)
            
            // Pulse 3
            Circle()
                .stroke(Color.neonGreen.opacity(0.1), lineWidth: 1)
                .frame(width: (isPulsing ? 300 : 20) * zoomLevel, height: (isPulsing ? 300 : 20) * zoomLevel)
                .opacity(isPulsing ? 0 : 1)
                .animation(isPulsing ? Animation.easeOut(duration: 3).repeatForever(autoreverses: false).delay(2) : .default, value: isPulsing)
            
            // Users
            ForEach(nearbyUsers) { user in
                RadarUserNode(
                    user: user, 
                    zoomLevel: zoomLevel, 
                    isChatting: activeChatUserIds.contains(user.id),
                    isHighlighted: user.id == highlightedUserId // Pass highlight state
                )
                .onTapGesture {
                    HapticManager.shared.medium()
                    onUserTap?(user)
                }
                .onLongPressGesture {
                    HapticManager.shared.heavy()
                    onUserLongPress?(user)
                }
                .transition(.opacity.animation(.easeInOut))
            }
            
            // Rooms
            ForEach(nearbyRooms) { room in
                RadarRoomNode(room: room, zoomLevel: zoomLevel)
                    .onTapGesture {
                        onRoomTap?(room)
                    }
                    .transition(.opacity.animation(.easeInOut))
            }
        }
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

struct RadarUserNode: View {
    let user: User
    var zoomLevel: CGFloat
    var isChatting: Bool
    var isHighlighted: Bool // Add property
    
    @State private var baseAngle: Double = 0.0
    @State private var pulseScale: CGFloat = 1.0 // For highlight animation
    
    var body: some View {
        let distanceInMeters = user.distance ?? 15.0
        let maxRadius: CGFloat = 160.0
        let minRadius: CGFloat = 40.0
        let maxDistance: Double = 30.0
        
        let normalized = CGFloat(min(max(distanceInMeters, 0), maxDistance) / maxDistance)
        let radius = minRadius + (normalized * (maxRadius - minRadius))
        
        VStack(spacing: 4) {
            // Logic for Display Name
            let displayName = user.displayName
            
            // Avatar
            Circle()
                .fill(isChatting ? Color.lightBlue : Color.mysteryViolet)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(displayName.prefix(1)))
                        .font(.radarBody)
                        .foregroundColor(.white)
                )
                .shadow(color: .mysteryViolet.opacity(0.5), radius: 5)
            
            // Name Label
            Text(displayName)
                .font(.radarCaption)
                .foregroundColor(.white)
                .padding(4)
                .background(Color.black.opacity(0.5))
                .cornerRadius(4)
        }
        .padding(isHighlighted ? 10 : 0) // Add padding for highlight border/glow
        .background(
            isHighlighted ? 
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .shadow(color: .white, radius: 10)
                .scaleEffect(pulseScale)
                .opacity(pulseScale > 1.2 ? 0 : 1)
            : nil
        )
        .offset(
            x: cos(baseAngle) * radius * zoomLevel,
            y: sin(baseAngle) * radius * zoomLevel
        )
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: user.distance)
        .onAppear {
            baseAngle = Double.random(in: 0...(2 * .pi))
            
            if isHighlighted {
                withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseScale = 1.3
                }
            }
        }
        .onChange(of: isHighlighted) { highlighted in
            if highlighted {
                withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseScale = 1.3
                }
            } else {
                withAnimation { pulseScale = 1.0 }
            }
        }
    }
}

struct RadarRoomNode: View {
    let room: Room
    var zoomLevel: CGFloat
    
    @State private var baseAngle: Double = 0.0
    @State private var baseDistance: CGFloat = 0.0
    
    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.signalRed, lineWidth: 2)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black))
                .overlay(
                    Image(systemName: room.metadata?.category == "quick_question" ? "bolt.fill" : "bubble.left.fill")
                        .font(.caption)
                        .foregroundColor(room.metadata?.category == "quick_question" ? .yellow : .signalRed)
                )
            
            Text(room.name)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(room.metadata?.category == "quick_question" ? .yellow : (ThemeManager.shared.isDarkMode ? .signalRed : .black))
        }
        .offset(
            x: cos(baseAngle) * baseDistance * zoomLevel,
            y: sin(baseAngle) * baseDistance * zoomLevel
        )
        .onAppear {
            if baseDistance == 0 {
                baseAngle = Double.random(in: 0...(2 * .pi))
                baseDistance = CGFloat.random(in: 50...150)
            }
        }
    }
}
