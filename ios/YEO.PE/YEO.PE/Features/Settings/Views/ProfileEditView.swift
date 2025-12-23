import SwiftUI

struct ProfileEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var authViewModel: AuthViewModel
    
    @State private var nickname: String = ""
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Color.deepBlack.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("edit_profile".localized)
                        .font(.radarHeadline)
                        .foregroundColor(.white)
                    Spacer()
                    // Save Button
                    if authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .neonGreen))
                    } else {
                        Button(action: saveProfile) {
                            Text("save".localized)
                                .font(.radarBody)
                                .foregroundColor(.neonGreen)
                        }
                    }
                }
                .padding()
                
                Spacer().frame(height: 20)
                
                // Form
                VStack(alignment: .leading, spacing: 10) {
                    Text("public_nickname".localized) // "Public Nickname"
                        .font(.radarCaption)
                        .foregroundColor(.textSecondary)
                        .padding(.leading, 4)
                    
                    HStack {
                        TextField("enter_nickname".localized, text: $nickname)
                            .padding()
                            .background(Color.glassBlack)
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        
                        // Randomize Button
                        Button(action: {
                            authViewModel.randomizeMask()
                            // Wait a bit for the async update, then refresh local state
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if let newMask = authViewModel.currentUser?.nicknameMask {
                                    self.nickname = newMask
                                }
                            }
                        }) {
                            Image(systemName: "dice.fill")
                                .font(.title2)
                                .foregroundColor(.neonGreen)
                                .frame(width: 50, height: 50)
                                .background(Color.glassBlack)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        }
                    }
                    
                    Text("public_nickname_desc".localized) // "This name is shown to others."
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.leading, 4)
                }
                .padding(.horizontal)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }
                
                Spacer()
            }
        }
        .onAppear {
            if let currentMask = authViewModel.currentUser?.nicknameMask {
                self.nickname = currentMask
            } else if let currentNick = authViewModel.currentUser?.nickname {
                self.nickname = currentNick
            }
        }
    }
    
    private func saveProfile() {
        // Validation
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 2 || trimmed.count > 20 {
            errorMessage = "Nickname must be between 2 and 20 characters."
            return
        }
        
        // Update Nickname Mask (Public Identity)
        authViewModel.updateProfile(nicknameMask: trimmed) { success in
            if success {
                presentationMode.wrappedValue.dismiss()
            } else {
                errorMessage = authViewModel.errorMessage
            }
        }
    }
}
