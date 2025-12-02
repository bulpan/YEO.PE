import Foundation
import Combine

class RoomListViewModel: ObservableObject {
    @Published var nearbyRooms: [Room] = []
    @Published var myRooms: [Room] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
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
    
    func createRoom(name: String, completion: @escaping (Bool) -> Void) {
        let body = ["name": name, "category": "general"]
        
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
            "targetUserId": user.id,
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
}
