import SwiftUI

struct FeedView: View {
    @ObservedObject var feedManager = FeedManager.shared
    @ObservedObject var tradeManager = TradeManager.shared
    @ObservedObject var userManager = UserManager.shared // ✨ Needed to check inventory for match logic
    
    // Sheets State
    @State private var selectedDetailItem: TradeItem?
    @State private var itemForQuickOffer: TradeItem?
    
    // Match Animation State (Testing Trigger)
    @State private var showMatchView = false
    @State private var matchedItem: TradeItem?
    
    // Heart Animation State
    @State private var showHeartOverlay = false
    
    // Gesture State
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. Global Background (Fallback)
                LiquidBackground().ignoresSafeArea()
                
                // 2. Main Content
                if feedManager.isLoading && feedManager.items.isEmpty {
                    ProgressView().tint(.white)
                } else if feedManager.items.isEmpty {
                    // Empty State
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.cyan)
                            .shadow(radius: 10)
                        Text("You're all caught up!")
                            .font(.title2).bold()
                            .foregroundStyle(.white)
                        Button("Refresh Feed") {
                            Task { await feedManager.fetchFeed() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white.opacity(0.2))
                    }
                } else {
                    // 3. Card Stack
                    ForEach(feedManager.items.suffix(2)) { item in
                        let isTop = feedManager.items.last?.id == item.id
                        
                        FullScreenItemCard(item: item)
                            .zIndex(isTop ? 2 : 1)
                            .offset(y: isTop ? dragOffset : 0)
                            .scaleEffect(isTop ? 1.0 : 0.95)
                            .opacity(isTop ? 1.0 : (dragOffset < -50 ? 1.0 : 0.0))
                            
                            // --- GESTURES ---
                            .onTapGesture(count: 2) {
                                if isTop { handleDoubleTap(item: item) }
                            }
                            .onTapGesture(count: 1) {
                                if isTop { selectedDetailItem = item }
                            }
                            .gesture(
                                isTop ? DragGesture()
                                    .onChanged { value in
                                        if value.translation.height < 0 {
                                            dragOffset = value.translation.height
                                        } else {
                                            dragOffset = value.translation.height / 5
                                        }
                                    }
                                    .onEnded { value in
                                        if value.translation.height < -150 {
                                            dismissItem(item)
                                        } else {
                                            withAnimation(.spring()) { dragOffset = 0 }
                                        }
                                    } : nil
                            )
                            
                            // --- OVERLAYS (Quick Offer Button) ---
                            .overlay(alignment: .bottomTrailing) {
                                if isTop {
                                    Button(action: { itemForQuickOffer = item }) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.black.opacity(0.8))
                                                .frame(width: 56, height: 56)
                                                .shadow(color: .cyan.opacity(0.5), radius: 10, y: 5)
                                                .overlay(
                                                    Circle()
                                                        .stroke(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                                                )
                                            
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                                .font(.system(size: 24, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .padding(.trailing, 20)
                                    .padding(.bottom, 155)
                                    .opacity(Double(1.0 - (abs(dragOffset) / 100)))
                                }
                            }
                    }
                }
                
                // 4. Company Branding (Top Left)
                VStack {
                    HStack {
                        Text("swappr.")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                            .padding(.leading, 24)
                            .padding(.top, 60)
                        Spacer()
                    }
                    Spacer()
                }
                .allowsHitTesting(false)
                
                // 5. Heart Animation
                if showHeartOverlay {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 10)
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(100)
                }
                
                // 6. ✨ MATCH VIEW OVERLAY (For Testing)
                if showMatchView, let item = matchedItem {
                    MatchView()
                        .transition(.opacity)
                        .zIndex(200)
                }
            }
            .task {
                if feedManager.items.isEmpty {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await feedManager.fetchFeed()
                }
            }
            .sheet(item: $selectedDetailItem) { item in
                NavigationStack {
                    ProductDetailView(item: item)
                }
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $itemForQuickOffer) { item in
                QuickOfferSheet(wantedItem: item)
                    .presentationDetents([.medium, .large])
            }
        }
    }
    
    // MARK: - Logic
    
    func dismissItem(_ item: TradeItem) {
        withAnimation(.easeOut(duration: 0.2)) { dragOffset = -1000 }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            feedManager.removeItem(id: item.id)
            dragOffset = 0
        }
    }
    
    func handleDoubleTap(item: TradeItem) {
        // 1. Play standard heart animation
        withAnimation(.spring(duration: 0.3)) { showHeartOverlay = true }
        Haptics.shared.playSuccess()
        
        Task { await tradeManager.markAsInterested(item: item) }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.2)) {
                showHeartOverlay = false
            }
            
            // ✨ TESTING LOGIC:
            // Force "Match" screen to appear if user has items (simulating a mutual match)
            if !userManager.userItems.isEmpty {
                matchedItem = item
                withAnimation { showMatchView = true }
            } else {
                // If no items, just remove card normally
                feedManager.removeItem(id: item.id)
            }
        }
    }
}

// MARK: - SUBVIEWS (Updated with Gamification)

struct FullScreenItemCard: View {
    let item: TradeItem
    
    // ✨ NEW: Gamification Logic
    var rankTitle: String {
        guard let count = item.ownerTradeCount else { return "Newcomer" }
        switch count {
        case 0...2: return "Novice"
        case 3...9: return "Eco Trader"
        case 10...24: return "Savant"
        case 25...49: return "Hero"
        default: return "Legend"
        }
    }
    
    var rankColor: Color {
        switch rankTitle {
        case "Novice": return .white.opacity(0.7)
        case "Eco Trader": return .green
        case "Savant": return .cyan
        case "Hero": return .purple
        case "Legend": return .yellow
        default: return .gray
        }
    }
    
    var isPremium: Bool {
        return item.ownerIsPremium ?? false
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                
                // 1. Full Screen Image
                AsyncImageView(filename: item.imageUrl)
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.2), .black.opacity(0.9)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
                
                // 2. ✨ PREMIUM BORDER (Visible only for Premium Users)
                if isPremium {
                    RoundedRectangle(cornerRadius: 0)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.yellow.opacity(0.8), .orange.opacity(0.5), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 4
                        )
                        .ignoresSafeArea()
                }
                
                // 3. Info Overlay
                VStack(alignment: .leading, spacing: 6) {
                    
                    // ✨ NEW: Rank & Category Row
                    HStack(spacing: 8) {
                        // Category Pill
                        Text(item.category.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(6)
                            .foregroundStyle(.white)
                        
                        // Rank Pill
                        Text(rankTitle.uppercased())
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(rankColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(rankColor.opacity(0.15))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(rankColor.opacity(0.3), lineWidth: 1))
                    }
                    
                    // Title
                    Text(item.title)
                        .font(.system(size: 32, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .shadow(radius: 2)
                    
                    // User & Distance
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundStyle(.cyan)
                        Text("\(String(format: "%.1f", item.distance)) km away")
                            .font(.subheadline).bold()
                            .foregroundStyle(.white.opacity(0.9))
                        
                        Text("•")
                            .foregroundStyle(.white.opacity(0.5))
                        
                        // User Name with Verification Check
                        HStack(spacing: 4) {
                            Text(item.ownerUsername ?? "User")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                            
                            if item.ownerIsVerified == true {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.cyan)
                            }
                        }
                    }
                }
                .padding(.leading, 24)
                .padding(.trailing, 90)
                .padding(.bottom, 145)
            }
        }
        .ignoresSafeArea()
        .background(Color.black)
    }
}
