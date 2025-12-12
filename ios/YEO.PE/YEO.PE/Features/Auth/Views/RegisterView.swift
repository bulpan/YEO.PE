import SwiftUI

struct RegisterView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
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
                
                Button(action: {
                    print("🔵 Register Button Tapped")
                    viewModel.register()
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("register".localized)
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(8)
                    }
                }
                .disabled(viewModel.isLoading)
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("cancel".localized)
                        .foregroundColor(.gray)
                }
            }
            .padding()
        }
    }
}
