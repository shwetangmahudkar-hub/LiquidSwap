import SwiftUI

struct SwipeableCard: View {
    let item: TradeItem
    var onRemove: (SwipeDirection) -> Void
    var onTap: () -> Void
    
    @State private var offset = CGSize.zero
    
    var body: some View {
        ZStack {
            GlassCard {
                VStack(alignment: .leading, spacing: 20) {
                    ZStack {
                        // Background Color
                        RoundedRectangle(cornerRadius: 15)
                            .fill(item.color.opacity(0.3))
                            .frame(height: 320)
                        
                        // Smart Image Loader
                        AsyncImageView(item: item)
                            .frame(height: 320) // Match the background height
                            .clipped()          // Ensure it doesn't spill out
                            .cornerRadius(15)   // Match the rounding
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.category.uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.cyan)
                            .tracking(2)
                        
                        Text(item.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.caption)
                            Text(item.distance)
                                .font(.subheadline)
                            Spacer()
                            Text("Owned by \(item.ownerName)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .overlay(
                ZStack {
                    if offset.width > 0 {
                        Text("LIKE")
                            .font(.largeTitle)
                            .fontWeight(.heavy)
                            .foregroundStyle(.green)
                            .rotationEffect(.degrees(-15))
                            .offset(x: -80, y: -100)
                            .opacity(Double(offset.width / 150))
                    } else if offset.width < 0 {
                        Text("NOPE")
                            .font(.largeTitle)
                            .fontWeight(.heavy)
                            .foregroundStyle(.red)
                            .rotationEffect(.degrees(15))
                            .offset(x: 80, y: -100)
                            .opacity(Double(abs(offset.width) / 150))
                    }
                }
            )
        }
        .rotationEffect(.degrees(Double(offset.width / 20)))
        .offset(x: offset.width, y: offset.height * 0.4)
        .opacity(2 - Double(abs(offset.width / 100)))
        // --- GESTURE LOGIC START ---
        // 1. Tap Gesture (Simultaneous so it doesn't block Drag)
        .simultaneousGesture(
            TapGesture().onEnded {
                // Only trigger tap if we haven't dragged much
                if abs(offset.width) < 5 && abs(offset.height) < 5 {
                    onTap()
                }
            }
        )
        // 2. Drag Gesture (High Priority so it starts instantly)
        .highPriorityGesture(
            DragGesture()
                .onChanged { gesture in
                    offset = gesture.translation
                }
                .onEnded { _ in
                    if abs(offset.width) > 100 {
                        // Swipe Success
                        Haptics.shared.playMedium()
                        let direction: SwipeDirection = offset.width > 0 ? .right : .left
                        onRemove(direction)
                    } else {
                        // Snap Back
                        Haptics.shared.playLight()
                        withAnimation(.spring()) {
                            offset = .zero
                        }
                    }
                }
        )
        // --- GESTURE LOGIC END ---
    }
}
