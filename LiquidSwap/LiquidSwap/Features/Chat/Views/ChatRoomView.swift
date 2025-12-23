import SwiftUI

struct ChatRoomView: View {
    let tradePartnerName: String
    @ObservedObject var chatManager = ChatManager.shared
    @State private var newMessageText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(tradePartnerName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "video.fill")
                        .foregroundStyle(.cyan)
                        .padding(.trailing, 16)
                    Image(systemName: "phone.fill")
                        .foregroundStyle(.cyan)
                }
                .padding()
                .background(.ultraThinMaterial)
                
                // Message List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            let messages = chatManager.conversations[tradePartnerName] ?? []
                            
                            if messages.isEmpty {
                                Text("This is the start of your conversation with \(tradePartnerName).")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                    .padding(.top, 40)
                            }
                            
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: chatManager.conversations[tradePartnerName]) { _ in
                        if let lastId = chatManager.conversations[tradePartnerName]?.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Input Bar
                HStack {
                    TextField("Message...", text: $newMessageText)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(20)
                        .foregroundStyle(.white)
                        .focused($isFocused)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.cyan)
                    }
                    .disabled(newMessageText.isEmpty)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
    }
    
    func sendMessage() {
        guard !newMessageText.isEmpty else { return }
        chatManager.sendMessage(newMessageText, to: tradePartnerName)
        newMessageText = ""
        // Keep focus if you want, or dismiss:
        // isFocused = false
    }
}

// Subview for Bubbles
struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isCurrentUser { Spacer() }
            
            Text(message.content)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(message.isCurrentUser ? Color.cyan : Color.white.opacity(0.15))
                .foregroundStyle(.white)
                .cornerRadius(16)
                .padding(.horizontal, 4) // Tiny gap
            
            if !message.isCurrentUser { Spacer() }
        }
    }
}
