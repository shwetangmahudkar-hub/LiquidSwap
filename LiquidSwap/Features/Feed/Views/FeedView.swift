import SwiftUI

// Ensure SwipeDirection is defined
enum CardSwipeDirection {
    case left
    case right
}

// Wrapper to make UUID identifiable for Sheet presentation
struct ProfileDestination: Identifiable {
    let id: UUID
}

struct FeedView: View {
    // FIX: Use shared instance instead of creating a new one
    @ObservedObject var feedManager = FeedManager.shared
    @ObservedObject var tradeManager = TradeManager.shared
    
    // State for Detail View Navigation
    @State private var selectedDetailItem: TradeItem?
    
    // State for Public Profile Sheet
    @State private var selectedProfile: ProfileDestination?
    
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
                    .zIndex(10) // Keep header on top
                    
                    // --- CARD STACK VIEW ---
                    GeometryReader { geometry in
                        // Width: Old (-38) -> New (-48) [5pt narrower each side]
                        let cardHeight = geometry.size.height - 54
                        let cardWidth = geometry.size.width - 48
                        
                        ZStack {
                            if feedManager.isLoading {
                                ProgressView().tint(.cyan)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else if feedManager.items.isEmpty {
                                EmptyFeedState(feedManager: feedManager)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                            } else {
                                // 1. GHOST CARDS
                                ForEach(0..<3) { index in
                                    GhostCard()
                                        .frame(width: cardWidth, height: cardHeight)
                                        .scaleEffect(0.9 - (Double(index) * 0.05))
                                        .offset(y: 20 + (CGFloat(index) * 15))
                                        .opacity(0.3 - (Double(index) * 0.1))
                                        .zIndex(Double(-index))
                                }
                                
                                // 2. REAL CARDS
                                ForEach(feedManager.items.suffix(3)) { item in
                                    let isTop = feedManager.items.last?.id == item.id
                                    
                                    if isTop {
                                        DraggableCard(item: item) { direction in
                                            lastSwipeDirection = direction
                                            handleSwipe(direction: direction, item: item)
                                        }
                                        .onProfileTap {
                                            selectedProfile = ProfileDestination(id: item.ownerId)
                                        }
                                        .onTapGesture { selectedDetailItem = item }
                                        .frame(width: cardWidth, height: cardHeight)
                                        .zIndex(100)
                                        .transition(.asymmetric(
                                            insertion: .identity,
                                            removal: .move(edge: lastSwipeDirection == .left ? .leading : .trailing)
                                        ))
                                    } else {
                                        TinderGlassCard(item: item)
                                            .frame(width: cardWidth, height: cardHeight)
                                            .zIndex(Double(feedManager.items.firstIndex(where: { $0.id == item.id }) ?? 0))
                                            .scaleEffect(0.95)
                                            .offset(y: 10)
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
                            ActionButton(icon: "xmark", color: .red) {
                                triggerButtonSwipe(direction: .left)
                            }
                            ActionButton(icon: "star.fill", color: .blue, scale: 0.8) { }
                            ActionButton(icon: "heart.fill", color: .cyan) {
                                triggerButtonSwipe(direction: .right)
                            }
                        }
                        .padding(.bottom, 60)
                        .padding(.top, 10)
                    }
                }
            }
            .onAppear {
                Task {
                    await feedManager.fetchFeed()
                }
            }
            .fullScreenCover(item: $selectedDetailItem) { item in
                ProductDetailView(item: item)
            }
            .sheet(item: $selectedProfile) { dest in
                PublicProfileView(userId: dest.id)
                    .presentationDetents([.fraction(0.85)]) // Partial sheet
            }
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
        if direction == .right { Haptics.shared.playSuccess() }
        else { Haptics.shared.playLight() }
        
        feedManager.removeItem(id: item.id)
        
        if direction == .right {
            Task {
                await tradeManager.markAsInterested(item: item)
            }
        }
    }
}

// MARK: - SUBVIEWS

// 1. Ghost Card
struct GhostCard: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(.ultraThinMaterial)
                .background(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        }
    }
}

// 2. Draggable Card
struct DraggableCard: View {
    let item: TradeItem
    var onSwipe: (CardSwipeDirection) -> Void
    var onProfileTap: (() -> Void)? = nil
    
    @State private var offset = CGSize.zero
    @State private var rotation: Double = 0
    @State private var lastHapticStep: Int = 0
    
