import SwiftUI

struct RoomListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = RoomListViewModel()
    @State private var isShowingCreateRoom = false
    @State private var showLoginSheet = false
    @State private var newRoomName = ""
    @State private var selectedRoom: Room?
    
    var body: some View {
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
                    .disabled(authViewModel.userId == room.creatorId && room.isActive == false)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("rooms_title".localized)
        .navigationBarItems(trailing: Button(action: {
            if authViewModel.isLoggedIn {
                isShowingCreateRoom = true
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
                    set: { if !$0 { selectedRoom = nil } }
                )
            ) { EmptyView() }
        )
        .sheet(isPresented: $showLoginSheet) {
            LoginView(viewModel: authViewModel)
        }
        .onAppear {
            viewModel.fetchMyRooms()
        }
        .sheet(isPresented: $isShowingCreateRoom) {
            VStack {
                Text("create_room".localized)
                    .font(.headline)
                    .padding()
                
                TextField("room_name".localized, text: $newRoomName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button("create".localized) {
                    // Get nearby users from BLEManager singleton
                    let nearbyUserIds = BLEManager.shared.discoveredUsers.compactMap { $0.id }
                    
                    viewModel.createRoom(name: newRoomName, nearbyUserIds: nearbyUserIds) { success in
                        if success {
                            isShowingCreateRoom = false
                            newRoomName = ""
                            // Refresh list immediately
                            viewModel.fetchMyRooms()
                        }
                    }
                }
                .padding()
                .disabled(newRoomName.isEmpty)
            }
            .padding()
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
                        .foregroundColor(shouldDimRoom ? .gray : .primary)
                    
                    if room.isActive == false {
                        if currentUserId == room.creatorId {
                            // Text("waiting_for_response".localized) // Removed as per request
                        } else {
                            // Text("(Invited)") // Removed as per request
                        }
                    } else {
                        Text("(\(room.memberCount ?? 0))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Row 2: Last Message
                if let lastMessage = room.lastMessage {
                    Text(lastMessage)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                } else {
                    Text("no_messages".localized)
                        .font(.caption)
                        .foregroundColor(.gray)
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
        .padding(.vertical, 4)
    }
    
    var shouldDimRoom: Bool {
        return room.isActive == false && currentUserId == room.creatorId
    }
}
