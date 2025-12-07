import Foundation
import Combine
import SwiftUI

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var newMessageText = ""
    @Published var isLoading = false
    @Published var members: [User] = []
    
    let room: Room
    let targetUser: User?
    let currentUser: User? // Add currentUser
    
    var isTargetUserActive: Bool {
        guard let targetUser = targetUser else { return true } 
        return members.contains(where: { $0.id == targetUser.id })
    }
    
    private var socketManager = SocketManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init(room: Room, targetUser: User? = nil, currentUser: User? = nil) {
        self.room = room
        self.targetUser = targetUser
        self.currentUser = currentUser
    }
    
    struct JoinResponse: Decodable {
        let success: Bool
    }
    
    struct LeaveRoomResponse: Decodable {
        let roomId: String
        let message: String
    }

    private var listenerUUIDs: [String: UUID] = [:]

    func joinRoom() {
        print("🎬 ChatViewModel: joinRoom called for \(room.uniqueId)")
        
        // 1. Join via API
        APIService.shared.request("/rooms/\(room.uniqueId)/join", method: "POST") { [weak self] (result: Result<JoinResponse, Error>) in
             print("API Join result: \(result)")
        }
        
        // 2. Connect Socket
        socketManager.connect()
        
        // Wait for connection before joining
        if socketManager.isConnected {
            print("ChatViewModel: Socket already connected, joining room now")
            socketManager.joinRoom(roomId: room.uniqueId)
        } else {
             print("ChatViewModel: Socket connecting...")
        }
        
        // Listen for connection status changes
        // First cancel existing to prevent duplicates
        cancellables.removeAll()
        
        socketManager.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                if isConnected {
                    print("🔄 Socket Connected - Rejoining Room & Syncing")
                    self?.socketManager.joinRoom(roomId: self?.room.uniqueId ?? "")
                    self?.fetchMessages() // Sync messages on reconnect
                }
            }
            .store(in: &cancellables)
            
        fetchMessages()
        fetchMembers()
        
        // Clear previous listeners just in case
        leaveRoom()
        
        // Register Listeners
        if let uuid = socketManager.on("room-joined") { [weak self] data, ack in
            print("✅ CSocket: Successfully joined room channel")
            self?.fetchMembers()
        } { listenerUUIDs["room-joined"] = uuid }
        
        if let uuid = socketManager.on("member-joined") { [weak self] data, ack in
             self?.fetchMembers()
        } { listenerUUIDs["member-joined"] = uuid }
        
        if let uuid = socketManager.on("new-message") { [weak self] data, ack in
            guard let self = self else { return }
            guard let messageData = data.first as? [String: Any] else { return }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: messageData, options: [])
                let message = try JSONDecoder().decode(Message.self, from: jsonData)
                
                print("📩 Received message: \(message.type ?? "unknown") - \(message.content ?? "")")
                
                DispatchQueue.main.async {
                    if let index = self.messages.firstIndex(where: { $0.id == message.id }) { return }
                    
                    // Deduplicate & Sync: Check if message is from me
                    // Use TokenManager as fallback source of truth
                    let currentUserId = self.currentUser?.id ?? TokenManager.shared.userId ?? ""
                    let isFromMe = (message.userId.caseInsensitiveCompare(currentUserId) == .orderedSame)
                    
                    // FILTER: Ignore system messages about myself (e.g. "XXX joined")
                    if message.type == "system" && isFromMe {
                        print("🚫 Ignoring system message about myself: \(message.content ?? "")")
                        return
                    }
                    
                    print("🔎 Message Dedup: ID=\(message.id) | Me=\(currentUserId) vs Sender=\(message.userId) | isMe=\(isFromMe)")
                    
                    if isFromMe {
                        if let optimisticIndex = self.messages.firstIndex(where: { 
                            // Check userId match AND localStatus is sending
                            let optUserMatch = ($0.userId.caseInsensitiveCompare(currentUserId) == .orderedSame)
                            return optUserMatch && $0.localStatus == .sending 
                        }) {
                            var realMessage = message
                            realMessage.localStatus = .sent
                            self.messages[optimisticIndex] = realMessage
                            print("✅ Synced optimistic message")
                            return
                        } else {
                            // If no optimistic message found (maybe distinct device?), strictly ensure it's treated as Mine
                            // But usually we append.
                            // If we append here, MessageRow needs to know it's me.
                        }
                    }
                    
                    self.messages.append(message)
                }
            } catch {
                print("Failed to decode new message: \(error)")
            }
        } { listenerUUIDs["new-message"] = uuid }
        
        if let uuid = socketManager.on("member-left") { [weak self] data, ack in
             print("👋 Member left event received")
             self?.fetchMembers()
        } { listenerUUIDs["member-left"] = uuid }
        
        if let uuid = socketManager.on("evaporate_messages") { [weak self] data, ack in
            guard let self = self else { return }
            guard let payload = data.first as? [String: Any],
                  let userId = payload["userId"] as? String else { return }
            
            print("💨 Evaporating messages for user: \(userId)")
            
            DispatchQueue.main.async {
                withAnimation {
                    self.messages.removeAll { $0.userId == userId && $0.type != "system" }
                }
            }
        } { listenerUUIDs["evaporate_messages"] = uuid }
    }
    
    func leaveRoom() {
        print("🚪 ChatViewModel: Cleanup listeners")
        for (key, uuid) in listenerUUIDs {
            socketManager.off(id: uuid)
            print("   - Removed listener for \(key)")
        }
        listenerUUIDs.removeAll()
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
        
        socketManager.sendMessage(roomId: room.uniqueId, content: content)
        
        // Optimistic Update: Append message locally immediately
        let tempId = UUID().uuidString
        let myId = currentUser?.id ?? TokenManager.shared.userId ?? ""
        
        // Debug
        if myId.isEmpty {
             print("⚠️ Warning: sending message with empty userId. currentUser is nil and TokenManager empty.")
        }
        
        let optimisticMessage = Message(
            messageId: tempId,
            roomId: room.uniqueId,
            userId: myId,
            nickname: currentUser?.nickname,
            nicknameMask: currentUser?.nicknameMask,
            type: "text",
            content: content,
            imageUrl: nil, // Add missing argument
            createdAt: ISO8601DateFormatter().string(from: Date()), // Convert Date to String
            localStatus: .sending
        )
        // Message struct does not have expiresAt property in the initializer shown in Room.swift
        
        withAnimation {
            self.messages.append(optimisticMessage)
        }
    }
    
    private var isExiting = false // Flag to prevent re-join on exit

    func exitRoom(completion: @escaping (Bool) -> Void) {
        isLoading = true
        isExiting = true // Set flag to prevent updatePresence from re-joining
        
        APIService.shared.request("/rooms/\(room.uniqueId)/leave", method: "POST") { [weak self] (result: Result<LeaveRoomResponse, Error>) in 
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    print("✅ Successfully left room via API")
                    self?.leaveRoom() // Disconnect socket listeners
                    completion(true)
                case .failure(let error):
                    print("❌ Failed to leave room: \(error)")
                    self?.isExiting = false // Reset flag on failure
                    completion(false)
                }
            }
        }
    }
    
    func updatePresence() {
        // Prevent re-joining if we are exiting the room
        guard !isExiting else {
            print("🛑 updatePresence skipped because isExiting=true")
            return 
        }
        
        // Calling join endpoint updates last_seen_at for existing members
        // helping to clear unread badges accurately
        APIService.shared.request("/rooms/\(room.uniqueId)/join", method: "POST") { (result: Result<JoinResponse, Error>) in
             // Silent update
        }
    }
}
