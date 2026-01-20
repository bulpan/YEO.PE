import SwiftUI
import Combine

struct PhoneVerificationView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // UI States
    @State private var phoneNumber: String = ""
    @State private var verificationCode: String = ""
    @State private var isCodeSent = false
    @State private var verificationID: String?
    @State private var timerCount = 180 // 3 minutes
    @State private var timer: Timer.TimerPublisher = Timer.publish(every: 1, on: .main, in: .common)
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // Computed props
    var formattedTime: String {
        let minutes = timerCount / 60
        let seconds = timerCount % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // Helper for Korea Logic
    private var isKorea: Bool {
        Locale.current.regionCode == "KR"
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Text("identity_verification".localized)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    // Hidden item for balance
                    Image(systemName: "chevron.left").font(.system(size: 20)).opacity(0)
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 32) {
                        
                        // Icon
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .font(.system(size: 60))
                            .foregroundColor(.neonGreen)
                            .padding(.top, 20)
                        
                        VStack(spacing: 8) {
                            Text("verify_phone_title".localized)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("verify_phone_subtitle".localized)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Step 1: Phone Number Input
                        VStack(alignment: .leading, spacing: 10) {
                            Text("phone_number".localized)
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            HStack {
                                // Dynamic Placeholder based on Region
                                TextField(isKorea ? "010-1234-5678" : "1 555-555-5555", text: $phoneNumber)
                                    .keyboardType(.phonePad)
                                    .foregroundColor(.primary) // Auto-switch for Light/Dark mode
                                    .accentColor(.neonGreen)
                                    .font(.system(size: 18))
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground)) // Light Gray/Dark Gray adaptive
                                    .cornerRadius(12)
                                    .disabled(isCodeSent)
                                
                                if !isCodeSent {
                                    Button(action: sendVerificationCode) {
                                        Text("send_code".localized)
                                            .font(.system(size: 14, weight: .bold))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(phoneNumber.count > (isKorea ? 9 : 6) ? Color.neonGreen : Color.theme.borderPrimary)
                                            .foregroundColor(phoneNumber.count > (isKorea ? 9 : 6) ? (ThemeManager.shared.isDarkMode ? .black : .white) : Color.theme.textSecondary)
                                            .cornerRadius(12)
                                    }
                                    .disabled(phoneNumber.count <= (isKorea ? 9 : 6))
                                }
                            }
                        }
                        
                        // Step 2: Verification Code Input
                        if isCodeSent {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("verification_code".localized)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text(formattedTime)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                
                                HStack {
                                    TextField("000000", text: $verificationCode)
                                        .keyboardType(.numberPad)
                                        .foregroundColor(.primary)
                                        .accentColor(.neonGreen)
                                        .font(.system(size: 24, weight: .bold))
                                        .multilineTextAlignment(.center)
                                        .padding()
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(12)
                                }
                                
                                Button(action: verifyCode) {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: ThemeManager.shared.isDarkMode ? .black : .white))
                                    } else {
                                        Text("verify_complete".localized)
                                            .font(.headline)
                                            .foregroundColor(verificationCode.count == 6 ? (ThemeManager.shared.isDarkMode ? .black : .white) : Color.theme.textSecondary)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(verificationCode.count == 6 ? Color.neonGreen : Color.theme.borderPrimary)
                                .cornerRadius(12)
                                .disabled(verificationCode.count != 6 || viewModel.isLoading)
                                
                                Button(action: {
                                    isCodeSent = false
                                    timer.connect().cancel()
                                }) {
                                    Text("retry_phone_number".localized)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .underline()
                                }
                                .padding(.top, 8)
                            }
                            .transition(.opacity)
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            // Custom Alert (Ensure visible text)
            if showAlert {
                Color.black.opacity(0.6).edgesIgnoringSafeArea(.all)
                VStack(spacing: 20) {
                    Text("alert".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(alertMessage)
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Button(action: { showAlert = false }) {
                        Text("confirm".localized)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.neonGreen)
                            .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color(hex: "2C2C2E")) // Explicit dark gray background
                .cornerRadius(20)
                .padding(40)
            }
        }
        .onReceive(timer) { _ in
            if timerCount > 0 {
                timerCount -= 1
            } else {
                // Time expired
                // timer.connect().cancel() // auto cancel managed by state?
                // Just let it verify handle expiration
            }
        }
    }
    
    private func sendVerificationCode() {
        var formattedPhone = phoneNumber
        
        // KR Logic: 01012345678 -> +821012345678
        if isKorea {
            if formattedPhone.hasPrefix("0") {
                formattedPhone.removeFirst()
            }
            formattedPhone = "+82" + formattedPhone
        } else {
            // Global: Ensure + prefix
            if !formattedPhone.hasPrefix("+") {
                formattedPhone = "+" + formattedPhone
            }
        }
        
        viewModel.sendPhoneVerificationCode(formattedPhone) { result in
             switch result {
             case .success(let vid):
                 self.verificationID = vid
                 self.isCodeSent = true
                 self.timerCount = 180
                 self.timer = Timer.publish(every: 1, on: .main, in: .common)
                 _ = self.timer.connect()
             case .failure(let error):
                 self.alertMessage = error.localizedDescription
                 self.showAlert = true
             }
        }
    }
    
    private func verifyCode() {
        guard let verificationID = verificationID else { return }
        
        viewModel.verifyPhoneCode(verificationID: verificationID, code: verificationCode) { success in
            if success {
                self.alertMessage = "verification_success_message".localized
                self.showAlert = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.presentationMode.wrappedValue.dismiss()
                }
            } else {
                self.alertMessage = viewModel.errorMessage ?? "verification_failed".localized
                self.showAlert = true
            }
        }
    }
}
