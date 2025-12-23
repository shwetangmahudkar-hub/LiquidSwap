import SwiftUI

struct ChatListView: View {
    @ObservedObject var chatManager = ChatManager.shared
    @ObservedObject var userManager = UserManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackground()
                
                if chatManager.conversations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray)
                        Text("No messages yet")
                            .foregroundStyle(.gray)
                        Text("Match with someone to start chatting!")
                            .font(.caption)
                            .foregroundStyle(.gray.opacity(0.8))
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 2) {
                            // Loop through all conversation partners
                            ForEach(Array(chatManager.conversations.keys), id: \.self) { partnerId in
                                NavigationLink(destination: ChatRoomView(partnerId: partnerId)) {
                                    ChatRow(partnerId: partnerId)
                                }
                                Divider().background(.white.opacity(0.1))
                            }
                        }
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .padding()
                    }
                }
            }
            .navigationTitle("Messages")
            .refreshable {
                await chatManager.fetchAllMessages()
            }
            // ADD THIS BLOCK:
            .task {
                await chatManager.setup()
            }
        }
    }
    
    struct ChatRow: View {
        let partnerId: UUID
        @ObservedObject var chatManager = ChatManager.shared
        
        var lastMessage: Message? {
            chatManager.conversations[partnerId]?.last
        }
        
        var body: some View {
            HStack(spacing: 16) {
                // Avatar Placeholder
                Circle()
                    .fill(Color.cyan.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(Image(systemName: "person.fill").foregroundStyle(.white))
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        // In a real app, we would fetch the partner's Name here
                        Text("User \(partnerId.uuidString.prefix(4))")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    
                    if let msg = lastMessage {
                        Text(msg.content)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
            }
            .padding()
            .contentShape(Rectangle())
        }
    }
}
