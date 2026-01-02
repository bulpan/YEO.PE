import Foundation
import Combine
import SocketIO
import UIKit
import UserNotifications

class SocketManager: ObservableObject {
    static let shared = SocketManager()
    
    var manager: SocketIO.SocketManager?
    var socket: SocketIOClient?
    
    @Published var isConnected = false
    
    private init() {}
    
    func connect() {
        if let socket = socket, (socket.status == .connected || socket.status == .connecting) {
            print("Socket already connected or connecting")
            return
        }
        
        guard let token = TokenManager.shared.accessToken else { return }
        guard let url = URL(string: AppConfig.socketURL) else { return }
        
        let config: SocketIOClientConfiguration = [
            .log(true),
            .compress,
            .connectParams(["token": token]),
            .reconnects(true),
            .reconnectWait(1)
        ]
        
        if manager == nil {
            manager = SocketIO.SocketManager(socketURL: url, config: config)
            socket = manager?.defaultSocket
        } else {
            // Update token if needed, or just reconnect
            manager?.config = config
            socket = manager?.defaultSocket
        }
        
        socket?.on(clientEvent: .connect) { [weak self] data, ack in
            print("Socket connected")
            DispatchQueue.main.async {
                self?.isConnected = true
            }
        }
        
        socket?.on(clientEvent: .disconnect) { [weak self] data, ack in
            print("Socket disconnected")
            DispatchQueue.main.async {
                self?.isConnected = false
            }
        }
        
        // Listen for new messages globally for Local Notifications
        socket?.on("new-message") { [weak self] data, ack in
            guard let self = self else { return }
            
            // Check if app is in background
            if UIApplication.shared.applicationState == .background || UIApplication.shared.applicationState == .inactive {
                if let messageData = data.first as? [String: Any],
                   let content = messageData["content"] as? String,
                   let nicknameMask = messageData["nicknameMask"] as? String, /* use nicknameMask as title */
                   let roomId = messageData["roomId"] as? String {
                    
                    self.scheduleLocalNotification(title: nicknameMask, body: content, roomId: roomId)
                }
            }
        }
        
        socket?.connect()
    }
    
    private func scheduleLocalNotification(title: String, body: String, roomId: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["action": "DEEP_LINK", "targetScreen": "CHAT_ROOM", "targetId": roomId]
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil) // Deliver immediately
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule local notification: \(error)")
            } else {
                print("✅ Scheduled local notification for background message")
            }
        }
    }
    
    func disconnect() {
        socket?.disconnect()
        isConnected = false
    }
    
    func joinRoom(roomId: String) {
        print("🔌 SocketManager: Emitting join-room with ID: \(roomId)")
        socket?.emit("join-room", ["roomId": roomId])
    }
    
    func leaveRoom(roomId: String) {
        print("🔌 SocketManager: Emitting leave-room with ID: \(roomId)")
        socket?.emit("leave-room", ["roomId": roomId])
    }
    
    func exitRoom(roomId: String) {
         print("🔌 SocketManager: Emitting exit-room with ID: \(roomId)")
        socket?.emit("exit-room", ["roomId": roomId])
    }
    
    func sendMessage(roomId: String, content: String, type: String = "text", imageUrl: String? = nil) {
        var data: [String: Any] = [
            "roomId": roomId,
            "type": type,
            "content": content
        ]
        
        if let imageUrl = imageUrl {
            data["imageUrl"] = imageUrl
        }
        
        print("🔌 SocketManager: Emitting send-message to \(roomId), type: \(type)")
        socket?.emit("send-message", data)
    }
    
    func sendTypingStart(roomId: String) {
        // print("⌨️ Start Typing: \(roomId)")
        socket?.emit("typing_start", ["roomId": roomId])
    }
    
    func sendTypingEnd(roomId: String) {
        // print("⌨️ End Typing: \(roomId)")
        socket?.emit("typing_end", ["roomId": roomId])
    }
    
    // Helper to listen for events
    @discardableResult
    func on(_ event: String, callback: @escaping ([Any], SocketAckEmitter) -> Void) -> UUID? {
        return socket?.on(event, callback: callback)
    }
    
    func off(_ event: String) {
        socket?.off(event)
    }
    
    func off(id: UUID) {
        socket?.off(id: id)
    }
}
