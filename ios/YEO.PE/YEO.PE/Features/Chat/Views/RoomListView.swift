import SwiftUI

struct RoomListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject var viewModel: RoomListViewModel // Shared Instance
    @State private var isShowingCreateRoom = false
    @State private var showLoginSheet = false
    @State private var newRoomName = ""
    @State private var selectedRoom: Room?
    
    var body: some View {
        ZStack {
            // Main List Content
            List {
                if viewModel.myRooms.isEmpty {
                    Text("no_active_rooms".localized)
                        .foregroundColor(.gray)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(viewModel.myRooms) { room in
                        Button(action: {
                            if let currentUserId = authViewModel.userId,
                               room.isActive == false,
                               room.creatorId == currentUserId {
                            } else {
                                selectedRoom = room
                            }
                        }) {
                            VStack(spacing: 0) {
                                RoomRow(room: room, currentUserId: authViewModel.userId)
                                    .padding(.vertical, 6) // Reduced height (approx 80% of original 8+8=16 padding? actually simply reducing wrapper padding)
                                    
                                Divider() // Full width separator
                                    .background(Color.theme.borderPrimary)
                            }
                        }
                        .listRowInsets(EdgeInsets()) // Remove default insets for full width
                        .listRowSeparator(.hidden) // Hide default
                        .listRowBackground(Color.theme.bgLayer1)
                        .disabled(authViewModel.userId == room.creatorId && room.isActive == false)
                    }
                }
            }
            .listStyle(PlainListStyle()) // Better control over background
            .navigationBarTitleDisplayMode(.inline) // Make large title inline (smaller) or hide it to use custom
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("rooms_title".localized)
                        .font(.headline) // Standard size, not large
                        .foregroundColor(Color.theme.textPrimary)
                }
            }
            .onAppear {
                 // Force transparent list background so global background shows
                 UITableView.appearance().backgroundColor = .clear
                 UITableViewCell.appearance().backgroundColor = .clear
                 // Fetch is handled by MainView or manual refresh, but we can keep it for safety if MainView didn't fetch yet?
                 // Since MainView fetches on Appear, and we share the VM, we might not need this. 
                 // But manual pull-to-refresh would be good. For now, keep it? 
                 // NO, MainView overwrites logic. Let's rely on MainView's cycle or explicit refresh. 
                 // Actually, leaving it doesn't hurt, but removing it prevents the "Overwrite" race condition if this view appears often.
                 // User asked to clean up logic. Let's KEEP it for now but note that MainView owns it.
                 viewModel.fetchMyRooms()
            }
            .background(Color.theme.bgMain.edgesIgnoringSafeArea(.all))
            .navigationBarItems(trailing: Button(action: {
                if authViewModel.isLoggedIn {
                    withAnimation { isShowingCreateRoom = true }
                } else {
                    showLoginSheet = true
                }
            }) {
                Image(systemName: "plus")
            })
            .background(
                NavigationLink(
                    destination: selectedRoom != nil ? ChatView(room: selectedRoom!) : nil,
                    isActive: Binding(
                        get: { selectedRoom != nil },
                        set: { isActive in 
                            if !isActive {
                                // Logic: User left the room (popped back)
                                if let room = selectedRoom {
                                    print("🔙 Returning from room \(room.name). Clearing unread count locally.")
                                    viewModel.markAsRead(roomId: room.uniqueId)
                                }
                                selectedRoom = nil 
                            }
                        }
                    )
                ) { EmptyView() }
            )
            .sheet(isPresented: $showLoginSheet) {
                LoginView(viewModel: authViewModel)
            }
            
            // Custom Popup Overlay
            if isShowingCreateRoom {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation { isShowingCreateRoom = false }
                    }
                
                VStack(spacing: 20) {
                    Text("create_room".localized)
                        .font(.radarHeadline)
                        .foregroundColor(Color.theme.textPrimary)
                    
                    TextField("room_name".localized, text: $newRoomName)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding()
                        .background(Color.theme.bgLayer2)
                        .cornerRadius(12)
                        .foregroundColor(Color.theme.textPrimary)
                        .accentColor(Color.theme.accentPrimary)
                    
                    HStack(spacing: 15) {
                        Button(action: {
                            withAnimation { isShowingCreateRoom = false }
                            newRoomName = ""
                        }) {
                            Text("cancel".localized)
                                .font(.radarBody)
                                .foregroundColor(Color.theme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.theme.bgLayer2)
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            // Get nearby users from BLEManager singleton
                            let nearbyUserIds = BLEManager.shared.discoveredUsers.compactMap { $0.id }
                            
                            viewModel.createRoom(name: newRoomName, nearbyUserIds: nearbyUserIds) { success in
                                if success {
                                    withAnimation { isShowingCreateRoom = false }
                                    newRoomName = ""
                                    // Refresh list immediately
                                    viewModel.fetchMyRooms()
                                }
                            }
                        }) {
                            Text("create".localized)
                                .font(.radarBody)
                                .fontWeight(.bold)
                                .foregroundColor(Color.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.theme.accentPrimary)
                                .cornerRadius(12)
                        }
                        .disabled(newRoomName.isEmpty)
                        .opacity(newRoomName.isEmpty ? 0.6 : 1.0)
                    }
                }
                .padding(24)
                .background(Color.theme.bgMain)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 40)
                .transition(.scale.combined(with: .opacity))
                .zIndex(100)
            }
        }
        .onAppear {
            viewModel.fetchMyRooms()
        }
    }
}

