import SwiftUI

struct TermsAgreementView: View {
    @Binding var isPresented: Bool
    @State private var agreedToTerms = false
    @State private var agreedToZeroTolerance = false
    @State private var showTerms = false
    @State private var showPrivacy = false
    
    var onConfirm: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var hasViewedTerms = false
    @State private var hasViewedPrivacy = false
    
    @State private var showReadFirstAlert = false
    
    var body: some View {
        ZStack {
            // Background: Adapts to theme (White in Light, Black in Dark)
            (themeManager.isDarkMode ? Color.black : Color.white)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 25) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 50))
                    .foregroundColor(Color.theme.accentPrimary)
                    .padding(.bottom, 10)
                
                Text("terms_update_notice".localized)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color.theme.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("terms_update_desc".localized)
                    .font(.system(size: 16))
                    .foregroundColor(Color.theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 15) {
                    // Zero Tolerance (Primary)
                    HStack(alignment: .top) {
                        Button(action: { toggleZeroTolerance() }) {
                            Image(systemName: agreedToZeroTolerance ? "checkmark.square.fill" : "square")
                                .foregroundColor(agreedToZeroTolerance ? Color.theme.accentPrimary : Color.gray)
                                .font(.system(size: 24))
                        }
                        
                        Text("i_agree_zero_tolerance".localized)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .onTapGesture { toggleZeroTolerance() }
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // General Terms
                    HStack(alignment: .top) {
                        Button(action: { toggleTerms() }) {
                            Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                                .foregroundColor(agreedToTerms ? Color.theme.accentPrimary : Color.gray)
                                .font(.system(size: 24))
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("i_agree_to_terms".localized)
                                .font(.system(size: 14))
                                .foregroundColor(Color.theme.textPrimary)
                                .onTapGesture { toggleTerms() }
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    showTerms = true
                                    hasViewedTerms = true
                                }) {
                                    Text("terms_of_service".localized)
                                        .font(.caption)
                                        .underline()
                                        .foregroundColor(Color.theme.textSecondary)
                                }
                                
                                Button(action: {
                                    showPrivacy = true
                                    hasViewedPrivacy = true
                                }) {
                                    Text("privacy_policy".localized)
                                        .font(.caption)
                                        .underline()
                                        .foregroundColor(Color.theme.textSecondary)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                
                Spacer()
                
                Button(action: {
                    if agreedToTerms && agreedToZeroTolerance {
                        onConfirm()
                    }
                }) {
                    Text("confirm_and_continue".localized)
                        .font(.headline)
                        .foregroundColor(
                            (agreedToTerms && agreedToZeroTolerance) ? Color(white: 0.9) : .white
                        ) // Active: Bright Gray, Inactive: White
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            (agreedToTerms && agreedToZeroTolerance) ? Color.theme.accentPrimary : Color.gray
                        )
                        .cornerRadius(12)
                }
                .disabled(!agreedToTerms || !agreedToZeroTolerance)
                .padding(.bottom, 20)
            }
            .padding(30)
        }
        .sheet(isPresented: $showTerms) {
            WebViewScreen(urlString: "https://yeop3.com/terms.html?theme=\(themeManager.isDarkMode ? "dark" : "light")", title: "terms_of_service".localized)
        }
        .sheet(isPresented: $showPrivacy) {
            WebViewScreen(urlString: "https://yeop3.com/privacy.html?theme=\(themeManager.isDarkMode ? "dark" : "light")", title: "privacy_policy".localized)
        }
        .interactiveDismissDisabled()
        .alert(isPresented: $showReadFirstAlert) {
            Alert(
                title: Text("check_required".localized),
                message: Text("please_read_terms_first".localized), // Need to add localization
                dismissButton: .default(Text("ok".localized))
            )
        }
    }
    
    private func toggleZeroTolerance() {
        agreedToZeroTolerance.toggle()
    }
    
    private func toggleTerms() {
        if !hasViewedTerms || !hasViewedPrivacy {
            showReadFirstAlert = true
        } else {
            agreedToTerms.toggle()
        }
    }
}

// Preview
struct TermsAgreementView_Previews: PreviewProvider {
    static var previews: some View {
        TermsAgreementView(isPresented: .constant(true), onConfirm: {})
            .preferredColorScheme(.dark)
    }
}
