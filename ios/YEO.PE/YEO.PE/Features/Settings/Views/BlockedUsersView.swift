import SwiftUI

struct BlockedUsersView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var showPolicyAlert = false
    
    var body: some View {
        ZStack {
            Color.deepBlack.edgesIgnoringSafeArea(.all)
            
            VStack {
                if authViewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .neonGreen))
                } else if authViewModel.blockedUsers.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "shield.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("no_blocked_users".localized) // "No blocked users"
                            .foregroundColor(.gray)
                    }
                } else {
                    List {
                        ForEach(authViewModel.blockedUsers) { user in
                            HStack {
                                Text(user.nickname ?? "Unknown")
                                    .foregroundColor(.white)
                                    .font(.radarBody)
                                
                                Spacer()
                                // No Unblock Button per policy
                                Text("blocked".localized)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .listRowBackground(Color.deepBlack)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
        }
        .navigationBarTitle("blocked_users".localized, displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showPolicyAlert = true
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.neonGreen)
                }
            }
        }
        .alert(isPresented: $showPolicyAlert) {
            Alert(
                title: Text("blocked_users_title".localized),
                message: Text("block_policy_info".localized),
                dismissButton: .default(Text("ok".localized))
            )
        }
        .onAppear {
            authViewModel.fetchBlockedUsers()
        }
    }
}
