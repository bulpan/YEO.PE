import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var debugMessage: String?
    @State private var showToast = false
    
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        ZStack {
            NavigationView {
                MainView(authViewModel: authViewModel)
            }
            .environmentObject(authViewModel)
            .background(Color.deepBlack)
            .preferredColorScheme(.dark)
            .navigationViewStyle(StackNavigationViewStyle())
            
            // Debug Toast Overlay
            if showToast, let message = debugMessage {
                VStack {
                    Spacer()
                    Text(message)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.neonGreen)
                        .padding(12)
                        .background(Color.black.opacity(0.9))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.neonGreen.opacity(0.5), lineWidth: 1)
                        )
                        .padding(.bottom, 60)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onTapGesture {
                            showToast = false
                        }
                }
                .zIndex(100)
            }
        }
        .onReceive(APIService.shared.debugMessageSubject) { message in
            self.debugMessage = message
            self.showToast = true
            
            // Auto hide after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if self.debugMessage == message {
                    self.showToast = false
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                print("📱 App became active - Connecting Socket")
                if authViewModel.isLoggedIn {
                    SocketManager.shared.connect()
                }
            case .background:
                print("📱 App went to background - Disconnecting Socket")
                SocketManager.shared.disconnect()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
