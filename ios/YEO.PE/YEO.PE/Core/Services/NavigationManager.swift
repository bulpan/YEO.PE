import Foundation
import Combine

class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    
    @Published var selectedRoomId: String?
    @Published var shouldShowRoomList: Bool = false
    @Published var targetUserId: String? // For NEARBY_USER deep link
    
    private init() {}
    
    func handleDeepLink(action: String, targetScreen: String, targetId: String?) {
        print("🔗 Handling Deep Link: action=\(action), screen=\(targetScreen), id=\(targetId ?? "nil")")
        
        DispatchQueue.main.async {
            switch targetScreen {
            case "CHAT_ROOM":
                if let roomId = targetId {
                    self.selectedRoomId = roomId
                    self.shouldShowRoomList = false // Ensure we are not just on the list
                }
            case "MAIN_MAP":
                self.selectedRoomId = nil
                self.shouldShowRoomList = false
                self.targetUserId = targetId
            default:
                print("⚠️ Unknown target screen: \(targetScreen)")
            }
        }
    }
}
