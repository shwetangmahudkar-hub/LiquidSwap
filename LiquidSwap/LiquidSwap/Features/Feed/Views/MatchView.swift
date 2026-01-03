import SwiftUI

struct MatchView: View {
    // Managers
    @ObservedObject var feedManager = FeedManager.shared
    @ObservedObject var tradeManager = TradeManager.shared
    @ObservedObject var userManager = UserManager.shared
    
    // UI State
    @State private var topCardOffset: CGSize = .zero
    @State private var showMatchAnimation = false
    @State private var matchedItem: TradeItem?
    
    var body: some View {
        ZStack {
            // 1. Global Background
            LiquidBackground()
            
            VStack(spacing: 0) {
                // 2. Header
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.title)
                        .foregroundStyle(.cyan)
                    Text("Discover")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    
                    // Filter Button (Visual only for now)
                    Button(action: {}) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                // 3. Card Stack
                GeometryReader { geo in
                    ZStack {
                        if feedManager.items.isEmpty {
                            EmptyFeedView {
                                Task { await feedManager.fetchFeed() }
                            }
                        } else {
                            // Reverse to show first item on top
                            ForEach(feedManager.items.prefix(3).reversed()) { item in
                                GlassSwipeCard(item: item)
                                    .frame(width: geo.size.width - 32, height: geo.size.height - 40)
                                    .offset(x: item.id == feedManager.items.first?.id ? topCardOffset.width : 0,
                                            y: item.id == feedManager.items.first?.id ? topCardOffset.height : 0)
                                    .rotationEffect(.degrees(item.id == feedManager.items.first?.id ? Double(topCardOffset.width / 20) : 0))
                                    .scaleEffect(item.id == feedManager.items.first?.id ? 1 : 0.95)
                                    .opacity(item.id == feedManager.items.first?.id ? 1 : 0.5)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: topCardOffset)
                                    .gesture(
                                        DragGesture()
                                            .onChanged { gesture in
                                                // Only allow drag for top card
                                                if item.id == feedManager.items.first?.id {
                                                    topCardOffset = gesture.translation
                                                }
                                            }
                                            .onEnded { gesture in
                                                if item.id == feedManager.items.first?.id {
                                                    handleSwipe(translation: gesture.translation, item: item)
                                                }
                                            }
                                    )
                                    // Overlay Status (Like/Nope)
                                    .overlay(
                                        ZStack {
                                            if item.id == feedManager.items.first?.id {
                                                if topCardOffset.width > 100 {
                                                    Text("LIKE")
                                                        .font(.largeTitle.weight(.heavy))
                                                        .foregroundColor(.green)
                                                        .padding()
                                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green, lineWidth: 4))
                                                        .rotationEffect(.degrees(-15))
                                                } else if topCardOffset.width < -100 {
                                                    Text("NOPE")
                                                        .font(.largeTitle.weight(.heavy))
                                                        .foregroundColor(.red)
                                                        .padding()
                                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red, lineWidth: 4))
                                                        .rotationEffect(.degrees(15))
                                                }
                                            }
                                        }
                                    )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // 4. Bottom Controls (Floating)
                if !feedManager.items.isEmpty {
                    HStack(spacing: 40) {
                        // Pass Button
                        Button(action: { swipeLeft() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.red)
                                .frame(width: 64, height: 64)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.red.opacity(0.3), lineWidth: 1))
                                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                        }
                        
                        // Like Button
                        Button(action: { swipeRight() }) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.green)
                                .frame(width: 72, height: 72)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.green.opacity(0.3), lineWidth: 1))
                                .shadow(color: .green.opacity(0.3), radius: 15, y: 5)
                        }
                    }
                    .padding(.bottom, 20)
                } else {
                    Spacer().frame(height: 100)
                }
            }
        }
        .task {
            if feedManager.items.isEmpty {
                await feedManager.fetchFeed()
            }
        }
    }
    
    // MARK: - Logic
    
    func handleSwipe(translation: CGSize, item: TradeItem) {
        let threshold: CGFloat = 120
        if translation.width > threshold {
            swipeRight()
        } else if translation.width < -threshold {
            swipeLeft()
        } else {
            // Reset
            withAnimation(.spring()) {
                topCardOffset = .zero
            }
        }
    }
    
    func swipeRight() {
        guard let item = feedManager.items.first else { return }
        
        // Animate off screen
        withAnimation(.easeIn(duration: 0.2)) {
            topCardOffset = CGSize(width: 500, height: 0)
        }
        
        // Logic
        Haptics.shared.playSuccess()
        Task {
            _ = await tradeManager.markAsInterested(item: item)
            // Delay removal slightly to allow animation
            try? await Task.sleep(nanoseconds: 200_000_000)
            await MainActor.run {
                feedManager.removeItem(id: item.id)
                topCardOffset = .zero
            }
        }
    }
    
    func swipeLeft() {
        guard let item = feedManager.items.first else { return }
        
        // Animate off screen
        withAnimation(.easeIn(duration: 0.2)) {
            topCardOffset = CGSize(width: -500, height: 0)
        }
        
        // Logic
        Haptics.shared.playLight()
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            await MainActor.run {
                feedManager.removeItem(id: item.id)
                topCardOffset = .zero
            }
        }
    }
}

// MARK: - Subviews

struct GlassSwipeCard: View {
    let item: TradeItem
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Image Layer
            AsyncImageView(filename: item.imageUrl)
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            
            // Gradient Overlay
            LinearGradient(colors: [.black.opacity(0), .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
            
            // Info Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(item.category.uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    if item.distance > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text("\(String(format: "%.1f", item.distance)) km")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                    }
                }
                
                Text(item.title)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .shadow(color: .black, radius: 2)
                
                Text(item.description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
            }
            .padding(24)
            .padding(.bottom, 20)
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        // Glass Border
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
        )
    }
}

struct EmptyFeedView: View {
    var onRefresh: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.cyan)
            }
            
            Text("You're all caught up!")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text("Check back later for more items.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            
            Button(action: onRefresh) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(30)
        .padding(20)
    }
}
