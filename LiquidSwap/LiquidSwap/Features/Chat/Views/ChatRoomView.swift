import SwiftUI

struct ChatRoomView: View {
    let partnerId: UUID
    
    @ObservedObject var chatManager = ChatManager.shared
    @State private var newMessageText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            let messages = chatManager.conversations[partnerId] ?? []
                            
                            ForEach(messages, id: \.id) { message in
                                MessageBubble(message: message)
                            }
                            
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding()
                    }
                    // FIXED: iOS 17 onChange Syntax
                    .onChange(of: chatManager.conversations[partnerId]) { oldValue, newValue in
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                
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
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func sendMessage() {
        guard !newMessageText.isEmpty else { return }
        let textToSend = newMessageText
        newMessageText = ""
        
        Task {
            await chatManager.sendMessage(textToSend, to: partnerId)
        }
    }
}

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
            if !message.isCurrentUser { Spacer() }
        }
    }
}