    var body: some View {
        ZStack {
            TinderGlassCard(item: item, onProfileTap: onProfileTap)
            
            if offset.width > 0 {
                VStack {
                    HStack {
                        Image(systemName: "heart.fill").font(.system(size: 80)).foregroundStyle(.green).shadow(radius: 5).padding().background(Circle().fill(.white.opacity(0.2)))
                        Spacer()
                    }
                    Spacer()
                }.padding(40).opacity(Double(offset.width / 150))
            } else if offset.width < 0 {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "xmark").font(.system(size: 80)).foregroundStyle(.red).shadow(radius: 5).padding().background(Circle().fill(.white.opacity(0.2)))
                    }
                    Spacer()
                }.padding(40).opacity(Double(abs(offset.width) / 150))
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
                    let currentStep = Int(width / 40)
                    if currentStep != lastHapticStep {
                        Haptics.shared.playLight()
                        lastHapticStep = currentStep
                    }
                }
                .onEnded { gesture in
                    let width = gesture.translation.width
                    if width > 120 {
                        Haptics.shared.playSuccess()
                        animateSwipe(translation: 500, direction: .right)
                    } else if width < -120 {
                        Haptics.shared.playLight()
                        animateSwipe(translation: -500, direction: .left)
                    } else {
                        withAnimation(.spring()) { offset = .zero; rotation = 0 }
                    }
                    lastHapticStep = 0
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
    
    func onProfileTap(_ action: @escaping () -> Void) -> DraggableCard {
        var copy = self
        copy.onProfileTap = action
        return copy
    }
}

// 3. TinderGlassCard
struct TinderGlassCard: View {
    let item: TradeItem
    var onProfileTap: (() -> Void)? = nil
    
    var body: some View {
        ZStack(alignment: .bottom) {
            AsyncImageView(filename: item.imageUrl)
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.3))
                .clipped()
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .bottom) {
                    Text(item.title).font(.title).bold().foregroundStyle(.white).lineLimit(2)
                    Spacer()
                    Badge(text: item.category, color: .purple)
                }
                
                Button(action: {
                    onProfileTap?()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.cyan)
                        
                        Text(item.ownerUsername ?? "Loading...")
                            .font(.caption).bold()
                            .foregroundStyle(.white)
                        
                        // Verification Checkmark
                        if item.ownerIsVerified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundStyle(.cyan)
                        }
                        
                        Text("•")
                            .font(.caption).foregroundStyle(.white.opacity(0.5))
                        
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                            Text("\(String(format: "%.1f", item.ownerRating ?? 0))")
                                .font(.caption2).bold().foregroundStyle(.white)
                            
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 4)
                
                Text(item.condition).font(.subheadline).bold().foregroundStyle(.cyan).padding(.bottom, 2)
                Text(item.description).font(.subheadline).foregroundStyle(.white.opacity(0.9)).lineLimit(2)
                
                if item.distance > 0 {
                    HStack {
                        Image(systemName: "location.fill").font(.caption).foregroundStyle(.white.opacity(0.7))
                        Text("\(String(format: "%.1f", item.distance)) km").font(.caption).foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .padding(20).padding(.bottom, 20)
            .background(LinearGradient(colors: [.black.opacity(0.9), .black.opacity(0.0)], startPoint: .bottom, endPoint: .top))
        }
        .cornerRadius(30)
        .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white.opacity(0.3), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
    }
}

// 4. ActionButton
struct ActionButton: View {
    let icon: String; let color: Color; var scale: CGFloat = 1.0; let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(.ultraThinMaterial).frame(width: 65 * scale, height: 65 * scale)
                    .shadow(color: .black.opacity(0.2), radius: 10)
                    .overlay(Circle().stroke(color.opacity(0.5), lineWidth: 2))
                Image(systemName: icon).font(.system(size: 28 * scale, weight: .bold)).foregroundStyle(color)
            }
        }
    }
}

// 5. EmptyFeedState
struct EmptyFeedState: View {
    @ObservedObject var feedManager: FeedManager
    
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
            
            Button("Refresh Feed") {
                Task { await feedManager.fetchFeed() }
            }
            .font(.caption).foregroundStyle(.cyan)
        }
    }
}

// 6. Badge
struct Badge: View {
    let text: String; let color: Color
    var body: some View {
        Text(text).font(.caption).bold().padding(.horizontal, 10).padding(.vertical, 5)
            .background(color.opacity(0.3)).foregroundStyle(.white).cornerRadius(8)
    }
}
