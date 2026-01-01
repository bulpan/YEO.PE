import SwiftUI

struct ChatView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel: ChatViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    
    init(room: Room, targetUser: User? = nil, currentUser: User? = nil) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(room: room, targetUser: targetUser, currentUser: currentUser))
    }
    
    @State private var reportTargetUser: User?
    @State private var showMenu = false
    @State private var showLeaveConfirmation = false
    
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
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.displayTitle)
                            .font(.radarHeadline)
                            .foregroundColor(Color.theme.textPrimary)
                            .lineLimit(1)
                        
                        if let targetUser = viewModel.targetUser {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(viewModel.isTargetUserActive ? Color.theme.accentPrimary : Color.textSecondary)
                                    .frame(width: 6, height: 6)
                                Text(viewModel.isTargetUserActive ? "active".localized : "waiting_for_user".localized)
                                    .font(.radarCaption)
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
                            .font(.system(size: 24))
                            .foregroundColor(Color.theme.textPrimary)
                    }
                    .actionSheet(isPresented: $showMenu) {
                        ActionSheet(
                            title: Text("chat_menu".localized),
                            buttons: [
                                .destructive(Text("leave_room".localized)) {
                                    showLeaveConfirmation = true
                                },
                                .cancel()
                            ]
                        )
                    }
                }
                .padding()
                .background(Color.theme.bgLayer1)
                .alert(isPresented: $showLeaveConfirmation) {
                    Alert(
                        title: Text("leave_room".localized),
                        message: Text("leave_room_confirm".localized),
                        primaryButton: .destructive(Text("leave".localized)) {
                            viewModel.exitRoom { success in
                                if success {
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }
                        },
                        secondaryButton: .cancel()
                    )
                }
                .sheet(item: $reportTargetUser) { user in
                    ReportSheet(
                        targetUserId: user.id,
                        targetUserNickname: user.nickname ?? "Unknown",
                        onReport: { reason, details in
                            viewModel.reportUser(userId: user.id, reason: reason, details: details) { _ in }
                        },
                        onBlock: {
                            viewModel.blockUser(userId: user.id) { success in
                                if success {
                                    // If handling 1:1 specifically, might want to exit?
                                    // For now, blocking simply removes them locally and prevents future messages.
                                }
                            }
                        }
                    )
                }
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                let sender = viewModel.members.first(where: { $0.id == message.userId })
                                MessageRow(message: message, sender: sender, onAvatarTap: { tappedUser in
                                    reportTargetUser = tappedUser
                                })
                                .id(message.id)
                            }
                        }
                        .padding()
                        .padding(.bottom, 10) // Extra padding for safety
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        // Use async to allow layout to settle before scrolling
                        DispatchQueue.main.async {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                        // Delay slightly to allow keyboard to fully appear
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }
                
                // Input Area
                HStack(spacing: 12) {
                    TextField("type_message".localized, text: $viewModel.newMessageText)
                        .padding(12)
                        .background(Color.textPrimary.opacity(0.1))
                        .cornerRadius(20)
                        .foregroundColor(.textPrimary)
                        .accentColor(.neonGreen)
                    
                    Button(action: {
                        viewModel.sendMessage()
                        // Force scroll after sending
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // Cannot access proxy here easily without refactoring, 
                            // but onChange(messages.count) handles it IF message is appended.
                            // The optimize update in ViewModel appends it, so onChange fires.
                        }
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 20))
                            .foregroundColor(ThemeManager.shared.isDarkMode ? .black : .white) // Black on Green, White on DarkGray
                            .padding(10)
                            .background(Color.neonGreen) // LightMode: DarkGray, DarkMode: NeonGreen
                            .clipShape(Circle())
                    }
                }
                .padding()
                .background(Color.glassBlack)
            }
        }
        .navigationBarHidden(true) // Hide default nav bar for custom header
        .onAppear {
            viewModel.joinRoom()
        }
        .onDisappear {
            viewModel.updatePresence()
            viewModel.leaveRoom()
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        // Guard against empty
        guard let lastId = viewModel.messages.last?.id else { return }
        
        // Scroll immediately with animation
        withAnimation {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
        
        // Double check a split second later for reliable "sticking"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
             withAnimation {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
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
        // If sender is known, respect their setting. Default to true (Masked) if generic preference?
        // User said: "If I set it to mask... show masked. If unset... show real."
        // App default is true.
        return sender?.settings?.maskId ?? false
    }
    
    var body: some View {
        if message.type == "system" {
            if isMe {
                // Hide "I joined" or "I left" system messages for the user themselves
                EmptyView()
            } else {
                HStack {
                    Spacer()
                    // Privacy Fix: Replace nickname with mask if preferred
                    // Privacy Fix & Localization
                    let displayContent: String = {
                        let original = message.content ?? ""
                        let displayName = shouldMask ? (message.nicknameMask ?? (message.nickname ?? "Unknown")) : (message.nickname ?? "Unknown")
                        
                        // Check for known server patterns
                        if original.contains("joined the room") {
                            // Try to extract name if variable, but since we have known nickname/mask, we can just reconstruct.
                            // Assuming the message is just "{Name} joined the room"
                            return String(format: "sys_joined_room".localized, displayName)
                        } else if original.contains("messages have evaporated") {
                            return String(format: "sys_msg_evaporated".localized, displayName)
                        }
                        
                        // Fallback: If no pattern matches, at least try to mask the name in the original string
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
            HStack(alignment: .bottom, spacing: 8) {
                if isMe { Spacer() }
                
                if !isMe {
                    // Avatar Placeholder
                    Button(action: {
                        if let user = sender {
                            onAvatarTap?(user)
                        } else {
                            // Create a temporary User object from message info if sender is missing
                            let tempUser = User(
                                id: message.userId,
                                email: "",
                                nickname: message.nickname ?? "Unknown",
                                nicknameMask: message.nicknameMask,
                                nickname_mask: nil,
                                settings: nil,
                                createdAt: nil,
                                lastLoginAt: nil,
                                distance: nil,
                                hasActiveRoom: false,
                                roomId: nil,
                                roomName: nil
                            )
                            onAvatarTap?(tempUser)
                        }
                    }) {
                        Circle()
                            .fill(Color.mysteryViolet)
                            .frame(width: 30, height: 30)
                            .overlay(Text(String((shouldMask ? (message.nicknameMask ?? "?") : (message.nickname ?? "?")).prefix(1))).font(.caption).foregroundColor(.white))
                    }
                }
                
                VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                    if !isMe {
                        Text(shouldMask ? (message.nicknameMask ?? "Unknown") : (message.nickname ?? "Unknown"))
                            .font(.radarCaption)
                            .foregroundColor(.textSecondary)
                    }
                    
                    HStack(alignment: .bottom, spacing: 4) {
                        if isMe {
                            if message.localStatus == .sending {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 15, height: 15)
                            }
                        }
                        
                        Text(shouldMask ? (message.content ?? "") : (message.content ?? "")) // Content usually doesn't need masking unless it mentions name? Message content is message content.
                            .font(.radarBody)
                            .padding(12)
                            .background(
                                isMe ? 
                                    (ThemeManager.shared.isDarkMode ? Color.neonGreen : Color.textPrimary.opacity(0.1)) 
                                    : Color.textPrimary.opacity(0.1)
                            )
                            .foregroundColor(
                                isMe ? 
                                    (ThemeManager.shared.isDarkMode ? .black : .textPrimary) 
                                    : (ThemeManager.shared.isDarkMode ? .white : .black) // Force black in Light Mode for other
                            )
                            .cornerRadius(16)
                            .opacity(message.localStatus == .sending ? 0.7 : 1.0)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.textPrimary.opacity(0.1), lineWidth: isMe ? 0 : 1)
                            )
                    }
                }
                
                if !isMe { Spacer() }
            }
        }
    }
}
