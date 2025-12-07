import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var isShowingRegister = false
    
    @StateObject private var appleAuth = AppleAuthManager()
    @StateObject private var googleAuth = GoogleAuthManager()
    @StateObject private var kakaoAuth = KakaoAuthManager()
    @StateObject private var naverAuth = NaverAuthManager()
    
    var body: some View {
        ZStack {
            Color.deepBlack.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Close Button
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
                
                Text("YEO.PE")
                    .font(.radarHeadline)
                    .foregroundColor(.neonGreen)
                    .padding(.bottom, 40)
                    .shadow(color: .neonGreen.opacity(0.5), radius: 10)
                
                TextField("email".localized, text: $viewModel.email)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color.glassBlack)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .autocapitalization(.none)
                
                SecureField("password".localized, text: $viewModel.password)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color.glassBlack)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                // Keep Me Logged In Checkbox
                HStack {
                    Button(action: {
                        viewModel.keepLoggedIn.toggle()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.keepLoggedIn ? "checkmark.square.fill" : "square")
                                .foregroundColor(viewModel.keepLoggedIn ? .neonGreen : .textSecondary)
                            Text("keep_me_logged_in".localized)
                                .font(.radarCaption)
                                .foregroundColor(.textSecondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.signalRed)
                        .font(.radarCaption)
                }
                
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .neonGreen))
                } else {
                    NeonButton(title: "login_button".localized) {
                        viewModel.login()
                    }
                }
                
                HStack(spacing: 15) {
                    SocialLoginButton(provider: "Google", color: .red) {
                        googleAuth.signIn { result in
                            handleSocialLoginResult(provider: "google", result: result)
                        }
                    }
                    SocialLoginButton(provider: "Apple", color: .white) {
                        appleAuth.startSignIn { result in
                            handleSocialLoginResult(provider: "apple", result: result)
                        }
                    }
                    SocialLoginButton(provider: "Kakao", color: .yellow) {
                        kakaoAuth.signIn { result in
                            handleSocialLoginResult(provider: "kakao", result: result)
                        }
                    }
                    SocialLoginButton(provider: "Naver", color: .green) {
                        naverAuth.signIn { result in
                            handleSocialLoginResult(provider: "naver", result: result)
                        }
                    }
                }
                .padding(.top, 10)
                
                Button(action: {
                    isShowingRegister = true
                }) {
                    Text("create_account".localized)
                        .foregroundColor(.gray)
                        .font(.footnote)
                }
            }
            .padding()
        }
        .sheet(isPresented: $isShowingRegister) {
            RegisterView(viewModel: viewModel)
        }
        .onChange(of: viewModel.isLoggedIn) { isLoggedIn in
            if isLoggedIn {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }

    func handleSocialLoginResult(provider: String, result: Result<String, Error>) {
        switch result {
        case .success(let token):
            viewModel.socialLogin(provider: provider, token: token)
        case .failure(let error):
            print("\(provider) Login Error: \(error.localizedDescription)")
            // Optionally show error in UI
        }
    }
}

struct SocialLoginButton: View {
    let provider: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(String(provider.prefix(1)))
                .font(.headline)
                .foregroundColor(color == .white ? .black : .white)
                .frame(width: 44, height: 44)
                .background(color)
                .clipShape(Circle())
        }
    }
}
