import SwiftUI

struct ChatView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel: ChatViewModel
    
    init(room: Room, targetUser: User? = nil, currentUser: User? = nil) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(room: room, targetUser: targetUser, currentUser: currentUser))
    }
    
    @State private var showMenu = false
    @State private var showLeaveConfirmation = false
    
    var body: some View {
        ZStack {
            // Background
            Color.deepBlack.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Custom Header with TTL
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.neonGreen)
                    }
                    .padding(.trailing, 8)
                    
                    VStack(alignment: .leading) {
                        Text(viewModel.room.displayName)
                            .font(.radarHeadline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 4) {
                            Text("TTL 23:59:42") // Placeholder for real timer
                                .font(.radarData)
                                .foregroundColor(.signalRed)
                            
                            if let targetUser = viewModel.targetUser {
                                Text("•")
                                    .foregroundColor(.textSecondary)
                                Text(viewModel.isTargetUserActive ? "active".localized : "waiting_for_user".localized)
                                    .font(.radarData)
                                    .foregroundColor(viewModel.isTargetUserActive ? .neonGreen : .textSecondary)
                            }
                        }
                    }
                    Spacer()
                    
                    // Inactive Indicator
                    if let targetUser = viewModel.targetUser, !viewModel.isTargetUserActive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.textSecondary)
                                .frame(width: 8, height: 8)
                            Text("connecting".localized)
                                .font(.radarCaption)
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                    }
                    
                    // Menu Button
                    Button(action: {
                        showMenu = true
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
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
                .background(Color.glassBlack)
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
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageRow(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        scrollToBottom(proxy: proxy)
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
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(20)
                        .foregroundColor(.white)
                        .accentColor(.neonGreen)
                    
                    Button(action: {
                        viewModel.sendMessage()
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                            .padding(10)
                            .background(Color.neonGreen)
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
        if let lastId = viewModel.messages.last?.id {
            withAnimation {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}

struct MessageRow: View {
    let message: Message
    
    var isMe: Bool {
        guard let currentUserId = TokenManager.shared.userId else { return false }
        return message.userId.caseInsensitiveCompare(currentUserId) == .orderedSame
    }
    
    var body: some View {
        if message.type == "system" {
            HStack {
                Spacer()
                Text(message.content ?? "")
                    .font(.radarCaption)
                    .foregroundColor(.textSecondary)
                    .padding(.vertical, 8)
                Spacer()
            }
        } else {
            HStack(alignment: .bottom, spacing: 8) {
                if isMe { Spacer() }
                
                if !isMe {
                    // Avatar Placeholder
                    Circle()
                        .fill(Color.mysteryViolet)
                        .frame(width: 30, height: 30)
                        .overlay(Text(String((message.nickname ?? message.nicknameMask ?? "?").prefix(1))).font(.caption).foregroundColor(.white))
                }
                
                VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                    if !isMe {
                        Text(message.nicknameMask ?? message.nickname ?? "Unknown")
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
                        
                        Text(message.content ?? "")
                            .font(.radarBody)
                            .padding(12)
                            .background(isMe ? Color.neonGreen : Color.white.opacity(0.1))
                            .foregroundColor(isMe ? .black : .white)
                            .cornerRadius(16)
                            .opacity(message.localStatus == .sending ? 0.7 : 1.0)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.1), lineWidth: isMe ? 0 : 1)
                            )
                    }
                }
                
                if !isMe { Spacer() }
            }
        }
    }
}
