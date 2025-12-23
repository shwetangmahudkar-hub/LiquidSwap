import SwiftUI

struct ChatListView: View {
    @ObservedObject var chatManager = ChatManager.shared
    
    // Mock List of People (Ideally this would come from your Matches)
    let activeChats = ["Sarah J.", "Mike R.", "Alex T."]
    
    var body: some View {
        ZStack {
            LiquidBackground()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Messages")
                        .font(.largeTitle)
                        .bold()
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                        .padding(.top, 20)
                    
                    VStack(spacing: 2) {
                        ForEach(activeChats, id: \.self) { partner in
                            NavigationLink(value: ChatRoomRoute(partnerName: partner)) {
                                ChatRow(partner: partner)
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
        .navigationTitle("") // Hide default
    }
}

struct ChatRow: View {
    let partner: String
    @ObservedObject var chatManager = ChatManager.shared
    
    var lastMessage: String {
        chatManager.conversations[partner]?.last?.content ?? "No messages yet"
    }
    
    var timeString: String {
        if let date = chatManager.conversations[partner]?.last?.timestamp {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return "Now"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar Placeholder
            Circle()
                .fill(Color.cyan.opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay(Text(partner.prefix(1)).bold().foregroundStyle(.white))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(partner)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(timeString)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Text(lastMessage)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .padding()
        .contentShape(Rectangle()) // Make full row tappable
    }
}
