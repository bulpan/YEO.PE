import SwiftUI
import Combine
import Foundation

struct ReportView: View {
    let targetUser: User
    @Binding var isPresented: Bool
    
    @State private var selectedReason = "report_spam"
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var errorMessage: String?
    
    let reasons = [
        "report_spam",
        "report_abusive",
        "report_inappropriate",
        "report_fake",
        "report_other"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.deepBlack.edgesIgnoringSafeArea(.all)
                
                Form {
                    Section(header: Text("reason".localized).foregroundColor(.gray)) {
                        Picker("select_reason".localized, selection: $selectedReason) {
                            ForEach(reasons, id: \.self) { reason in
                                Text(reason.localized).tag(reason)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    Section(header: Text("details_optional".localized).foregroundColor(.gray)) {
                        TextEditor(text: $details)
                            .frame(height: 100)
                            .foregroundColor(.white)
                    }
                    
                    Section {
                        Button(action: submitReport) {
                            HStack {
                                Spacer()
                                if isSubmitting {
                                    ProgressView()
                                } else {
                                    Text("submit_report".localized)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                }
                                Spacer()
                            }
                        }
                        .disabled(isSubmitting)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.deepBlack)
            }
            .navigationBarTitle("report_user".localized, displayMode: .inline)
            .navigationBarItems(leading: Button("cancel".localized) {
                isPresented = false
            })
            .alert(isPresented: $showSuccessAlert) {
                Alert(
                    title: Text("report_submitted".localized),
                    message: Text("report_submitted_desc".localized),
                    dismissButton: .default(Text("ok".localized)) {
                        isPresented = false
                    }
                )
            }
        }
    }
    
    private func submitReport() {
        isSubmitting = true
        APIService.shared.reportUser(targetUserId: targetUser.id, reason: selectedReason, details: details) { result in
            DispatchQueue.main.async {
                isSubmitting = false
                switch result {
                case .success:
                    showSuccessAlert = true
                case .failure(let error):
                    // In a real app, maybe show error alert
                    print("Report failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
