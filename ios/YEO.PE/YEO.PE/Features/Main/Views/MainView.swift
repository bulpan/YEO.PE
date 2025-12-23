import SwiftUI
import Combine

struct MainView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var roomViewModel = RoomListViewModel()
    @ObservedObject private var bleManager = BLEManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var showConnectionAlert = false
    @State private var showChatAlert = false
    @State private var showLoginSheet = false
    @State private var showProfileSheet = false
    @State private var showSettingsSheet = false
    @State private var selectedDeviceFilter: BLEManager.DeviceType? = nil // nil = All
    @State private var matchedUser = "User #1234"
    @State private var selectedTargetUser: User?
    @State private var selectedRoom: Room?
    @State private var showRoomList = false
    @State private var isBoosting = false
    @State private var showQuickQuestionInput = false
    @State private var quickQuestionText = ""
    @State private var showNotificationBanner = false
    @State private var notificationMessage = ""
    @State private var highlightedUserId: String? // For finding users logic
    @State private var notificationTargetUserId: String? // Store pending target
    
    var totalUnreadCount: Int {
        roomViewModel.myRooms
            .filter { $0.isActive != false } // Only count active rooms
            .reduce(0) { $0 + ($1.unreadCount ?? 0) }
    }
    
    private func sendQuickQuestion() {
        guard authViewModel.isLoggedIn else { return }
        
        showQuickQuestionInput = false
        withAnimation {
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
                    
                    // Navigate to the created room (Quick Question Chat)
                    if let room = response.room {
                        self.selectedRoom = room
                        self.roomViewModel.markAsRead(roomId: room.id)
                        self.roomViewModel.fetchMyRooms()
                    }
                case .failure(let error):
                    APIService.shared.debugMessageSubject.send("❌ Failed to send: \(error.localizedDescription)")
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.theme.bgMain.edgesIgnoringSafeArea(.all)
            
            // Notification Banner
            if showNotificationBanner {
                VStack {
                    HStack {
                        Image(systemName: "message.fill")
                            .foregroundColor(ThemeManager.shared.isDarkMode ? .neonGreen : .white)
                        Text(notificationMessage)
                            .font(.radarBody)
                            .foregroundColor(ThemeManager.shared.isDarkMode ? .white : .white)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding()
                    .background(Color.theme.bgLayer2)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.theme.borderPrimary, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    .padding(.top, 50) // Adjust for safe area
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                    .onTapGesture {
                        withAnimation { showNotificationBanner = false }
                        
                        // Handle "User Discovered" highlight logic
                        if let targetId = notificationTargetUserId {
                             // Reset sheets
                             showProfileSheet = false
                             showSettingsSheet = false
                             showProfileSheet = false
                             showSettingsSheet = false
                             showRoomList = false
                             showLoginSheet = false
                             showLoginSheet = false
                             
                             // Highlight
                             highlightedUserId = targetId
                             
                             // Remove highlight after 5 seconds
                             DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                 if highlightedUserId == targetId {
                                     highlightedUserId = nil
                                 }
                             }
                             
                             notificationTargetUserId = nil // Clear
                        } else {
                            // Default: Open Room List
                            showRoomList = true
                        }
                    }
                    Spacer()
                }
                .zIndex(100)
            }
            
            // Radar Animation
            RadarPulseView(
                nearbyUsers: bleManager.discoveredUsers,
                nearbyRooms: filteredNearbyRooms,
                activeChatUserIds: activeChatUserIds,
                highlightedUserId: highlightedUserId,
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
                        self.roomViewModel.markAsRead(roomId: room.id)
                        self.roomViewModel.fetchMyRooms()
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
                        if let roomId = selectedRoom?.id {
                            print("🚪 ChatView dismissed for \(roomId), marking as read locally")
                            roomViewModel.markAsRead(roomId: roomId)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                roomViewModel.fetchMyRooms()
                            }
                        }
                        selectedRoom = nil
                    }
                )
            ) {
                EmptyView()
            }
            
            // Overlay Controls
            VStack {
                // Top Bar
                HStack {
                    Text("signal_active".localized)
                        .font(.radarData)
                        .foregroundColor(ThemeManager.shared.isDarkMode ? .neonGreen : .structuralGray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ThemeManager.shared.isDarkMode ? Color.neonGreen.opacity(0.1) : Color.black.opacity(0.05))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(ThemeManager.shared.isDarkMode ? Color.neonGreen.opacity(0.3) : Color.structuralGray, lineWidth: 1)
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
                            .font(.system(size: 24))
                            .foregroundColor(ThemeManager.shared.isDarkMode ? .neonGreen : .structuralGray)
                            .padding(12)
                            .background(Color.textPrimary.opacity(0.05))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                if bleManager.isRawScanMode {
                    VStack {
                        // Filter Picker
                        Picker("Filter", selection: $selectedDeviceFilter) {
                            Text("all".localized).tag(BLEManager.DeviceType?.none)
                            Text("ios".localized).tag(BLEManager.DeviceType?.some(.ios))
                            Text("android".localized).tag(BLEManager.DeviceType?.some(.android))
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                        
                        RawRadarView(peripherals: bleManager.rawPeripherals, filter: selectedDeviceFilter)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false)
                    }
                }
                
                Spacer()

                HStack {
                    Button(action: {
                        showRoomList = true
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
                        showQuickQuestionInput = true
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
                        .foregroundColor(.textPrimary)
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
                // Determine Display Name based on MaskID setting
                let displayName = targetUser.displayName
                
                ConnectionAlertView(
                    matchedUser: displayName,
                    title: "start_chat_title".localized,
                    message: "start_chat_message".localized,
                    confirmText: "start".localized,
                    onAccept: {
                        withAnimation { showChatAlert = false }
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
                    // Dimmed Background
                    Color.black.opacity(0.6).edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            showQuickQuestionInput = false
                        }
                    
                    VStack {
                        Spacer()
                        
                        // Card Content
                        VStack(spacing: 12) {
                            HStack {
                                Text("quick_question".localized)
                                    .font(.subheadline)
                                    .foregroundColor(Color.theme.accentPrimary)
                                Spacer()
                            }
                            
                            TextEditor(text: $quickQuestionText)
                                .frame(height: 60)
                                .scrollContentBackground(.hidden) // Cleaner
                                .padding(8)
                                .background(Color.theme.bgLayer2)
                                .cornerRadius(8)
                                .foregroundColor(Color.theme.textPrimary)
                                .accentColor(Color.theme.accentPrimary)
                            
                            HStack {
                                Spacer()
                                Button(action: {
                                    sendQuickQuestion()
                                }) {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(ThemeManager.shared.isDarkMode ? .black : .white)
                                        .padding(10)
                                        .background(Color.theme.accentPrimary)
                                        .clipShape(Circle())
                                }
                                .disabled(quickQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .opacity(quickQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                            }
                        }
                        .padding(16)
                        .background(Color.theme.bgLayer1)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.theme.borderPrimary, lineWidth: 0.5)
                        )
                        .padding(.horizontal, 20)
                        // Adjust bottom padding to be above tab bar area but not floating too high
                        .padding(.bottom, 100)
                    }
                }
                .transition(.opacity) // check: "remove animation" -> opacity is simple. 
                .zIndex(2)
            }
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginView(viewModel: authViewModel)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileView(viewModel: authViewModel)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView(authViewModel: authViewModel)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView(authViewModel: authViewModel)
                .environmentObject(themeManager)
        }
        .alert(isPresented: $authViewModel.showIdentityRegeneratedAlert) {
            Alert(
                title: Text("identity_regenerated".localized),
                message: Text("identity_regenerated_desc".localized),
                primaryButton: .default(Text("settings".localized)) {
                    showSettingsSheet = true
                },
                secondaryButton: .cancel(Text("ok".localized))
            )
        }
        // Room List via Navigation Push (Full Screen)
        .background(
            NavigationLink(destination: RoomListView(viewModel: roomViewModel).environmentObject(themeManager), isActive: $showRoomList) {
                EmptyView()
            }
        )
        // Removed .id(themeManager.isDarkMode) to prevent full rebuild
        .onAppear {
            roomViewModel.fetchNearbyRooms()
            roomViewModel.fetchMyRooms()
            bleManager.start()
            
            // Listen for new messages for global notifications & unread count
            SocketManager.shared.on("new-message") { data, ack in
                guard let messageData = data.first as? [String: Any],
                      let roomId = messageData["roomId"] as? String,
                      let content = messageData["content"] as? String,
                      let nickname = messageData["nickname"] as? String ?? messageData["nicknameMask"] as? String else { return }
                
                // Filter 1: Don't count own messages
                if let msgUserId = messageData["userId"] as? String,
                   let currentUserId = authViewModel.currentUser?.id,
                   msgUserId == currentUserId {
                    return
                }
                
                // If we are NOT in this room, show notification and refresh list
                if self.selectedRoom?.uniqueId != roomId {
                    self.roomViewModel.incrementUnreadCount(roomId: roomId)
                    // REMOVED: self.roomViewModel.fetchMyRooms() to prevent race condition overwriting local +1
                    
                    DispatchQueue.main.async {
                        let bannerMessage = "\(nickname): \(content)"
                        APIService.shared.debugMessageSubject.send(bannerMessage)
                        self.notificationMessage = bannerMessage
                        withAnimation {
                            // self.showNotificationBanner = true // Disabled by user request
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                self.showNotificationBanner = false
                            }
                        }
                    }
                } else {
                    self.roomViewModel.markAsRead(roomId: roomId)
                }
            } // <-- close first socket handler properly
            
            // [Ghost User Fix] Listen for User Left events

            // Listen for Global Notification Tap (if implemented via UNUserNotificationCenter)
            // Or a NotificationCenter broadcast for "HighlightUser"
            NotificationCenter.default.addObserver(forName: NSNotification.Name("HighlightUser"), object: nil, queue: .main) { notification in
                if let userId = notification.userInfo?["userId"] as? String {
                     // Dismiss all sheets
                     showProfileSheet = false
                     showSettingsSheet = false
                     showProfileSheet = false
                     showSettingsSheet = false
                     showRoomList = false
                     showLoginSheet = false
                     showLoginSheet = false
                     
                     // Highlight
                     highlightedUserId = userId
                     
                     // Auto-clear
                     DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                         if highlightedUserId == userId {
                             highlightedUserId = nil
                         }
                     }
                }
            }
        } // <-- close onAppear
        .onDisappear {
            bleManager.stop()
        }
        .onReceive(NavigationManager.shared.$selectedRoomId) { roomId in
            guard let roomId = roomId else { return }
            print("🔗 MainView received deep link to room: \(roomId)")
            roomViewModel.fetchRoom(id: roomId) { room in
                if let room = room {
                    self.selectedRoom = room
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
        let myJoinedRoomIds = Set(roomViewModel.myRooms.map { $0.id })
        
        return rooms.filter { (room: Room) -> Bool in
            if myJoinedRoomIds.contains(room.id) {
                return false
            }
            let isCreatorNearby = bleManager.discoveredUsers.contains { user in
                user.id == room.creatorId
            }
            return isCreatorNearby
        }
    }
}

// Custom Speech Bubble Shape
struct BubbleShape: Shape {
    var cornerRadius: CGFloat
    var tailSize: CGSize

    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Define bubble area (minus tail)
        let bubbleRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tailSize.height)
        
        path.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        
        // Add Tail
        let tailStart = CGPoint(x: rect.midX - tailSize.width / 2, y: bubbleRect.maxY)
        let tailTip = CGPoint(x: rect.midX, y: rect.maxY)
        let tailEnd = CGPoint(x: rect.midX + tailSize.width / 2, y: bubbleRect.maxY)
        
        path.move(to: tailStart)
        path.addLine(to: tailTip)
        path.addLine(to: tailEnd)
        
        // Manual draw for correct stroke
        return manualPath(in: rect)
    }
    
    func manualPath(in rect: CGRect) -> Path {
        var path = Path()
        let r = cornerRadius
        let bubbleH = rect.height - tailSize.height
        
        path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: bubbleH - r))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: bubbleH - r), radius: r, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.midX + tailSize.width / 2, y: bubbleH))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX - tailSize.width / 2, y: bubbleH))
        path.addLine(to: CGPoint(x: rect.minX + r, y: bubbleH))
        path.addArc(center: CGPoint(x: rect.minX + r, y: bubbleH - r), radius: r, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
        path.closeSubpath()
        return path
    }
}
