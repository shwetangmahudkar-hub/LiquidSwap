import SwiftUI

struct MatchView: View {
    var item: TradeItem
    @Binding var showMatch: Bool
    
    // 1. Get the ChatManager
    @ObservedObject var chatManager = ChatManager.shared
    
    var body: some View {
        ZStack {
            // Dark Overlay
            Color.black.opacity(0.85).ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Celebration Text
                Text("It's a Match!")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: .cyan.opacity(0.5), radius: 10)
                
                // The Item Image
                // FIXED: Uses 'imageUrl' for Cloud images
                AsyncImageView(filename: item.imageUrl)
                    .frame(width: 250, height: 250)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 4
                            )
                    )
                    .shadow(color: .purple.opacity(0.5), radius: 20)
                
                Text("You matched with this \(item.title)!")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                // Action Buttons
                VStack(spacing: 16) {
                    Button(action: {
                        startChat()
                    }) {
                        Text("Send Message")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.cyan)
                            .cornerRadius(12)
                    }
                    
                    Button(action: { showMatch = false }) {
                        Text("Keep Swiping")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }
    
    // MARK: - Logic
    
    func startChat() {
        Task {
            // 1. Send an initial greeting
            let greeting = "Hi! I matched with your \(item.title)!"
            
            // 2. Send to the Item's Owner (Cloud)
            await chatManager.sendMessage(greeting, to: item.ownerId)
            
            // 3. Close the Match Screen
            showMatch = false
            
            // Note: The new chat will now appear in your 'Messages' tab!
        }
    }
}

#Preview {
    MatchView(item: TradeItem.generateMockItems()[0], showMatch: .constant(true))
}
