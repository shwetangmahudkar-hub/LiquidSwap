import SwiftUI

// Ensure SwipeDirection is defined
enum CardSwipeDirection {
    case left
    case right
}

struct FeedView: View {
    @StateObject var feedManager = FeedManager()
    @ObservedObject var tradeManager = TradeManager.shared // NEW: Observe TradeManager for errors
    
    @State private var showMatchAnimation = false
    @State private var matchedItem: TradeItem?
    
    // State to track the last swipe direction for button animations
    @State private var lastSwipeDirection: CardSwipeDirection = .left
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. Theme Background
                LiquidBackground()
                
                VStack(spacing: 0) {
                    // --- HEADER ---
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.cyan)
                            .font(.title2)
                        Text("LiquidSwap")
                            .font(.title2).bold()
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    
                    // --- MAIN CARD STACK ---
                    GeometryReader { geometry in
                        ZStack {
                            if feedManager.isLoading {
                                ProgressView().tint(.cyan)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else if feedManager.items.isEmpty {
                                EmptyFeedState()
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                            } else {
                                // Loop through items
                                ForEach(feedManager.items.suffix(3)) { item in
                                    let isTop = feedManager.items.last?.id == item.id
                                    
                                    if isTop {
                                        // TOP CARD: Interactive & Draggable
                                        DraggableCard(item: item) { direction in
                                            lastSwipeDirection = direction
                                            handleSwipe(direction: direction, item: item)
                                        }
                                        .frame(width: geometry.size.width - 32, height: geometry.size.height)
                                        .zIndex(100) // Always on top
                                        .transition(.asymmetric(
                                            insertion: .identity,
                                            removal: .move(edge: lastSwipeDirection == .left ? .leading : .trailing)
                                        ))
                                    } else {
                                        // BACKGROUND CARDS: Static
                                        TinderGlassCard(item: item)
                                            .frame(width: geometry.size.width - 32, height: geometry.size.height)
                                            .zIndex(Double(feedManager.items.firstIndex(where: { $0.id == item.id }) ?? 0))
                                            .scaleEffect(0.95) // Subtle depth effect
                                            .offset(y: 10) // Peek out from behind
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding(.vertical, 10)
                    
                    // --- BOTTOM ACTION BAR ---
                    if !feedManager.items.isEmpty {
                        HStack(spacing: 40) {
                            // PASS Button (X)
                            ActionButton(icon: "xmark", color: .red) {
                                triggerButtonSwipe(direction: .left)
                            }
                            
                            // SUPER LIKE (Placeholder)
                            ActionButton(icon: "star.fill", color: .blue, scale: 0.8) {
                                // Future Feature
                            }
                            
                            // INTERESTED Button (Heart)
                            ActionButton(icon: "heart.fill", color: .cyan) {
                                triggerButtonSwipe(direction: .right)
                            }
                        }
                        .padding(.bottom, 20)
                        .padding(.top, 10)
                    }
                }
            }
            .onAppear {
                Task { await feedManager.fetchFeed() }
            }
            // NEW: Connect Error Alert logic
            .alert("Error", isPresented: $tradeManager.showError) {
                Button("OK") { tradeManager.clearError() }
            } message: {
                Text(tradeManager.errorMessage ?? "An unknown error occurred")
            }
        }
    }
    
    // MARK: - Logic
    
    func triggerButtonSwipe(direction: CardSwipeDirection) {
        guard let topItem = feedManager.items.last else { return }
        lastSwipeDirection = direction
        
        withAnimation(.easeInOut(duration: 0.4)) {
            handleSwipe(direction: direction, item: topItem)
        }
    }
    
    func handleSwipe(direction: CardSwipeDirection, item: TradeItem) {
        // 1. Remove item from Feed UI immediately
        feedManager.removeItem(id: item.id)
        
        // 2. Logic: If Right Swipe, save to "Interested"
        if direction == .right {
            Task {
                await tradeManager.markAsInterested(item: item)
            }
        }
    }
}

// MARK: - SUBVIEWS

// 1. Draggable Card Wrapper (Interactive)
struct DraggableCard: View {
    let item: TradeItem
    var onSwipe: (CardSwipeDirection) -> Void
    
    @State private var offset = CGSize.zero
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            TinderGlassCard(item: item)
            
            // NEW: Like/Nope Overlay Logic
            if offset.width > 0 {
                // RIGHT (LIKE)
                VStack {
                    HStack {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.green)
                            .shadow(radius: 5)
                            .padding()
                            .background(Circle().fill(.white.opacity(0.2)))
                        Spacer()
                    }
                    Spacer()
                }
                .padding(40)
                .opacity(Double(offset.width / 150)) // Fade in as you drag
            } else if offset.width < 0 {
                // LEFT (NOPE)
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "xmark")
                            .font(.system(size: 80))
                            .foregroundStyle(.red)
                            .shadow(radius: 5)
                            .padding()
                            .background(Circle().fill(.white.opacity(0.2)))
                    }
                    Spacer()
                }
                .padding(40)
                .opacity(Double(abs(offset.width) / 150)) // Fade in as you drag
            }
        }
        .offset(x: offset.width, y: offset.height)
        .rotationEffect(.degrees(rotation))
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    let width = gesture.translation.width
                    offset = gesture.translation
                    rotation = Double(width / 20)
                }
                .onEnded { gesture in
                    let width = gesture.translation.width
                    if width > 120 {
                        // Swipe Right
                        animateSwipe(translation: 500, direction: .right)
                    } else if width < -120 {
                        // Swipe Left
                        animateSwipe(translation: -500, direction: .left)
                    } else {
                        // Snap Back
                        withAnimation(.spring()) {
                            offset = .zero
                            rotation = 0
                        }
                    }
                }
        )
    }
    
    func animateSwipe(translation: CGFloat, direction: CardSwipeDirection) {
        withAnimation(.easeOut(duration: 0.3)) {
            offset.width = translation
            rotation = Double(translation / 10)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSwipe(direction)
        }
    }
}

// 2. The Visual Card (Pure UI)
struct TinderGlassCard: View {
    let item: TradeItem
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Image
            AsyncImageView(filename: item.imageUrl)
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.3))
                .clipped()
            
            // Text Area Gradient
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .bottom) {
                    Text(item.title)
                        .font(.title).bold()
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Spacer()
                    Badge(text: item.category, color: .purple)
                }
                
                Text(item.condition)
                    .font(.subheadline).bold()
                    .foregroundStyle(.cyan)
                    .padding(.bottom, 2)
                
                Text(item.description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
            }
            .padding(20)
            .padding(.bottom, 20)
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.9), .black.opacity(0.0)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
        }
        .cornerRadius(30)
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
    }
}

// 3. Action Buttons
struct ActionButton: View {
    let icon: String
    let color: Color
    var scale: CGFloat = 1.0
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 65 * scale, height: 65 * scale)
                    .shadow(color: .black.opacity(0.2), radius: 10)
                    .overlay(Circle().stroke(color.opacity(0.5), lineWidth: 2))
                
                Image(systemName: icon)
                    .font(.system(size: 28 * scale, weight: .bold))
                    .foregroundStyle(color)
            }
        }
    }
}

// 4. Empty State
struct EmptyFeedState: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .top, endPoint: .bottom))
                .shadow(radius: 10)
            
            Text("No items found")
                .font(.title2).bold()
                .foregroundStyle(.white)
            
            Text("Adjust your ISO settings in Profile to see more!")
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

// 5. Badge Helper
struct Badge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text).font(.caption).bold()
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(color.opacity(0.3))
            .foregroundStyle(.white).cornerRadius(8)
    }
}
