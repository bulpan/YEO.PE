import SwiftUI

struct ReportSheet: View {
    let targetUserId: String // ID not User object to keep it simple
    let targetUserNickname: String
    var onReport: (String, String?, @escaping (Bool) -> Void) -> Void // updated signature
    var onBlock: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedReason: String = "spam"
    @State private var details: String = ""
    @State private var showBlockConfirmation = false
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    
    let reasons = [
        ("spam", "spam".localized),
        ("abusive", "abusive".localized),
        ("inappropriate", "inappropriate_content".localized),
        ("other", "other".localized)
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("report_reason".localized)) {
                    Picker("reason".localized, selection: $selectedReason) {
                        ForEach(reasons, id: \.0) { reason in
                            Text(reason.1).tag(reason.0)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 120)
                }
                
                Section(header: Text("details_optional".localized)) {
                    TextEditor(text: $details)
                        .frame(height: 100)
                }
                
                Section {
                    Button(action: {
                        isSubmitting = true
                        onReport(selectedReason, details.isEmpty ? nil : details) { success in
                            isSubmitting = false
                            if success {
                                HapticManager.shared.success()
                                showSuccessAlert = true
                            } else {
                                // Optional: Show error
                                HapticManager.shared.error()
                            }
                        }
                    }) {
                        if isSubmitting {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("report_submit".localized)
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(isSubmitting)
                }
                
                Section {
                    Button(action: {
                        showBlockConfirmation = true
                    }) {
                        Text("block_user".localized)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("report_user".localized)
            .navigationBarItems(leading: Button("cancel".localized) {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showBlockConfirmation) {
                Alert(
                    title: Text("block_user".localized),
                    message: Text("block_confirm_message".localized),
                    primaryButton: .destructive(Text("block".localized)) {
                        HapticManager.shared.error() // Or heavy
                        onBlock()
                        presentationMode.wrappedValue.dismiss()
                    },
                    secondaryButton: .cancel(Text("cancel".localized))
                )
            }
            // Success Alert (Attached to background to avoid conflict? Or straight on View)
            .background(
                Color.clear
                    .alert(isPresented: $showSuccessAlert) {
                        Alert(
                            title: Text("report_submitted".localized),
                            message: Text("report_submitted_desc".localized),
                            dismissButton: .default(Text("ok".localized)) {
                                presentationMode.wrappedValue.dismiss()
                            }
                        )
                    }
            )
        }
    }
}
