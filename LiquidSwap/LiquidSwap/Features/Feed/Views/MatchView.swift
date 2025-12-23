import SwiftUI

struct MatchView: View {
    let item: TradeItem
    var onChat: () -> Void
    var onKeepSwiping: () -> Void
    
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // 1. Frosted Glass Background (Darker)
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .opacity(0.95)
            
            // 2. Liquid Splash Effects
            LiquidBackground()
                .opacity(0.3)
            
            VStack(spacing: 30) {
                // Title Animation
                Text("It's a Match!")
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(.white)
                    .scaleEffect(animate ? 1.0 : 0.5)
                    .opacity(animate ? 1.0 : 0.0)
                    .shadow(color: .cyan, radius: 20)
                
                Text("You and \(item.ownerName) like each other's items.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Item Images Collision Animation
                HStack(spacing: -30) {
                    // Your Item (Placeholder)
                    Circle()
                        .fill(Color.purple.opacity(0.5))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "cube.box.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.white)
                        )
                        .overlay(Circle().stroke(.white, lineWidth: 4))
                        .offset(x: animate ? 0 : -100)
                    
                    // Their Item
                    Circle()
                        .fill(item.color.opacity(0.5))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: item.systemImage)
                                .font(.system(size: 50))
                                .foregroundStyle(.white)
                        )
                        .overlay(Circle().stroke(.white, lineWidth: 4))
                        .offset(x: animate ? 0 : 100)
                }
                .padding(.vertical, 40)
                
                // Action Buttons
                VStack(spacing: 16) {
                    Button(action: onChat) {
                        Text("Send a Message")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.cyan)
                            .cornerRadius(30)
                            .foregroundStyle(.black)
                    }
                    
                    Button(action: onKeepSwiping) {
                        Text("Keep Swiping")
                            .bold()
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 40)
                .opacity(animate ? 1.0 : 0.0)
                .offset(y: animate ? 0 : 50)
            }
        }
        // CORRECT PLACEMENT of onAppear
        .onAppear {
            // Trigger Haptics
            Haptics.shared.playSuccess()
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                animate = true
            }
        }
    }
}

#Preview {
    MatchView(
        item: TradeItem.mockData[0],
        onChat: {},
        onKeepSwiping: {}
    )
}
