import SwiftUI

struct SuspensionView: View {
    enum ReasonContainer: Equatable {
        case text(String)
        case localized([String: String])
        
        var localizedDisplay: String {
            switch self {
            case .text(let str): return str
            case .localized(let dict):
                let lang = Locale.current.language.languageCode?.identifier ?? "en"
                // Simple check for "ko" vs others (defaults to en)
                if lang == "ko" { return dict["ko"] ?? dict["en"] ?? "" }
                return dict["en"] ?? dict["ko"] ?? ""
            }
        }
    }

    enum RestrictionType: Equatable {
        case suspended(Date, ReasonContainer?, Date?) // until, reason, suspendedAt
        case banned(ReasonContainer?, Date?) // reason, suspendedAt
    }
    
    let type: RestrictionType
    
    @State private var showingAppealAlert = false
    @State private var appealReason = ""
    @State private var isSubmitting = false
    
    var body: some View {
        ZStack {
            Color.deepBlack.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                
                VStack(spacing: 8) {
                    Text(titleText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(descText)
                        .font(.body)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Display Suspended At Time
                    if let suspendedAt = suspendedAtDate {
                         Text("신고 접수 시간: \(formatDate(suspendedAt))")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    }
                }
                
                if case .suspended(let date, _, _) = type {
                    VStack(spacing: 4) {
                        Text("lift_date".localized)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                        
                        Text(date, style: .date)
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        Text(date, style: .time)
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Button(action: {
                    showingAppealAlert = true
                }) {
                    Text("appeal_btn".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            }
            .padding()
            
            if isSubmitting {
                ProgressView()
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
            }
        }
        .alert("appeal_title".localized, isPresented: $showingAppealAlert, actions: {
            TextField("appeal_reason_hint".localized, text: $appealReason)
            Button("cancel".localized, role: .cancel) { }
            Button("submit".localized, action: submitAppeal)
        }, message: {
            Text("appeal_desc".localized)
        })
    }
    
    var titleText: String {
        switch type {
        case .suspended: return "account_suspended_title".localized
        case .banned: return "account_banned_title".localized
        }
    }
    
    var descText: String {
        switch type {
        case .suspended(_, let reason, _):
            if let r = reason { return r.localizedDisplay }
            return "account_suspended_desc".localized
        case .banned(let reason, _):
            if let r = reason { return r.localizedDisplay }
            return "account_banned_desc".localized
        }
    }
    
    var suspendedAtDate: Date? {
        switch type {
        case .suspended(_, _, let date): return date
        case .banned(_, let date): return date
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func submitAppeal() {
        guard !appealReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSubmitting = true
        APIService.shared.appealSuspension(reason: appealReason) { result in
            DispatchQueue.main.async {
                isSubmitting = false
                switch result {
                case .success:
                    print("Appeal Sent")
                case .failure(let error):
                    print("Appeal Failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
