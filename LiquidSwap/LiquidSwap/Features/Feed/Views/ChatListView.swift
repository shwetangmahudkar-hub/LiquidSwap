import SwiftUI

struct ChatListView: View {
    @ObservedObject var chatManager = ChatManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackground()
                
                VStack(spacing: 0) {
                    // --- HEADER ---
                    HStack {
                        Text("Messages")
                            .font(.largeTitle).bold()
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            
                            // 1. NEW MATCHES ROW (Tinder Style)
                            // (Using the same conversation data for now, but styled differently)
                            if !chatManager.conversations.isEmpty {
                                Text("New Matches")
                                    .font(.headline)
                                    .foregroundStyle(.cyan)
                                    .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(Array(chatManager.conversations.keys), id: \.self) { partnerId in
                                            NavigationLink(destination: ChatRoomView(partnerId: partnerId)) {
                                                VStack {
                                                    // Large Avatar
                                                    Circle()
                                                        .fill(LinearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom))
                                                        .frame(width: 70, height: 70)
                                                        .overlay(
                                                            Circle().stroke(Color.white, lineWidth: 2)
                                                        )
                                                        .overlay(Text(partnerId.uuidString.prefix(1)).font(.title2).bold().foregroundStyle(.white))
                                                        .shadow(radius: 5)
                                                    
                                                    Text("User")
                                                        .font(.caption).bold()
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            // 2. MESSAGES LIST
                            Text("Conversations")
                                .font(.headline)
                                .foregroundStyle(.cyan)
                                .padding(.horizontal)
                            
                            if chatManager.conversations.isEmpty {
                                EmptyChatState()
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(chatManager.conversations.keys), id: \.self) { partnerId in
                                        NavigationLink(destination: ChatRoomView(partnerId: partnerId)) {
                                            GlassChatRow(partnerId: partnerId)
                                        }
                                        Divider().background(Color.white.opacity(0.1))
                                    }
                                }
                                .background(.ultraThinMaterial)
                                .cornerRadius(20)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top, 10)
                    }
                }
            }
            .task { await chatManager.setup() }
            .refreshable { await chatManager.fetchAllMessages() }
        }
    }
}

// --- SUBVIEWS ---

struct GlassChatRow: View {
    let partnerId: UUID
    @ObservedObject var chatManager = ChatManager.shared
    
    var lastMessage: Message? {
        chatManager.conversations[partnerId]?.last
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 55, height: 55)
                .overlay(Text(partnerId.uuidString.prefix(1)).bold().foregroundStyle(.white))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Trader \(partnerId.uuidString.prefix(4))")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    if let date = lastMessage?.createdAt {
                        Text(date.formatted(.dateTime.hour().minute()))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                
                if let msg = lastMessage {
                    Text(msg.content)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .contentShape(Rectangle()) // Makes the whole row tappable
    }
}

struct EmptyChatState: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 50))
                .foregroundStyle(.white.opacity(0.3))
            Text("No messages yet")
                .foregroundStyle(.white.opacity(0.7))
            Text("Start swiping to find trades!")
                .font(.caption)
                .foregroundStyle(.gray)
            Spacer()
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
}
