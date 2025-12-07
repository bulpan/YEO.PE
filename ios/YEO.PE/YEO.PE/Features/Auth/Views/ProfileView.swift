import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.deepBlack.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                // Header
                HStack {
                    Spacer()
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.textSecondary)
                            .padding()
                    }
                }
                
                // Profile Icon
                Circle()
                    .stroke(Color.neonGreen, lineWidth: 2)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.neonGreen)
                    )
                    .shadow(color: .neonGreen.opacity(0.5), radius: 10)
                
                // User Info
                VStack(spacing: 10) {
                    Text(viewModel.nickname.isEmpty ? "user".localized : viewModel.nickname)
                        .font(.radarHeadline)
                        .foregroundColor(.white)
                    
                    Text(viewModel.email)
                        .font(.radarCaption)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                // Logout Button
                Button(action: {
                    viewModel.logout()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("logout".localized)
                        .font(.radarData)
                        .foregroundColor(.deepBlack)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(Color.neonGreen)
                        .cornerRadius(8)
                }
                .padding(.bottom, 50)
            }
            .padding()
        }
        .onAppear {
            // Ensure we have the latest profile info
            // In a real app, we might fetch it here if not already available
        }
    }
}
