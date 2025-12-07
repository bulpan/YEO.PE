import SwiftUI
import Combine

struct MainView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var roomViewModel = RoomListViewModel()
    @ObservedObject private var bleManager = BLEManager.shared
    
    @State private var showConnectionAlert = false
    @State private var showChatAlert = false
    @State private var showLoginSheet = false
    @State private var showProfileSheet = false
    @State private var showSettingsSheet = false
    @State private var selectedDeviceFilter: BLEManager.DeviceType? = nil // nil = All
    @State private var matchedUser = "User #1234"
    @State private var selectedTargetUser: User?
    @State private var selectedRoom: Room?
    @State private var showRoomListSheet = false
    @State private var isBoosting = false
    @State private var showQuickQuestionInput = false
    @State private var quickQuestionText = ""
    @State private var showNotificationBanner = false
    @State private var notificationMessage = ""
    
    var totalUnreadCount: Int {
        roomViewModel.myRooms.reduce(0) { $0 + ($1.unreadCount ?? 0) }
    }
    
    // ... (body)

    private func sendQuickQuestion() {
        guard authViewModel.isLoggedIn else { return }
        
        withAnimation {
            showQuickQuestionInput = false
            isBoosting = true
        }
        
        let visibleUIDs = bleManager.discoveredUsers.compactMap { $0.uid }
        APIService.shared.sendQuickQuestion(uids: visibleUIDs, content: quickQuestionText) { result in
            DispatchQueue.main.async {
                isBoosting = false
                quickQuestionText = "" // Reset text
                
                switch result {
                case .success(let response):
                    let count = response.sentCount ?? 0
                    APIService.shared.debugMessageSubject.send("✅ Sent question to \(count) users!")
                case .failure(let error):
                    APIService.shared.debugMessageSubject.send("❌ Failed to send: \(error.localizedDescription)")
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.deepBlack.edgesIgnoringSafeArea(.all)
            
            // Notification Banner
            if showNotificationBanner {
                VStack {
                    HStack {
                        Image(systemName: "message.fill")
                            .foregroundColor(.neonGreen)
                        Text(notificationMessage)
                            .font(.radarBody)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding()
                    .background(Color.glassBlack)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.neonGreen.opacity(0.5), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .padding(.top, 50) // Adjust for safe area
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                    .onTapGesture {
                        withAnimation { showNotificationBanner = false }
                        // Optional: Navigate to room if we had roomId stored
                        showRoomListSheet = true
                    }
                    Spacer()
                }
                .zIndex(100)
            }
            
            // Radar Animation
            RadarPulseView(
                nearbyUsers: bleManager.discoveredUsers,
                nearbyRooms: filteredNearbyRooms,
                activeChatUserIds: activeChatUserIds, // Pass computed set
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
            
            // Hidden Navigation Link for Radar interactions
            NavigationLink(
                destination: selectedRoom != nil ? ChatView(room: selectedRoom!, targetUser: selectedTargetUser, currentUser: authViewModel.currentUser) : nil,
                isActive: Binding(
                    get: { selectedRoom != nil },
                    set: { isPresenting in
                        if !isPresenting {
                            // Chat View Dismissed
                            if let roomId = selectedRoom?.id {
                                print("🚪 ChatView dismissed for \(roomId), marking as read locally")
                                roomViewModel.markAsRead(roomId: roomId)
                                // Also fetch fresh data to ensure server sync
                                roomViewModel.fetchMyRooms()
                            }
                            selectedRoom = nil
                        }
                    }
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
                    
                    // Debug Toggle
                    Toggle("Debug", isOn: $bleManager.isRawScanMode)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: .neonGreen))
                        .scaleEffect(0.8)
                    
                    Spacer()
                    
                    Button(action: {
                        showSettingsSheet = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 24)) // Increased size
                            .foregroundColor(.neonGreen) // Brighter color
                            .padding(12) // Larger hit area
                            .background(Color.white.opacity(0.05)) // Subtle background for feedback
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                if bleManager.isRawScanMode {
                    VStack {
                        // Filter Picker
                        Picker("Filter", selection: $selectedDeviceFilter) {
                            Text("All").tag(BLEManager.DeviceType?.none)
                            Text("iOS").tag(BLEManager.DeviceType?.some(.ios))
                            Text("Android").tag(BLEManager.DeviceType?.some(.android))
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                        
                        RawRadarView(peripherals: bleManager.rawPeripherals, filter: selectedDeviceFilter)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false) // Let touches pass through to main radar if needed
                    }
                }
                
                Spacer()
                
                // Bottom Bar
                HStack {
                    Button(action: {
                        showRoomListSheet = true
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 20))
                            Text("chat".localized)
                                .font(.radarCaption)
                        }
                        .foregroundColor(.textPrimary)
                        .overlay(
                            ZStack {
                                if totalUnreadCount > 0 {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 10, height: 10)
                                        .offset(x: 10, y: -10)
                                }
                            }
                        )
                    }
                    
                    Spacer()
                    
                    // Signal Boost Button (Central) -> Quick Question
                    Button(action: {
                        guard authViewModel.isLoggedIn else {
                            showLoginSheet = true
                            return
                        }
                        
                        withAnimation { showQuickQuestionInput = true }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.neonGreen.opacity(0.1))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 24))
                                .foregroundColor(.neonGreen)
                        }
                    }
                    .shadow(color: .neonGreen.opacity(0.4), radius: 10)
                    
                    Spacer()
                    
                    Button(action: {
                        if authViewModel.isLoggedIn {
                            showProfileSheet = true
                        } else {
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
            
            // Quick Question Input Overlay
            if showQuickQuestionInput {
                ZStack {
                    Color.black.opacity(0.7).edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            withAnimation { showQuickQuestionInput = false }
                        }
                    
                    VStack(spacing: 16) {
                        Text("Quick Question") // Simple English title
                            .font(.headline)
                            .foregroundColor(.neonGreen)
                        
                        Text("quick_question_desc".localized)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                        
                        ZStack(alignment: .topLeading) {
                            if quickQuestionText.isEmpty {
                                Text("quick_question_placeholder".localized)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 12)
                            }
                            
                            TextEditor(text: $quickQuestionText)
                                .frame(height: 80)
                                .padding(4)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.neonGreen.opacity(0.5), lineWidth: 1)
                                )
                        }
                        
                        HStack(spacing: 15) {
                            Button(action: {
                                withAnimation { showQuickQuestionInput = false }
                            }) {
                                Text("cancel".localized)
                                    .font(.subheadline)
                                    .foregroundColor(.textSecondary)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(10)
                            }
                            
                            Button(action: {
                                sendQuickQuestion()
                            }) {
                                Text("send".localized)
                                    .font(.subheadline)
                                    .foregroundColor(.black)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.neonGreen)
                                    .cornerRadius(10)
                            }
                            .disabled(quickQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(quickQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                        }
                    }
                    .padding(24)
                    .background(Color.deepBlack)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.neonGreen, lineWidth: 2)
                    )
                    .padding(.horizontal, 20) // Wider
                }
                .transition(.scale)
                .zIndex(2)
            }
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginView(viewModel: authViewModel)
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileView(viewModel: authViewModel)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView(authViewModel: authViewModel)
        }
        .sheet(isPresented: $showRoomListSheet) {
            NavigationView {
                RoomListView()
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            roomViewModel.fetchNearbyRooms()
            roomViewModel.fetchMyRooms() // Fetch my rooms for unread count
            bleManager.start()
            
            // Listen for new messages for global notifications & unread count
            SocketManager.shared.on("new-message") { data, ack in
                guard let messageData = data.first as? [String: Any],
                      let roomId = messageData["roomId"] as? String,
                      let content = messageData["content"] as? String,
                      let nickname = messageData["nickname"] as? String ?? messageData["nicknameMask"] as? String else { return }
                
                // If we are NOT in this room, show notification and refresh list
                if self.selectedRoom?.uniqueId != roomId {
                    // 1. Optimistic Update: Increment badge immediately
                    self.roomViewModel.incrementUnreadCount(roomId: roomId)
                    
                    // 2. Refresh from server (keep this for consistency)
                    self.roomViewModel.fetchMyRooms()
                    
                    // Show Banner
                    DispatchQueue.main.async {
                        let bannerMessage = "\(nickname): \(content)"
                        APIService.shared.debugMessageSubject.send(bannerMessage) // Re-using debug toast for now as requested "Top Notification"
                        // Or implement a specific banner state if debug toast isn't sufficient.
                        // User asked for "Top Notification". Debug toast is at bottom.
                        // Let's use a separate top banner.
                        self.notificationMessage = bannerMessage
                        withAnimation {
                            self.showNotificationBanner = true
                        }
                        
                        // Hide after 3s
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                self.showNotificationBanner = false
                            }
                        }
                    }
                }
            }
        }
        .onDisappear {
            bleManager.stop()
        }
        .onReceive(NavigationManager.shared.$selectedRoomId) { roomId in
            guard let roomId = roomId else { return }
            print("🔗 MainView received deep link to room: \(roomId)")
            
            // Fetch room details and navigate
            roomViewModel.fetchRoom(id: roomId) { room in
                if let room = room {
                    self.selectedRoom = room
                    // Reset ID after navigation handled (optional, depending on behavior)
                    // NavigationManager.shared.selectedRoomId = nil 
                }
            }
        }
        .navigationBarTitle("")
        .navigationBarHidden(true)
    }
    
    private var activeChatUserIds: Set<String> {
        guard let currentUserId = authViewModel.currentUser?.id else { return [] }
        var ids = Set<String>()
        for room in roomViewModel.myRooms {
            // Check for valid 1:1 rooms (Active)
            // Note: User might want inactive (pending check)? "Already chatting" -> Active.
            if room.isActive == true {
                if let inviteeId = room.metadata?.inviteeId {
                     if room.creatorId == currentUserId {
                         ids.insert(inviteeId)
                     } else if inviteeId == currentUserId, let creatorId = room.creatorId {
                         ids.insert(creatorId)
                     }
                }
            }
        }
        return ids
    }

    private var filteredNearbyRooms: [Room] {
        let rooms: [Room] = roomViewModel.nearbyRooms
        // Set of room IDs that I have joined
        let myJoinedRoomIds = Set(roomViewModel.myRooms.map { $0.id })
        
        return rooms.filter { (room: Room) -> Bool in
            // 1. Exclude rooms I have already joined (they are in 'Chat' tab)
            if myJoinedRoomIds.contains(room.id) {
                return false
            }
            
            // 2. Show only if creator is nearby (Signal logic)
            let isCreatorNearby = bleManager.discoveredUsers.contains { user in
                user.id == room.creatorId
            }
            return isCreatorNearby
        }
    }
}
