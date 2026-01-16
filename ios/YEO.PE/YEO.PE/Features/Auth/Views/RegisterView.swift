import SwiftUI

struct RegisterView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var agreedToTerms = false
    @State private var agreedToZeroTolerance = false
    @State private var showTerms = false
    @State private var showPrivacy = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("join_field".localized)
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.bottom, 20)
                
                TextField("email_placeholder".localized, text: $viewModel.email)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .autocapitalization(.none)
                
                TextField("enter_nickname".localized, text: $viewModel.nickname)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                
                SecureField("password_placeholder".localized, text: $viewModel.password)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                // Terms Agreement
                VStack(alignment: .leading, spacing: 8) {
                        Text("i_agree_to_terms".localized)
                            .font(.caption)
                            .foregroundColor(.white)
                            .onTapGesture { agreedToTerms.toggle() }
                    
                    // Zero Tolerance Policy Agreement
                    HStack(alignment: .top) {
                        Button(action: { agreedToZeroTolerance.toggle() }) {
                            Image(systemName: agreedToZeroTolerance ? "checkmark.square.fill" : "square")
                                .foregroundColor(agreedToZeroTolerance ? .white : .gray)
                                .font(.system(size: 20))
                        }
                        
                        Text("i_agree_zero_tolerance".localized) // "I acknowledge that posting objectionable content will result in immediate permanent suspension."
                            .font(.caption)
                            .foregroundColor(.neonGreen) // Highlight this important policy
                            .onTapGesture { agreedToZeroTolerance.toggle() }
                    }
                    
                    HStack(spacing: 16) {
                        Button(action: { showTerms = true }) {
                            Text("terms_of_service".localized)
                                .font(.caption2)
                                .underline()
                                .foregroundColor(.gray)
                        }
                        
                        Button(action: { showPrivacy = true }) {
                            Text("privacy_policy".localized)
                                .font(.caption2)
                                .underline()
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.leading, 28) // Align with text
                }
                .padding(.vertical, 10)
                
                Button(action: {
                    print("🔵 Register Button Tapped")
                    if agreedToTerms && agreedToZeroTolerance {
                        viewModel.register()
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("register".localized)
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background((agreedToTerms && agreedToZeroTolerance) ? Color.white : Color.gray)
                            .cornerRadius(8)
                    }
                }
                .disabled(viewModel.isLoading || !agreedToTerms || !agreedToZeroTolerance)
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("cancel".localized)
                        .foregroundColor(.gray)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showTerms) {
            WebViewScreen(urlString: "https://yeop3.com/terms.html?theme=\(themeManager.isDarkMode ? "dark" : "light")", title: "terms_of_service".localized)
        }
        .sheet(isPresented: $showPrivacy) {
            WebViewScreen(urlString: "https://yeop3.com/privacy.html?theme=\(themeManager.isDarkMode ? "dark" : "light")", title: "privacy_policy".localized)
        }
    }
}
