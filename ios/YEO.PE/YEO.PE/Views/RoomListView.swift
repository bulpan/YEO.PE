import SwiftUI

struct RoomListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = RoomListViewModel()
    @State private var isShowingCreateRoom = false
    @State private var showLoginSheet = false
    @State private var newRoomName = ""
    @State private var showCreateSuccessAlert = false
    @State private var selectedRoom: Room?
    
    var body: some View {
        List {
            Section(header: Text("MY ROOMS")) {
                if viewModel.myRooms.isEmpty {
                    Text("No active rooms")
                        .foregroundColor(.gray)
                } else {
                    ForEach(viewModel.myRooms) { room in
                        Button(action: {
                            selectedRoom = room
                        }) {
                            RoomRow(room: room)
                        }
                    }
                }
            }
            
            Section(header: Text("NEARBY ROOMS")) {
                if viewModel.nearbyRooms.isEmpty {
                    Text("No rooms nearby")
                        .foregroundColor(.gray)
                } else {
                    ForEach(viewModel.nearbyRooms) { room in
                        Button(action: {
                            if authViewModel.isLoggedIn {
                                selectedRoom = room
                            } else {
                                showLoginSheet = true
                            }
                        }) {
                            RoomRow(room: room)
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Rooms")
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
            viewModel.fetchNearbyRooms()
        }
        .sheet(isPresented: $isShowingCreateRoom) {
            VStack {
                Text("Create Room")
                    .font(.headline)
                    .padding()
                
                TextField("Room Name", text: $newRoomName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button("Create") {
                    viewModel.createRoom(name: newRoomName) { success in
                        if success {
                            isShowingCreateRoom = false
                            newRoomName = ""
                            // Delay alert to allow sheet to dismiss smoothly
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showCreateSuccessAlert = true
                            }
                        }
                    }
                }
                .padding()
                .disabled(newRoomName.isEmpty)
            }
            .padding()
        }
        .alert(isPresented: $showCreateSuccessAlert) {
            Alert(title: Text("Success"), message: Text("Room created successfully!"), dismissButton: .default(Text("OK")))
        }
    }
}

struct RoomRow: View {
    let room: Room
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(room.name)
                    .font(.headline)
                Text("Members: \(room.memberCount ?? 0)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
    }
}
