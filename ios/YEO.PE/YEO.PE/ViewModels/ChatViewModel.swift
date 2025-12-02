import Foundation
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var newMessageText = ""
    @Published var isLoading = false
    @Published var members: [User] = []
    
    let room: Room
    let targetUser: User?
    
    var isTargetUserActive: Bool {
        guard let targetUser = targetUser else { return true } // If no target, assume active (group chat)
        return members.contains(where: { $0.id == targetUser.id })
    }
    
    private var socketManager = SocketManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init(room: Room, targetUser: User? = nil) {
        self.room = room
        self.targetUser = targetUser
    }
    
    struct JoinResponse: Decodable {
        let success: Bool
    }

    func joinRoom() {
        // 1. Join via API (to add to DB members)
        APIService.shared.request("/rooms/\(room.uniqueId)/join", method: "POST") { [weak self] (result: Result<JoinResponse, Error>) in
            // Even if API join fails (e.g. already joined), we proceed to socket join
            print("API Join result: \(result)")
        }
        
        // 2. Connect Socket
        socketManager.connect()
        
        // Wait for connection before joining
        if socketManager.isConnected {
            socketManager.joinRoom(roomId: room.uniqueId)
        }
        
        // Listen for connection status changes
        socketManager.$isConnected
            .sink { [weak self] isConnected in
                if isConnected {
                    self?.socketManager.joinRoom(roomId: self?.room.uniqueId ?? "")
                }
            }
            .store(in: &cancellables)
            
        fetchMessages()
        fetchMembers()
        
        socketManager.on("room-joined") { [weak self] data, ack in
            print("✅ Successfully joined room channel")
            self?.fetchMembers() // Refresh members when someone joins
        }
        
        socketManager.on("member-joined") { [weak self] data, ack in
             self?.fetchMembers()
        }
        
        socketManager.on("new-message") { [weak self] data, ack in
            guard let self = self else { return }
            guard let messageData = data.first as? [String: Any] else { return }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: messageData, options: [])
                let message = try JSONDecoder().decode(Message.self, from: jsonData)
                
                DispatchQueue.main.async {
                    // Check if we already have this message (by ID or temporary ID if we had one)
                    if !self.messages.contains(where: { $0.id == message.id }) {
                        self.messages.append(message)
                    }
                }
            } catch {
                print("Failed to decode new message: \(error)")
            }
        }
    }
    
    func leaveRoom() {
        socketManager.off("new-message")
        // Note: We do NOT call socketManager.leaveRoom() here because that triggers DB exit on server.
        // We just stop listening. The socket will handle connection state.
    }
    
    func fetchMessages() {
        isLoading = true
        APIService.shared.request("/rooms/\(room.uniqueId)/messages") { (result: Result<MessageListResponse, Error>) in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let response):
                    self.messages = response.messages
                case .failure(let error):
                    print("Failed to fetch messages: \(error)")
                }
            }
        }
    }
    
    func fetchMembers() {
        APIService.shared.request("/rooms/\(room.uniqueId)/members") { (result: Result<[String: [User]], Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if let members = response["members"] {
                        self.members = members
                    }
                case .failure(let error):
                    print("Failed to fetch members: \(error)")
                }
            }
        }
    }
    
    func sendMessage() {
        guard !newMessageText.isEmpty else { return }
        
        let content = newMessageText
        newMessageText = "" // Clear input immediately
        
        // Optimistic Update Removed to prevent duplicates
        // The socket event will add the message shortly.
        /*
        if let userId = TokenManager.shared.userId {
            let tempMessage = Message(
                messageId: UUID().uuidString,
                roomId: room.uniqueId,
                userId: userId,
                nickname: "Me", // Placeholder
                nicknameMask: "Me",
                type: "text",
                content: content,
                imageUrl: nil,
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
            self.messages.append(tempMessage)
        }
        */
        
        socketManager.sendMessage(roomId: room.uniqueId, content: content)
    }
}
