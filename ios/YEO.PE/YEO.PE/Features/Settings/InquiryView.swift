import SwiftUI

// MARK: - Inquiry List View
struct InquiryListView: View {
    @State private var inquiries: [Inquiry] = []
    @State private var isLoading = true
    @State private var showWriteSheet = false
    
    var body: some View {
        ZStack {
            Color.theme.bgMain.edgesIgnoringSafeArea(.all)
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .neonGreen))
            } else {
                if inquiries.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "tray")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("inquiry_empty".localized)
                            .font(.radarBody)
                            .foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(inquiries) { inquiry in
                                NavigationLink(destination: InquiryDetailView(inquiryId: inquiry.id)) {
                                    InquiryRow(inquiry: inquiry)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("inquiry_title".localized) // "1:1 문의"
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showWriteSheet = true }) {
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(.neonGreen)
                }
            }
        }
        .onAppear(perform: fetchInquiries)
        .sheet(isPresented: $showWriteSheet) {
            InquiryWriteView(onSuccess: {
                showWriteSheet = false
                fetchInquiries()
            })
        }
    }
    
    private func fetchInquiries() {
        isLoading = true
        APIService.shared.fetchMyInquiries { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let data):
                    self.inquiries = data
                case .failure(let error):
                    print("Error fetching inquiries: \(error)")
                }
            }
        }
    }
}

// MARK: - Inquiry Row
struct InquiryRow: View {
    let inquiry: Inquiry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(inquiry.category.localized)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.neonGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.neonGreen.opacity(0.1))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Text(inquiry.status.localized)
                        .font(.caption)
                        .foregroundColor(inquiry.status == .answered ? .neonGreen : .gray)
                }
                
                Text(inquiry.content)
                    .font(.body)
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)
                
                Text(formatDate(inquiry.createdAt))
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            
            if inquiry.status == .answered && !(inquiry.isReadByUser ?? false) {
                 Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            }
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding()
        .background(Color.theme.bgLayer2)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.theme.borderPrimary, lineWidth: 1)
        )
    }
    
    private func formatDate(_ dateString: String) -> String {
        // Implement simplified date formatter
        // Assuming dateString is ISO8601
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
             let displayFormatter = DateFormatter()
             displayFormatter.dateStyle = .medium
             return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Inquiry Detail View
struct InquiryDetailView: View {
    let inquiryId: String
    @State private var inquiry: Inquiry?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.theme.bgMain.edgesIgnoringSafeArea(.all)
            
            if isLoading {
                ProgressView()
            } else if let inquiry = inquiry {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Question Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Q.")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.neonGreen)
                                Text(inquiry.category.localized)
                                    .font(.caption)
                                    .padding(6)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(4)
                                Spacer()
                                Text(formatDate(inquiry.createdAt))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Text(inquiry.content)
                                .font(.body)
                                .foregroundColor(.textPrimary)
                                .lineSpacing(4)
                        }
                        .padding()
                        .background(Color.theme.bgLayer2)
                        .cornerRadius(12)
                        
                        // Answer Section
                        if let answer = inquiry.answer {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("A.")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.cyan)
                                    Text("admin_answer".localized) // "관리자 답변"
                                        .font(.headline)
                                        .foregroundColor(.textPrimary)
                                    Spacer()
                                    if let answeredAt = inquiry.answeredAt {
                                        Text(formatDate(answeredAt))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Divider().background(Color.gray)
                                
                                Text(answer)
                                    .font(.body)
                                    .foregroundColor(.textPrimary)
                                    .lineSpacing(4)
                            }
                            .padding()
                            .background(Color.theme.bgLayer2)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                            )
                        } else {
                            HStack {
                                Spacer()
                                Text("waiting_for_answer".localized)
                                    .foregroundColor(.gray)
                                    .padding()
                                Spacer()
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("inquiry_detail".localized)
        .onAppear(perform: fetchDetail)
    }
    
    private func fetchDetail() {
        APIService.shared.getInquiryDetail(id: inquiryId) { result in
             DispatchQueue.main.async {
                 isLoading = false
                 switch result {
                 case .success(let data):
                     self.inquiry = data
                 case .failure(let error):
                     print("Error: \(error)")
                 }
             }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
             let displayFormatter = DateFormatter()
             displayFormatter.dateStyle = .medium
             displayFormatter.timeStyle = .short
             return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Inquiry Write View
struct InquiryWriteView: View {
    var onSuccess: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedCategory: Inquiry.Category = .bug
    @State private var content: String = ""
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.bgMain.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    // Category Picker
                    VStack(alignment: .leading) {
                        /* Text("category".localized) REMOVED */
                        
                        Picker("Category", selection: $selectedCategory) {
                            ForEach(Inquiry.Category.allCases, id: \.self) { category in
                                Text(category.localized).tag(category)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding()
                    
                    // Content Editor
                    VStack(alignment: .leading) {
                        Text("content".localized)
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        
                        TextEditor(text: $content)
                            .scrollContentBackground(.hidden)
                            .background(Color.theme.bgLayer2)
                            .cornerRadius(8)
                            .foregroundColor(.textPrimary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.theme.borderPrimary, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    
                    Spacer()
                }
            }
            .navigationTitle("new_inquiry".localized)
            .navigationBarItems(
                leading: Button("cancel".localized) { presentationMode.wrappedValue.dismiss() },
                trailing: Button("save".localized) { submit() }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            )
        }
    }
    
    private func submit() {
        isSubmitting = true
        APIService.shared.createInquiry(category: selectedCategory, content: content) { result in
            DispatchQueue.main.async {
                isSubmitting = false
                switch result {
                case .success:
                    onSuccess()
                case .failure(let error):
                    print("Submit Error: \(error)")
                }
            }
        }
    }
}
