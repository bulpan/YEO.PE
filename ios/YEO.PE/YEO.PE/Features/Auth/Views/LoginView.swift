import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var languageManager = LanguageManager.shared
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
                    NeonButton(title: "login_button".localized, action: {
                        viewModel.login()
                    }) // Removed hardcoded color/textColor to use NeonButton's new adaptive defaults
                }
                
                VStack(spacing: 12) {
                    // Google
                    SocialLoginButton(
                        provider: "Google",
                        imageName: "globe", // Placeholder for G logo (system icon)
                        textColor: .black,
                        backgroundColor: .white,
                        borderColor: Color.gray.opacity(0.3)
                    ) {
                        googleAuth.signIn { result in
                            handleSocialLoginResult(provider: "google", result: result)
                        }
                    }
                    
                    // Apple
                    SocialLoginButton(
                        provider: "Apple",
                        imageName: "applelogo",
                        textColor: .white,
                        backgroundColor: .black,
                        borderColor: .clear
                    ) {
                        appleAuth.startSignIn { result in
                            handleSocialLoginResult(provider: "apple", result: result)
                        }
                    }
                    
                    // Kakao
                    if languageManager.currentLanguage == .korean {
                        SocialLoginButton(
                            provider: "Kakao",
                            imageName: "message.fill", // Placeholder for Kakao Talk bubble
                            textColor: .black.opacity(0.85),
                            backgroundColor: Color(hex: "FEE500"), // Kakao Yellow
                            borderColor: .clear
                        ) {
                            kakaoAuth.signIn { result in
                                handleSocialLoginResult(provider: "kakao", result: result)
                            }
                        }
                    }
                    
                    // Naver (Hidden for now)
                    /*
                    SocialLoginButton(
                        provider: "Naver",
                        imageName: "n.circle.fill",
                        textColor: .white,
                        backgroundColor: Color(hex: "03C75A"),
                        borderColor: .clear
                    ) {
                        naverAuth.signIn { result in
                            handleSocialLoginResult(provider: "naver", result: result)
                        }
                    }
                    */
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
        . sheet(isPresented: $isShowingRegister) {
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
    let imageName: String
    let textColor: Color
    let backgroundColor: Color
    let borderColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: imageName)
                    .font(.system(size: 20))
                    .frame(width: 24, height: 24)
                
                Text(String(format: "login_with".localized, provider)) // "Login with Google", etc.
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .foregroundColor(textColor)
            .padding()
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
    }
}
