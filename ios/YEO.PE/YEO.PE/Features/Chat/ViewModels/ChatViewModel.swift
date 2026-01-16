import Foundation
import Combine
import SwiftUI

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var newMessageText = ""
    @Published var isLoading = false
    @Published var members: [User] = []
    
    // Typing Indicator
    @Published var typingUserIds: Set<String> = []
    
    var typingLabelText: String? {
        guard !typingUserIds.isEmpty else { return nil }
        let count = typingUserIds.count
        return "\(count)명이 입력 중..."
    }
    
    // Legacy support if UI used 'isOtherUserTyping'
    var isOtherUserTyping: Bool { !typingUserIds.isEmpty }
    
    private var typingTimer: Timer?
    private var isTyping = false
    
    @Published var room: Room? // Optional for lazy creation
    let targetUser: User?
    let currentUser: User?
    
    var isTargetUserActive: Bool {
        guard let targetUser = targetUser else { return true } 
        return members.contains(where: { $0.id == targetUser.id })
    }

    var displayTitle: String {
        // 1:1 Logic: Prefer Target User's nickname
        if let target = targetUser {
            return target.nicknameMask ?? target.nickname ?? "Unknown"
        }
        // Fallback to room name if room exists, else "New Chat"
        return room?.displayName ?? "New Chat"
    }
    
    var displayProfileImageUrl: String? {
        // 1. Try room's displayProfileImageUrl (from room list data)
        if let url = room?.displayProfileImageUrl, !url.isEmpty {
            return url
        }
        // 2. Fallback to targetUser's profile image
        return targetUser?.profileImageUrl
    }
    
    private var socketManager = SocketManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init(room: Room? = nil, targetUser: User? = nil, currentUser: User? = nil) {
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
        guard let room = room else { return } // Do nothing if room not created
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
                    if let roomId = self?.room?.uniqueId {
                        self?.socketManager.joinRoom(roomId: roomId)
                        self?.fetchMessages() // Sync messages on reconnect
                    }
                }
            }
            .store(in: &cancellables)
            
        fetchMessages()
        fetchMembers()
        
        // Clear previous listeners just in case
        leaveRoom()
        
        // Register Listeners

        
        let joinUUID = socketManager.on("room-joined") { [weak self] data, ack in
             print("✅ Room joined event received")
        }
        if let uuid = joinUUID { listenerUUIDs["room-joined"] = uuid }

        let memberJoinUUID = socketManager.on("member-joined") { [weak self] data, ack in
             self?.fetchMembers()
        }
        if let uuid = memberJoinUUID { listenerUUIDs["member-joined"] = uuid }
        
        let msgUUID = socketManager.on("new-message") { [weak self] data, ack in
            guard let self = self else { return }
            guard let messageData = data.first as? [String: Any] else { return }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: messageData, options: [])
                let message = try JSONDecoder().decode(Message.self, from: jsonData)
                
                DispatchQueue.main.async {
                    // Deduplication: Check if message with same ID already exists
                    if self.messages.contains(where: { $0.id == message.id }) { return }
                    
                    let currentUserId = self.currentUser?.id ?? TokenManager.shared.userId ?? ""
                    let isFromMe = (message.userId.caseInsensitiveCompare(currentUserId) == .orderedSame)
                    
                    // Filter out my own system messages if received via socket to prevent duplicates if handled locally (though normally we want them)
                    // Actually, for "User joined", if I join, I get it via socket.
                    // The duplication usually happens if multiple events fire or local optimistic update conflicts.
                    // This ID check should solve 90% of cases.
                    
                    if isFromMe {
                        if let optimisticIndex = self.messages.firstIndex(where: { 
                            let optUserMatch = ($0.userId.caseInsensitiveCompare(currentUserId) == .orderedSame)
                            return optUserMatch && $0.localStatus == .sending && $0.content == message.content
                        }) {
                            var realMessage = message
                            realMessage.localStatus = .sent
                            self.messages[optimisticIndex] = realMessage
                            return
                        }
                    }
                    self.messages.append(message)
                }
            } catch {
                print("Failed to decode new message: \(error)")
            }
        }
        if let uuid = msgUUID { listenerUUIDs["new-message"] = uuid }
        
        let leftUUID = socketManager.on("member-left") { [weak self] data, ack in
             print("👋 Member left received")
             self?.fetchMembers()
        }
        if let uuid = leftUUID { listenerUUIDs["member-left"] = uuid }
        
        let evapUUID = socketManager.on("evaporate_messages") { [weak self] data, ack in
            guard let self = self else { return }
            guard let payload = data.first as? [String: Any],
                  let userId = payload["userId"] as? String else { return }
            DispatchQueue.main.async {
                withAnimation {
                    self.messages.removeAll { $0.userId == userId && $0.type != "system" }
                }
            }
        }
        if let uuid = evapUUID { listenerUUIDs["evaporate_messages"] = uuid }
        
        let typingUUID = socketManager.on("typing_update") { [weak self] data, ack in
            guard let self = self else { return }
            guard let payload = data.first as? [String: Any],
                  let userId = payload["userId"] as? String,
                  let isTyping = payload["isTyping"] as? Bool else { return }
            
            let currentUserId = self.currentUser?.id ?? TokenManager.shared.userId ?? ""
            if userId != currentUserId {
                DispatchQueue.main.async {
                     if isTyping { self.typingUserIds.insert(userId) }
                     else { self.typingUserIds.remove(userId) }
                }
            }
        }
        if let uuid = typingUUID { listenerUUIDs["typing_update"] = uuid }
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
        guard let room = room else { return }
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
        guard let room = room else { 
            // If no room, members is just [targetUser] + [me]
             if let target = targetUser, let me = currentUser { self.members = [me, target] }
             return 
        }
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

    func sendMessage(type: String = "text", content: String? = nil, imageUrl: String? = nil) {
        let finalContent = content ?? newMessageText
        guard !finalContent.isEmpty || imageUrl != nil else { return }
        
        // 1. Lazy Creation: If room doesn't exist, create it first
        if room == nil {
            guard let target = targetUser else { return }
            createRoomAndSend(targetUser: target, type: type, content: finalContent, imageUrl: imageUrl)
            return
        }
        
        guard let room = room else { return }
        
        // Reset input if it's a text message being cleaned up
        if type == "text" && content == nil {
            newMessageText = ""
        }
        
        socketManager.sendMessage(roomId: room.uniqueId, content: finalContent, type: type, imageUrl: imageUrl)
        
        // Optimistic Update
        let tempId = UUID().uuidString
        let myId = currentUser?.id ?? TokenManager.shared.userId ?? ""
        
        let optimisticMessage = Message(
            messageId: tempId,
            roomId: room.uniqueId,
            userId: myId,
            nickname: currentUser?.nickname,
            nicknameMask: currentUser?.nicknameMask,
            userProfileImage: currentUser?.profileImageUrl, // Optimistic profile image
            type: type,
            content: finalContent,
            imageUrl: imageUrl,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            localStatus: .sending
        )
        
        withAnimation {
            self.messages.append(optimisticMessage)
        }
        
        if isTyping {
            isTyping = false
            typingTimer?.invalidate()
            socketManager.sendTypingEnd(roomId: room.uniqueId)
        }
    }
    
    private func createRoomAndSend(targetUser: User, type: String, content: String, imageUrl: String?) {
        isLoading = true
        // Create 1:1 Room
        let body: [String: Any] = [
            "name": targetUser.nickname ?? "Chat",
            "category": "private", // or general? usually private for 1:1 implies logic
            "inviteeId": targetUser.id
        ]
        
        APIService.shared.request("/rooms", method: "POST", body: body) { [weak self] (result: Result<Room, Error>) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let newRoom):
                    print("✅ Lazy Room Created: \(newRoom.id)")
                    self.room = newRoom
                    // Now join and send
                    self.joinRoom() // Connect socket
                    
                    // Small delay to ensure socket join? Actually joinRoom handles connection.
                    // But sendMessage requires socket joined.
                    // We can optimistically wait or retry.
                    // For now, call sendMessage again which will hit the 'room exists' path.
                    // But we need to handle the 'text cleared' logic carefully.
                    
                    // If text was passed explicitly (image case), pass it.
                    // If it was from newMessageText, pass it.
                    
                    // We need to clear text input HERE if it was text, because the recursive call will clear it.
                    // Actually, let's just recursively call.
                    self.sendMessage(type: type, content: content, imageUrl: imageUrl)
                    
                case .failure(let error):
                    print("❌ Failed to create room: \(error)")
                }
            }
        }
    }
    
    func uploadImage(_ image: UIImage) {
        isLoading = true
        APIService.shared.uploadImage(image: image) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let url):
                    self?.sendMessage(type: "image", content: "사진을 보냈습니다.", imageUrl: url)
                case .failure(let error):
                    print("❌ Image upload failed: \(error)")
                    // Here we might want to show an error message in UI
                }
            }
        }
    }
    
    func handleTextInput(_ text: String) {
        newMessageText = text
        guard let room = room else { return } // No typing events if no room yet
        
        guard !text.isEmpty else {
            // Text cleared -> Stop typing immediately
            if isTyping {
                isTyping = false
                typingTimer?.invalidate()
                socketManager.sendTypingEnd(roomId: room.uniqueId)
            }
            return
        }
        
        // If not already typing, start
        if !isTyping {
            isTyping = true
            socketManager.sendTypingStart(roomId: room.uniqueId)
        }
        
        // Debounce: Reset timer on every keystroke
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.isTyping = false
             if let roomId = self.room?.uniqueId {
                 self.socketManager.sendTypingEnd(roomId: roomId)
             }
        }
    }
    
    func exitRoom(completion: @escaping (Bool) -> Void) {
        guard let room = room else { completion(true); return }
        isLoading = true
        
        APIService.shared.request("/rooms/\(room.uniqueId)/leave", method: "POST") { [weak self] (result: Result<LeaveRoomResponse, Error>) in 
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    NSLog("✅ [ChatViewModel] Successfully left room via API")
                    self?.leaveRoom() // Disconnect socket listeners
                    completion(true)
                case .failure(let error):
                    NSLog("❌ [ChatViewModel] Failed to leave room: \(error)")
                    // Fail-safe: Allow user to leave locally even if server fails
                    // This prevents users from being stuck in "Zombie Rooms"
                    self?.leaveRoom()
                    completion(true)
                }
            }
        }
    }
    
    func blockUser(userId: String, completion: @escaping (Bool) -> Void) {
        let body = ["targetUserId": userId]
        
        APIService.shared.request("/users/block", method: "POST", body: body) { (result: Result<StandardResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ User blocked successfully")
                    // Locally filter messages from this user
                    self.messages.removeAll { $0.userId == userId }
                    // Also remove from members list so they don't appear in typing or header
                    self.members.removeAll { $0.id == userId }
                    completion(true)
                case .failure(let error):
                    print("❌ Failed to block user: \(error)")
                    completion(false)
                }
            }
        }
    }
    
    func reportUser(userId: String, reason: String, details: String?, completion: @escaping (Bool) -> Void) {
        var body: [String: Any] = [
            "targetUserId": userId,
            "reason": reason
        ]
        if let details = details {
            body["details"] = details
        }
        
        APIService.shared.request("/users/report", method: "POST", body: body) { (result: Result<StandardResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ User reported successfully")
                    completion(true)
                case .failure(let error):
                    print("❌ Failed to report user: \(error)")
                    completion(false)
                }
            }
        }
    }
    
    func updatePresence() {
        guard let room = room else { return }
        // Calling join endpoint updates last_seen_at for existing members
        // helping to clear unread badges accurately
        APIService.shared.request("/rooms/\(room.uniqueId)/join", method: "POST") { (result: Result<JoinResponse, Error>) in
             // Silent update
        }
    }
}
