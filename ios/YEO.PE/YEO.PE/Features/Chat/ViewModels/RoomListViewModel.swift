import Foundation
import Combine

class RoomListViewModel: ObservableObject {
    @Published var nearbyRooms: [Room] = []
    @Published var myRooms: [Room] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Manage socket listener
    private var listenerUUID: UUID? 

    init() {
        // Listen for new rooms created nearby
        listenerUUID = SocketManager.shared.on("room-created") { [weak self] data, ack in
            guard let self = self else { return }
            guard let roomData = data.first as? [String: Any] else { return }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: roomData, options: [])
                let newRoom = try JSONDecoder().decode(Room.self, from: jsonData)
                
                print("🆕 Room Created Event: \(newRoom.name) by \(newRoom.creatorId ?? "unknown")")
                
                DispatchQueue.main.async {
                    // Receiver-Side Filtering:
                    // Only show this room if the creator is currently visible in my BLE radar.
                    // This ensures robust "I see you -> I see your room" logic.
                    let isCreatorNearby = BLEManager.shared.discoveredUsers.contains { user in
                        return user.uid == newRoom.creatorId
                    }
                    
                    if isCreatorNearby {
                        print("✅ Creator is nearby! Adding room to list.")
                        // Check duplicates
                        if !self.nearbyRooms.contains(where: { $0.id == newRoom.id }) {
                            self.nearbyRooms.insert(newRoom, at: 0)
                        }
                    } else {
                        print("🚫 Creator is NOT nearby. Ignoring room.")
                    }
                }
            } catch {
                print("Failed to decode new room: \(error)")
            }
        }
    }

    deinit {
        if let uuid = listenerUUID {
             SocketManager.shared.off(id: uuid)
        }
    }
    func fetchNearbyRooms() {
        isLoading = true
        APIService.shared.request("/rooms/nearby") { (result: Result<RoomListResponse, Error>) in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let response):
                    self.nearbyRooms = response.rooms
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func fetchMyRooms() {
        APIService.shared.request("/rooms/my") { (result: Result<RoomListResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("✅ My Rooms Fetched: \(response.rooms.count) rooms")
                    self.myRooms = response.rooms
                case .failure(let error):
                    print("❌ Failed to fetch my rooms: \(error)")
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func createRoom(name: String, nearbyUserIds: [String] = [], completion: @escaping (Bool) -> Void) {
        let body: [String: Any] = [
            "name": name, 
            "category": "general",
            "nearbyUserIds": nearbyUserIds
        ]
        
        APIService.shared.request("/rooms", method: "POST", body: body) { (result: Result<Room, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    self.fetchMyRooms()
                    self.fetchNearbyRooms()
                    completion(true)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    completion(false)
                }
            }
        }
    }
    
    func createOneOnOneRoom(with user: User, completion: @escaping (Room?) -> Void) {
        // Naming convention: "Chat with [Nickname]" (Server might mask this later)
        let roomName = "Chat with \(user.nickname ?? "User")"
        let body: [String: Any] = [
            "name": roomName,
            "category": "private",
            "inviteeId": user.id,
            "nearbyUserIds": [user.id] // Trigger notification
        ]
        
        APIService.shared.request("/rooms", method: "POST", body: body) { (result: Result<Room, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let room):
                    self.fetchMyRooms()
                    self.fetchNearbyRooms()
                    completion(room)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    completion(nil)
                }
            }
        }
    }
    
    func fetchRoom(id: String, completion: @escaping (Room?) -> Void) {
        APIService.shared.request("/rooms/\(id)") { (result: Result<Room, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let room):
                    completion(room)
                case .failure(let error):
                    print("❌ Failed to fetch room details: \(error)")
                    // Fallback: Check if it's already in memory
                    if let room = self.myRooms.first(where: { $0.id == id }) ?? self.nearbyRooms.first(where: { $0.id == id }) {
                        completion(room)
                    } else {
                        completion(nil)
                    }
                }
            }
        }
    }
    
    // MARK: - Local State Updates (Optimistic)
    
    func markAsRead(roomId: String) {
        if let index = myRooms.firstIndex(where: { $0.uniqueId == roomId }) {
            var updatedRoom = myRooms[index]
            updatedRoom.unreadCount = 0
            myRooms[index] = updatedRoom // Trigger publisher
            print("✅ Locally marked room \(roomId) as read")
        }
    }
    
    func incrementUnreadCount(roomId: String) {
        if let index = myRooms.firstIndex(where: { $0.uniqueId == roomId }) {
            var updatedRoom = myRooms[index]
            let current = updatedRoom.unreadCount ?? 0
            updatedRoom.unreadCount = current + 1
            myRooms[index] = updatedRoom // Trigger publisher
            print("✅ Locally incremented unread count for room \(roomId)")
        }
    }
}
