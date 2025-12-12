import SwiftUI

struct BlockedUsersView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var blockedUsers: [User] = []
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.deepBlack.edgesIgnoringSafeArea(.all)
            
            VStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .neonGreen))
                } else if blockedUsers.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "shield.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("no_blocked_users".localized) // "No blocked users"
                            .foregroundColor(.gray)
                    }
                } else {
                    List {
                        ForEach(blockedUsers) { user in
                            HStack {
                                Text(user.nickname ?? "Unknown")
                                    .foregroundColor(.white)
                                    .font(.radarBody)
                                
                                Spacer()
                                
                                Button(action: {
                                    unblock(user)
                                }) {
                                    Text("unblock".localized) // "Unblock"
                                        .font(.caption)
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.white)
                                        .cornerRadius(8)
                                }
                            }
                            .listRowBackground(Color.deepBlack)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
        }
        .navigationBarTitle("blocked_users".localized, displayMode: .inline)
        .onAppear(perform: loadBlockedUsers)
    }
    
    private func loadBlockedUsers() {
        isLoading = true
        APIService.shared.getBlockedUsers { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let response):
                    self.blockedUsers = response.blockedUsers
                case .failure(let error):
                    print("Failed to fetch blocked users: \(error)")
                }
            }
        }
    }
    
    private func unblock(_ user: User) {
        authViewModel.unblockUser(userId: user.id)
        // Optimistically remove from list
        withAnimation {
            blockedUsers.removeAll { $0.id == user.id }
        }
    }
}
