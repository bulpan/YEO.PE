import Foundation
import Combine
import SocketIO

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
        
        socket?.connect()
    }
    
    func disconnect() {
        socket?.disconnect()
        isConnected = false
    }
    
    func joinRoom(roomId: String) {
        socket?.emit("join-room", ["roomId": roomId])
    }
    
    func leaveRoom(roomId: String) {
        socket?.emit("leave-room", ["roomId": roomId])
    }
    
    func sendMessage(roomId: String, content: String) {
        let data: [String: Any] = [
            "roomId": roomId,
            "type": "text",
            "content": content
        ]
        socket?.emit("send-message", data)
    }
    
    // Helper to listen for events
    func on(_ event: String, callback: @escaping ([Any], SocketAckEmitter) -> Void) {
        socket?.on(event, callback: callback)
    }
    
    func off(_ event: String) {
        socket?.off(event)
    }
}
