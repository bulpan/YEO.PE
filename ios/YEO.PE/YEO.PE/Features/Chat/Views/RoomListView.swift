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
                } else {
                    ForEach(viewModel.myRooms) { room in
                        Button(action: {
                            // Logic: Creator cannot enter inactive room
                            if let currentUserId = authViewModel.userId,
                               room.isActive == false,
                               room.creatorId == currentUserId {
                                // Do nothing (disabled)
                            } else {
                                selectedRoom = room
                            }
                        }) {
                            RoomRow(room: room, currentUserId: authViewModel.userId)
                        }
                        .listRowBackground(Color.theme.bgLayer1) // Cell background
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
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Row 1: Name (Count/Status)
                HStack {
                    Text(room.displayName)
                        .font(.headline)
                        .foregroundColor(shouldDimRoom ? Color.theme.textSecondary : Color.theme.textPrimary)
                    
                    if room.isActive == false {
                        if currentUserId == room.creatorId {
                            // Text("waiting_for_response".localized) // Removed as per request
                        } else {
                            // Text("(Invited)") // Removed as per request
                        }
                    } else {
                        Text("(\(room.memberCount ?? 0))")
                            .font(.caption)
                            .foregroundColor(Color.theme.textSecondary)
                    }
                }
                
                // Row 2: Last Message
                if let lastMessage = room.lastMessage {
                    Text(lastMessage)
                        .font(.subheadline)
                        .foregroundColor(Color.theme.textSecondary)
                        .lineLimit(2)
                } else {
                    Text("no_messages".localized)
                        .font(.caption)
                        .foregroundColor(Color.theme.textSecondary)
                }
            }
            
            Spacer()
            
            // Quick Question Icon
            if room.metadata?.category == "quick_question" {
                 Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                    .padding(.trailing, 4)
            }
            
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
        .padding(.vertical, 4)
    }
    
    var shouldDimRoom: Bool {
        return room.isActive == false && currentUserId == room.creatorId
    }
}
