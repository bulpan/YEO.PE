import SwiftUI
import Combine
import UserNotifications
import SensitiveContentAnalysis

struct ChatView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel: ChatViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    
    init(room: Room? = nil, targetUser: User? = nil, currentUser: User? = nil) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(room: room, targetUser: targetUser, currentUser: currentUser))
    }
    
    @State private var reportTargetUser: User?
    @State private var showMenu = false
    @State private var showLeaveConfirmation = false
    @State private var showImagePicker = false
    @State private var inputImage: UIImage?
    @State private var showSensitiveContentAlert = false
    
    var body: some View {
        ZStack {
            // Background
            Color.deepBlack.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color.theme.accentPrimary)
                    }
                    .padding(.trailing, 8)
                    
                    // Profile Avatar
                    if (viewModel.targetUser != nil || viewModel.room?.metadata?.category == "quick_question") {
                        if let profilePath = viewModel.displayProfileImageUrl, !profilePath.isEmpty, let url = getHeaderProfileUrl(from: profilePath) {
                            CachedAsyncImage(url: url)
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                                .padding(.trailing, 8)
                        } else {
                            Circle()
                                .fill(Color.theme.accentPrimary.opacity(0.1))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(String(viewModel.displayTitle.prefix(1)))
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color.theme.accentPrimary)
                                )
                                .padding(.trailing, 8)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.displayTitle)
                            .font(.system(size: 20, weight: .bold)) // Reduced 70% from 28
                            .foregroundColor(Color.theme.textPrimary)
                            .lineLimit(1)
                        
                        if let targetUser = viewModel.targetUser {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(viewModel.isTargetUserActive ? Color.theme.accentPrimary : Color.textSecondary)
                                    .frame(width: 6, height: 6)
                                Text(viewModel.isTargetUserActive ? "active".localized : "waiting_for_user".localized)
                                    .font(.system(size: 10)) // Reduced caption
                                    .foregroundColor(Color.theme.textSecondary)
                            }
                        }
                    }
                    Spacer()
                    
                    // Menu Button
                Button(action: {
                        showMenu = true
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 20)) // Reduced icon
                            .foregroundColor(Color.theme.textPrimary)
                    }
                }
                .padding(.horizontal, 10) // Reduced padding from default
                .padding(.vertical, 10) // Reduced height
                .background(Color.theme.bgLayer1)
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                let sender = viewModel.members.first(where: { $0.id == message.userId }) 
                                ?? (viewModel.targetUser?.id == message.userId ? viewModel.targetUser : nil)
                                MessageRow(message: message, sender: sender, onAvatarTap: { tappedUser in
                                    reportTargetUser = tappedUser
                                })
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal, 8) // Reduced 50% (approx 16 -> 8)
                        .padding(.vertical, 10)
                    }
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        DispatchQueue.main.async {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }
                
                // Input Area
                HStack(spacing: 12) {
                    TextField(viewModel.isTargetUserActive ? "type_message".localized : "user_has_left".localized, text: $viewModel.newMessageText)
                        .padding(12)
                        .background(Color.textPrimary.opacity(0.1))
                        .cornerRadius(20)
                        .foregroundColor(.textPrimary)
                        .accentColor(.neonGreen)
                        .disabled(!viewModel.isTargetUserActive)
                    
                    // Image Picker Button
                    Button(action: {
                        showImagePicker = true
                    }) {
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundColor(Color.theme.textSecondary)
                            .padding(10)
                    }
                    .disabled(!viewModel.isTargetUserActive)
                    .opacity(viewModel.isTargetUserActive ? 1.0 : 0.5)
                    
                    Button(action: {
                        viewModel.sendMessage()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // Scroll handled by onChange
                        }
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 20))
                            .foregroundColor(ThemeManager.shared.isDarkMode ? .black : .white)
                            .padding(10)
                            .background(viewModel.isTargetUserActive ? Color.neonGreen : Color.gray)
                            .clipShape(Circle())
                    }
                    .disabled(!viewModel.isTargetUserActive)
                }
                .padding()
                .background(Color.glassBlack)
                
            }
            
            // Loading Overlay
            if viewModel.isLoading {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
            
            // Custom Confirmation Overlay (Replaces System Alert)
            if showLeaveConfirmation {
                Color.black.opacity(0.6)
                    .edgesIgnoringSafeArea(.all)
                    // High ZIndex to ensure it's on top of everything including NavBars
                    .zIndex(998)
                    .onTapGesture {
                        withAnimation { showLeaveConfirmation = false }
                    }
                
                VStack(spacing: 20) {
                    Text("leave_room".localized)
                        .font(.headline)
                        .foregroundColor(Color.theme.textPrimary)
                    
                    Text("leave_room_confirm".localized)
                        .font(.subheadline)
                        .foregroundColor(Color.theme.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            NSLog("🚫 [ChatView] Custom Overlay Cancel tapped")
                            withAnimation { showLeaveConfirmation = false }
                        }) {
                            Text("cancel".localized)
                                .foregroundColor(Color.theme.textPrimary)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.theme.borderPrimary, lineWidth: 1)
                                )
                        }
                        
                        Button(action: {
                            NSLog("🚀 [ChatView] Custom Overlay Leave tapped")
                            withAnimation { showLeaveConfirmation = false }
                            viewModel.exitRoom { success in
                                NSLog("👋 [ChatView] exitRoom completion: \(success)")
                                if success {
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }
                        }) {
                            Text("leave".localized)
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .background(Color.theme.signalRed)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(24)
                .background(Color.theme.bgLayer1)
                .cornerRadius(16)
                .shadow(radius: 20)
                .padding(.horizontal, 40)
                .zIndex(999) // Strictly on top
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.joinRoom()
            // Clear app icon badge when entering chat
            UNUserNotificationCenter.current().setBadgeCount(0)
        }
        .onDisappear {
            viewModel.leaveRoom()
        }
        // MARK: - Global ActionSheet & Sheets
        .actionSheet(isPresented: $showMenu) {
            ActionSheet(
                title: Text("chat_menu".localized),
                buttons: [
                    .destructive(Text("leave_room".localized)) {
                        NSLog("👆 [ChatView] Leave Room button tapped")
                        // Show visible overlay immediately
                        withAnimation {
                            showLeaveConfirmation = true
                        }
                    },
                    .cancel()
                ]
            )
        }
        .sheet(item: $reportTargetUser) { user in
            ReportSheet(
                targetUserId: user.id,
                targetUserNickname: user.nickname ?? "Unknown",
                onReport: { reason, details, completion in
                    viewModel.reportUser(userId: user.id, reason: reason, details: details) { success in
                        completion(success)
                    }
                },
                onBlock: {
                    viewModel.blockUser(userId: user.id) { success in
                        if success {
                            // Handle block success if needed
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: .photoLibrary) { image in
                self.inputImage = image
                
                // IOS 17+ Sensitive Content Analysis
                if #available(iOS 17.0, *) {
                    Task {
                        do {
                            let analyzer = SCSensitivityAnalyzer()
                            let policy = analyzer.analysisPolicy
                            
                            if policy == .disabled {
                                viewModel.uploadImage(image) // Feature disabled by user/system
                            } else {
                                // Convert UIImage to CGImage for analysis
                                if let cgImage = image.cgImage {
                                    let analysis = try await analyzer.analyzeImage(cgImage)
                                    
                                    if analysis.isSensitive {
                                        // Sensitive Content Detected!
                                        DispatchQueue.main.async {
                                            print("🚨 Sensitive Content Detected! Upload Blocked.")
                                            showSensitiveContentAlert = true
                                        }
                                    } else {
                                        viewModel.uploadImage(image)
                                    }
                                } else {
                                    viewModel.uploadImage(image)
                                }
                            }
                        } catch {
                            print("Analysis failed: \(error)")
                            viewModel.uploadImage(image) // Fail open or closed? Fail open for now to avoid bugs blocking legit users.
                        }
                    }
                } else {
                    // Fallback for older iOS
                    viewModel.uploadImage(image)
                }
            }
        }
        .alert(isPresented: $showSensitiveContentAlert) {
            Alert(
                title: Text("blocked".localized),
                message: Text("report_inappropriate".localized),
                dismissButton: .default(Text("ok".localized))
            )
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastId = viewModel.messages.last?.id else { return }
        
        withAnimation {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
    
    private func getHeaderProfileUrl(from path: String) -> URL? {
        var baseUrl = AppConfig.baseURL
        if baseUrl.hasPrefix("ws://") { baseUrl = baseUrl.replacingOccurrences(of: "ws://", with: "http://") }
        else if baseUrl.hasPrefix("wss://") { baseUrl = baseUrl.replacingOccurrences(of: "wss://", with: "https://") }
        
        let fullUrl = path.hasPrefix("http") ? path : "\(baseUrl)\(path)"
        return URL(string: fullUrl)
    }
}

struct MessageRow: View {
    let message: Message
    let sender: User?
    var onAvatarTap: ((User) -> Void)? = nil
    
    var isMe: Bool {
        guard let currentUserId = TokenManager.shared.userId else { return false }
        return message.userId.caseInsensitiveCompare(currentUserId) == .orderedSame
    }
    
    var shouldMask: Bool {
        return sender?.settings?.maskId ?? false
    }
    
    // Time Formatter
    private var formattedTime: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        func format(_ date: Date) -> String {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "ko_KR")
            displayFormatter.dateFormat = "a h:mm"
            return displayFormatter.string(from: date)
        }
        
        if let date = formatter.date(from: message.createdAt) {
            return format(date)
        }
        
        // Fallback for standard ISO without fractional
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: message.createdAt) {
            return format(date)
        }
        
        return ""
    }
    
    var fallbackAvatar: some View {
        Circle()
            .fill(Color.mysteryViolet)
            .frame(width: 30, height: 30)
            .overlay(Text(String((shouldMask ? (message.nicknameMask ?? "?") : (message.nickname ?? "?")).prefix(1))).font(.caption).foregroundColor(.white))
    }
    
    private func getProfileUrl(from path: String) -> URL? {
        var baseUrl = AppConfig.baseURL
        if baseUrl.hasPrefix("ws://") { baseUrl = baseUrl.replacingOccurrences(of: "ws://", with: "http://") }
        else if baseUrl.hasPrefix("wss://") { baseUrl = baseUrl.replacingOccurrences(of: "wss://", with: "https://") }
        
        let fullUrl = path.hasPrefix("http") ? path : "\(baseUrl)\(path)"
        return URL(string: fullUrl)
    }
    
    var body: some View {
        if message.type == "system" {
            if isMe {
                EmptyView()
            } else {
                HStack {
                    Spacer()
                    let displayContent: String = {
                        let original = message.content ?? ""
                        
                        // Improved Nickname Resolution:
                        // If sender is nil (user left), 'shouldMask' is false, falling back to 'message.nickname'.
                        // But 'message.nickname' might be "Unknown" if server joined failed.
                        // We should try 'message.nicknameMask' if 'message.nickname' seems invalid.
                        var displayName = message.nickname ?? "Unknown"
                        
                        // If nickname is missing/Unknown, try mask
                        if (displayName == "Unknown" || displayName.isEmpty), let mask = message.nicknameMask, !mask.isEmpty {
                            displayName = mask
                        }
                        // Or if we should mask (normal case)
                        else if shouldMask {
                             displayName = message.nicknameMask ?? displayName
                        }
                        
                        if original.contains("joined the room") {
                            return String(format: "sys_joined_room".localized, displayName)
                        } else if original.contains("messages have evaporated") {
                            return String(format: "sys_msg_evaporated".localized, displayName)
                        } else if original.contains("left the room") {
                            return String(format: "sys_left_room".localized, displayName)
                        }
                        
                        if shouldMask, let nickname = message.nickname, let mask = message.nicknameMask {
                            return original.replacingOccurrences(of: nickname, with: mask)
                        }
                        return original
                    }()
                        
                    Text(displayContent)
                        .font(.radarCaption)
                        .foregroundColor(.textSecondary)
                        .padding(.vertical, 8)
                    Spacer()
                }
            }
        } else {
            HStack(alignment: .top, spacing: 8) { // Align top (Avatar matches Nickname top)
                if isMe {
                    Spacer()
                    // Time for sent message (Left of bubble)
                    VStack {
                        Spacer()
                        Text(formattedTime)
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                            .padding(.bottom, 2)
                    }
                }
                
                if !isMe {
                    Button(action: {
                        if let user = sender {
                            onAvatarTap?(user)
                        } else {
                            // Temp user fallback
                            let tempUser = User(
                                id: message.userId,
                                 nickname: message.nickname ?? "Unknown",
                                 nicknameMask: message.nicknameMask,
                                 profileImageUrl: message.userProfileImage
                            )
                            onAvatarTap?(tempUser)
                        }
                    }) {
                        // Profile Image Logic
                        // 1. Try Message's embedded profile image (Fastest)
                        if let profilePath = message.userProfileImage, !profilePath.isEmpty, let url = getProfileUrl(from: profilePath) {
                            CachedAsyncImage(url: url)
                                .frame(width: 30, height: 30)
                                .clipShape(Circle())
                        }
                        // 2. Try Sender object (if available)
                        else if let user = sender, let profileUrl = user.fullProfileFileURL {
                            CachedAsyncImage(url: profileUrl)
                                .frame(width: 30, height: 30)
                                .clipShape(Circle())
                        } else {
                            // 3. Fallback Initials
                            fallbackAvatar
                        }
                    }
                    .padding(.top, 0) // Ensure no extra top padding affecting alignment
                }
                
                VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                    if !isMe {
                        Text(shouldMask ? (message.nicknameMask ?? "Unknown") : (message.nickname ?? "Unknown"))
                            .font(.radarCaption)
                            .foregroundColor(.textSecondary)
                    }
                    
                    HStack(alignment: .bottom, spacing: 4) {
                        if isMe, message.localStatus == .sending {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 15, height: 15)
                        }
                        
                        if message.imageUrl == nil {
                            Text(message.content ?? "")
                                .font(.system(size: 13)) // Reduced 80%
                                .padding(9) // Reduced 70%
                                .background(
                                    (isMe ? 
                                        (ThemeManager.shared.isDarkMode ? Color.neonGreen : Color.textPrimary.opacity(0.1)) 
                                        : Color.textPrimary.opacity(0.1))
                                    .clipShape(ChatBubbleShape(isMe: isMe))
                                )
                                .foregroundColor(
                                    isMe ? 
                                        (ThemeManager.shared.isDarkMode ? .black : .textPrimary) 
                                        : (ThemeManager.shared.isDarkMode ? .white : .black)
                                )
                                .opacity(message.localStatus == .sending ? 0.7 : 1.0)
                                .overlay(
                                    ChatBubbleShape(isMe: isMe)
                                        .stroke(Color.textPrimary.opacity(0.1), lineWidth: isMe ? 0 : 1)
                                )
                        }
                        
                        if let imageUrl = message.imageUrl, let url = URL(string: AppConfig.baseURL + imageUrl) {
                            CachedAsyncImage(url: url)
                                .frame(maxWidth: 200, maxHeight: 200)
                                .aspectRatio(contentMode: .fill)
                                .cornerRadius(12)
                        }
                        
                        // [Fix] Time moved inside HStack to hug the bubble, ignoring long nicknames
                        if !isMe {
                            Text(formattedTime)
                                .font(.caption2)
                                .foregroundColor(.textSecondary)
                                .padding(.bottom, 2)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: isMe ? .trailing : .leading)
        }
    }
}

// Custom Bubble Shape for "Tail" effect
struct ChatBubbleShape: Shape {
    var isMe: Bool
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [
                .bottomLeft,
                .bottomRight,
                isMe ? .topLeft : .topRight
            ],
            cornerRadii: CGSize(width: 16, height: 16)
        )
        // The "missing" corner (isMe ? topRight : topLeft) remains sharp (radius 0), creating the "tail" effect.
        return Path(path.cgPath)
    }
}
