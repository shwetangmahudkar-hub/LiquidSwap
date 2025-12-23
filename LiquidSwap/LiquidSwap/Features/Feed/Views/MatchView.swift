import SwiftUI

struct MatchView: View {
    var item: TradeItem
    @Binding var showMatch: Bool
    
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
                
                // The Item Image - FIXED: Uses imageUrl
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
                        // In a real app, go to chat
                        showMatch = false
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
}

#Preview {
    MatchView(item: TradeItem.generateMockItems()[0], showMatch: .constant(true))
}
