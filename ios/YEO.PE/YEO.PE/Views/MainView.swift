import SwiftUI

struct MainView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var roomViewModel = RoomListViewModel()
    @ObservedObject private var bleManager = BLEManager.shared
    
    @State private var showConnectionAlert = false
    @State private var showChatAlert = false
    @State private var showLoginSheet = false
    @State private var showProfileSheet = false
    @State private var showSettingsSheet = false
    @State private var matchedUser = "User #1234"
    @State private var selectedTargetUser: User?
    @State private var selectedRoom: Room?

    var body: some View {
        ZStack {
            // Background
            Color.deepBlack.edgesIgnoringSafeArea(.all)
            
            // Radar Animation
            RadarPulseView(
                nearbyUsers: bleManager.discoveredUsers,
                nearbyRooms: roomViewModel.nearbyRooms,
                onUserTap: { user in
                    if authViewModel.isLoggedIn {
                        selectedTargetUser = user
                        withAnimation {
                            showChatAlert = true
                        }
                    } else {
                        showLoginSheet = true
                    }
                },
                onRoomTap: { room in
                    if authViewModel.isLoggedIn {
                        self.selectedRoom = room
                    } else {
                        showLoginSheet = true
                    }
                }
            )
            // .padding(.bottom, 80) // Removed to center radar on screen
            
            // Hidden Navigation Link for Radar interactions
            NavigationLink(
                destination: selectedRoom != nil ? ChatView(room: selectedRoom!, targetUser: selectedTargetUser) : nil,
                isActive: Binding(
                    get: { selectedRoom != nil },
                    set: { if !$0 { selectedRoom = nil } }
                )
            ) { EmptyView() }
            
            // Overlay Controls
            VStack {
                // Top Bar
                HStack {
                    Text("signal_active".localized)
                        .font(.radarData)
                        .foregroundColor(.neonGreen)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.neonGreen.opacity(0.1))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.neonGreen.opacity(0.3), lineWidth: 1)
                        )
                    
                    Spacer()
                    
                    Button(action: {
                        showSettingsSheet = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.textSecondary)
                    }
                }
                .padding()
                
                Spacer()
                
                // Bottom Bar
                HStack {
                    NavigationLink(destination: RoomListView()) {
                        VStack(spacing: 4) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 20))
                            Text("chat".localized)
                                .font(.radarCaption)
                        }
                        .foregroundColor(.textPrimary)
                    }
                    
                    Spacer()
                    
                    // Scan Trigger (Central) - Simulates Match
                    Button(action: {
                        withAnimation {
                            showConnectionAlert = true
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.neonGreen.opacity(0.1))
                                .frame(width: 60, height: 60) // Slightly smaller to match alignment
                            
                            Circle()
                                .stroke(Color.neonGreen, lineWidth: 2)
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 24))
                                .foregroundColor(.neonGreen)
                        }
                    }
                    // Removed .offset(y: -20)
                    .shadow(color: .neonGreen.opacity(0.4), radius: 10)
                    
                    Spacer()
                    
                    Button(action: {
                        if authViewModel.isLoggedIn {
                            showProfileSheet = true
                        } else {
                            showConnectionAlert = false // Ensure alert is closed
                            showLoginSheet = true
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: authViewModel.isLoggedIn ? "person.fill" : "person.crop.circle.badge.questionmark")
                                .font(.system(size: 20))
                            Text(authViewModel.isLoggedIn ? "profile".localized : "login".localized)
                                .font(.radarCaption)
                        }
                        .foregroundColor(.textSecondary)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 20)
                .glassmorphism(cornerRadius: 30)
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            
            // Connection Alert Overlay (Match)
            if showConnectionAlert {
                ConnectionAlertView(
                    matchedUser: matchedUser,
                    title: "signal_matched".localized,
                    message: "signal_matched_message".localized,
                    confirmText: "connect".localized,
                    onAccept: {
                        withAnimation { showConnectionAlert = false }
                        // Navigate to chat or perform action
                    },
                    onIgnore: {
                        withAnimation { showConnectionAlert = false }
                    }
                )
                .transition(.opacity)
                .zIndex(1)
            }
            
            // Chat Request Alert Overlay
            if showChatAlert, let targetUser = selectedTargetUser {
                ConnectionAlertView(
                    matchedUser: targetUser.nicknameMask ?? targetUser.nickname ?? "Unknown",
                    title: "start_chat_title".localized,
                    message: "start_chat_message".localized,
                    confirmText: "start".localized,
                    onAccept: {
                        // Close alert immediately
                        withAnimation { showChatAlert = false }
                        
                        // Create room and navigate
                        roomViewModel.createOneOnOneRoom(with: targetUser) { room in
                            if let room = room {
                                DispatchQueue.main.async {
                                    self.selectedRoom = room
                                }
                            }
                        }
                    },
                    onIgnore: {
                        withAnimation { showChatAlert = false }
                        selectedTargetUser = nil
                    }
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginView(viewModel: authViewModel)
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileView(viewModel: authViewModel)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
        }
        .onAppear {
            roomViewModel.fetchNearbyRooms()
            bleManager.start()
        }
        .onDisappear {
            bleManager.stop()
        }
    }
}
