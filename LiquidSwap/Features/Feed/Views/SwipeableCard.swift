import SwiftUI

// 1. Define the Enum here so it is available to FeedView too
enum SwipeDirection {
    case left
    case right
}

struct SwipeableCard: View {
    let item: TradeItem
    
    // 2. Closure to tell the parent (FeedView) when a swipe finishes
    var onSwipe: (SwipeDirection) -> Void
    
    @State private var offset = CGSize.zero
    
    var body: some View {
        ZStack {
            // Background Card
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6))
                .shadow(radius: 4)
            
            // Image Layer - FIXED: Uses imageUrl
            AsyncImageView(filename: item.imageUrl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .cornerRadius(20)
            
            // Gradient Overlay
            LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
                .cornerRadius(20)
            
            // ✨ NEW: Donation/Free Badge
            if item.isDonation {
                VStack {
                    HStack {
                        Spacer()
                        Text("FREE")
                            .font(.headline)
                            .fontWeight(.heavy)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.green) // Matches the "Post Donation" button
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            )
                            .padding(16)
                    }
                    Spacer()
                }
            }
            
            // Text Info
            VStack(alignment: .leading) {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.title)
                            .bold()
                            .foregroundStyle(.white)
                        
                        Text("\(item.category) • \(String(format: "%.1f", item.distance)) km")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                    
                    // Info Icon
                    Image(systemName: "info.circle")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                .padding()
            }
            
            // Swipe Overlay Indicators (Like/Pass)
            if offset.width > 0 {
                // LIKE (Right)
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green.opacity(0.8))
                    .opacity(Double(offset.width / 150))
            } else if offset.width < 0 {
                // PASS (Left)
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.red.opacity(0.8))
                    .opacity(Double(abs(offset.width) / 150))
            }
        }
        .offset(x: offset.width, y: offset.height * 0.4)
        .rotationEffect(.degrees(Double(offset.width / 20)))
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    offset = gesture.translation
                }
                .onEnded { _ in
                    withAnimation {
                        swipeCard()
                    }
                }
        )
    }
    
    // Logic to decide if card flies away or snaps back
    func swipeCard() {
        if offset.width > 150 {
            // Swipe Right
            offset = CGSize(width: 500, height: 0)
            onSwipe(.right)
        } else if offset.width < -150 {
            // Swipe Left
            offset = CGSize(width: -500, height: 0)
            onSwipe(.left)
        } else {
            // Snap Back
            offset = .zero
        }
    }
}