struct RoomRow: View {
    let room: Room
    let currentUserId: String?
    
    var isQuickQuestion: Bool {
        return room.metadata?.category == "quick_question"
    }
    
    var isWaitingForResponse: Bool {
        return room.isActive == false && currentUserId == room.creatorId
    }
    
    var fallbackAvatar: some View {
        Circle()
            .fill(Color.theme.accentPrimary.opacity(0.1))
            .frame(width: 50, height: 50)
            .overlay(
                Text(String(room.displayName.prefix(1)))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.theme.accentPrimary)
            )
    }

    private func getProfileUrl(from path: String) -> URL? {
        var baseUrl = AppConfig.baseURL
        if baseUrl.hasPrefix("ws://") { baseUrl = baseUrl.replacingOccurrences(of: "ws://", with: "http://") }
        else if baseUrl.hasPrefix("wss://") { baseUrl = baseUrl.replacingOccurrences(of: "wss://", with: "https://") }
        
        let fullUrl = path.hasPrefix("http") ? path : "\(baseUrl)\(path)"
        return URL(string: fullUrl)
    }
    
    var body: some View {
        HStack {
            // Icon / Avatar Area
            ZStack {
                if isQuickQuestion {
                    Circle()
                        .fill(Color.yellow.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.yellow)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                } else if isWaitingForResponse {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "clock")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        )
                } else {
                    // General / Active Room
                    // General / Active Room
                    if let profilePath = room.displayProfileImageUrl, !profilePath.isEmpty, let url = getProfileUrl(from: profilePath) {
                         CachedAsyncImage(url: url)
                             .frame(width: 50, height: 50)
                             .clipShape(Circle())
                    } else {
                        fallbackAvatar
                    }
                }
            }
            .padding(.trailing, 8)
            .padding(.leading, 16) // Add leading padding since we removed listRowInsets
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(room.displayName)
                        .font(.headline)
                        .foregroundColor(isWaitingForResponse ? .gray : .textPrimary)
                    
                    if isQuickQuestion {
                        Text("OPEN")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow)
                            .cornerRadius(4)
                    }
                }
                
                if let lastMessage = room.lastMessage {
                    Text(lastMessage)
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                } else if isWaitingForResponse {
                    Text("waiting_response_short".localized) // "Waiting for reply..."
                        .font(.caption)
                        .foregroundColor(.gray)
                        .italic()
                } else {
                    Text("no_messages".localized)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
            
            Spacer()
            
            // Unread Badge
            if let unreadCount = room.unreadCount, unreadCount > 0 {
                Text("\(unreadCount)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.red)
                    .clipShape(Circle())
            }
        }
        //.padding(.vertical, 4) // Handled by wrapper
        .padding(.trailing, 16) // Add trailing padding since we removed listRowInsets
        .opacity(isWaitingForResponse ? 0.6 : 1.0)
    }
}
