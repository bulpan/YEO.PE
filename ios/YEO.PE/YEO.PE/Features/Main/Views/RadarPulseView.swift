import SwiftUI

struct RadarPulseView: View {

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
                            zoomLevel = min(max(zoomLevel * delta, 0.5), 2.0) // Max zoom: 2x
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
            
            // Pulse Animation (TimelineView)
            TimelineView(.animation) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                
                ForEach(0..<3) { index in
                    let duration: Double = 3.3
                    let offset = Double(index)
                    // Calculate progress 0.0 to 1.0 based on current time
                    let progress = (time + offset).truncatingRemainder(dividingBy: duration) / duration
                    
                    Circle()
                        .stroke(Color.neonGreen.opacity(0.5 * (1.0 - progress)), lineWidth: 0.5)
                        .frame(width: 20 + (480 * progress), height: 20 + (480 * progress))
                }
            }
            
            // Users
            ForEach(nearbyUsers) { user in
                RadarUserNode(
                    user: user, 
                    zoomLevel: zoomLevel, 
                    isChatting: activeChatUserIds.contains(user.id),
                    isHighlighted: user.id == highlightedUserId // Pass highlight state
                )
                .onTapGesture {
                    // Guest Interaction Logic
                    if user.isGuest {
                         HapticManager.shared.error() // Feedback that it's disabled
                         // Optional: Show toast? For now just silent fail as requested "touch disabled"
                         return
                    }
                    
                    HapticManager.shared.medium()
                    onUserTap?(user)
                }
                .onLongPressGesture {
                    if user.isGuest { return }
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
    }
}

struct RadarUserNode: View {
    let user: User
    var zoomLevel: CGFloat
    var isChatting: Bool
    var isHighlighted: Bool
    
    @State private var baseAngle: Double = 0.0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        let distanceInMeters = user.distance ?? 20.0
        let maxRadius: CGFloat = 180.0
        let minRadius: CGFloat = 50.0
        let maxDistance: Double = 60.0
        
        let normalized = CGFloat(min(max(distanceInMeters, 0), maxDistance) / maxDistance)
        let radius = minRadius + (normalized * (maxRadius - minRadius))
        
        VStack(spacing: 8) {
            // 1. User Bubble (Avatar)
            ZStack {
                if let url = user.fullProfileFileURL {
                    CachedAsyncImage(url: url)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    PlaceholderAvatar(isGuest: user.isGuest, isDarkMode: ThemeManager.shared.isDarkMode)
                }
            }
            .frame(width: 50, height: 50)
            .background(ThemeManager.shared.isDarkMode ? Color.black : Color.white)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        isChatting ? Color.neonGreen : (user.isGuest ? Color.gray : Color.theme.iconBorder),
                        lineWidth: isChatting ? 3 : 1
                    )
            )
            .shadow(color: isChatting ? .neonGreen.opacity(0.5) : Color.black.opacity(0.2), radius: 5)
            .scaleEffect(pulseScale)
            
            // 2. Nickname Label
            Text(user.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ThemeManager.shared.isDarkMode ? .white : .black)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(ThemeManager.shared.isDarkMode ? Color.black.opacity(0.4) : Color.white.opacity(0.6))
                .cornerRadius(4)
                .shadow(radius: 1)
        }
        .offset(
            x: cos(baseAngle) * radius * zoomLevel,
            y: sin(baseAngle) * radius * zoomLevel
        )
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: user.distance)
        .onAppear {
            // Only randomize if not already set (stability check)
            if baseAngle == 0.0 {
                baseAngle = Double.random(in: 0...(2 * .pi))
            }
            
            if isHighlighted || isChatting {
                withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulseScale = 1.1
                }
            }
        }
    }
}

struct PlaceholderAvatar: View {
    let isGuest: Bool
    let isDarkMode: Bool
    
    var body: some View {
        ZStack {
            if isGuest {
                Image(systemName: "person.fill")
                    .resizable().padding(12)
                    .foregroundColor(.gray)
            } else {
                Image(systemName: "person.fill")
                    .resizable().padding(12)
                    .foregroundColor(isDarkMode ? .white : .gray)
            }
        }
        .frame(width: 50, height: 50)
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
