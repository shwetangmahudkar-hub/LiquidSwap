import SwiftUI

struct FeedView: View {
    @ObservedObject var feedManager = FeedManager.shared
    @ObservedObject var tradeManager = TradeManager.shared
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var tabManager = TabBarManager.shared
    
    // Sheets State
    @State private var selectedDetailItem: TradeItem?
    @State private var itemForQuickOffer: TradeItem?
    @State private var selectedProfileOwnerId: UUID?
    
    // Heart Animation State
    @State private var showHeartOverlay = false
    
    // Gesture State (Only Y for swipe up)
    @State private var dragOffsetY: CGFloat = 0
    
    // Current top item for the info bar
    var currentItem: TradeItem? {
        feedManager.items.last
    }
    
    // Bottom bar position: higher when tab bar visible, lower when hidden
    var bottomBarPadding: CGFloat {
        tabManager.isVisible ? 95 : 20
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. Global Background
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
                            .offset(y: isTop ? dragOffsetY : 0)
                            .scaleEffect(isTop ? 1.0 : 0.95)
                            .opacity(isTop ? 1.0 : (dragOffsetY < -50 ? 0.0 : 1.0)) // Fade out when swiping up
                            
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
                                        // Only track vertical movement for swipe up
                                        if value.translation.height < 0 {
                                            dragOffsetY = value.translation.height
                                        } else {
                                            dragOffsetY = value.translation.height / 5
                                        }
                                    }
                                    .onEnded { value in
                                        let horizontalAmount = value.translation.width
                                        let verticalAmount = value.translation.height
                                        
                                        // Determine primary swipe direction
                                        if abs(horizontalAmount) > abs(verticalAmount) {
                                            // Horizontal swipe detected
                                            if horizontalAmount < -50 {
                                                // SWIPE LEFT → Open Profile (no card movement)
                                                openOwnerProfile(item: item)
                                            } else if horizontalAmount > 50 {
                                                // SWIPE RIGHT → Open Product Detail (no card movement)
                                                openProductDetail(item: item)
                                            }
                                            // Reset any vertical offset
                                            withAnimation(.spring()) { dragOffsetY = 0 }
                                        } else {
                                            // Vertical swipe
                                            if verticalAmount < -150 {
                                                // SWIPE UP → Dismiss item
                                                dismissItem(item)
                                            } else {
                                                withAnimation(.spring()) { dragOffsetY = 0 }
                                            }
                                        }
                                    } : nil
                            )
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
                
                // 5. Heart Animation Overlay
                if showHeartOverlay {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 10)
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(100)
                }
                
                // 6. Bottom Info Bar (Always visible, position synced with Tab Bar)
                if let item = currentItem {
                    VStack {
                        Spacer()
                        
                        FeedBottomBar(
                            item: item,
                            onQuickOffer: { itemForQuickOffer = item }
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, bottomBarPadding)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: tabManager.isVisible)
                    }
                    .zIndex(5)
                }
                
                // 7. Error Toast (Subtle)
                if let error = feedManager.error {
                    VStack {
                        Spacer()
                        Text(error)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(10)
                            .padding(.bottom, 120)
                    }
                    .transition(.move(edge: .bottom))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            feedManager.error = nil
                        }
                    }
                }
            }
            .task {
                if feedManager.items.isEmpty {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await feedManager.fetchFeed()
                }
            }
            // Single Tap / Swipe Right -> Product Detail
            .sheet(item: $selectedDetailItem) { item in
                NavigationStack {
                    ProductDetailView(item: item)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            // Quick Offer Sheet
            .sheet(item: $itemForQuickOffer) { item in
                QuickOfferSheet(wantedItem: item)
                    .presentationDetents([.medium, .large])
            }
            // Swipe Left -> Owner Profile
            .sheet(item: $selectedProfileOwnerId) { ownerId in
                NavigationStack {
                    PublicProfileView(userId: ownerId)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    // MARK: - Logic
    
    /// Swipe UP - Skip to next item
    func dismissItem(_ item: TradeItem) {
        withAnimation(.easeOut(duration: 0.2)) {
            dragOffsetY = -1000
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            feedManager.removeItem(id: item.id)
            dragOffsetY = 0
        }
    }
    
    /// Swipe LEFT - Open owner's profile
    func openOwnerProfile(item: TradeItem) {
        Haptics.shared.playLight()
        selectedProfileOwnerId = item.ownerId
    }
    
    /// Swipe RIGHT - Open product detail
    func openProductDetail(item: TradeItem) {
        Haptics.shared.playLight()
        selectedDetailItem = item
    }
    
    /// Double Tap - Like item (add to Interested) and move to next
    func handleDoubleTap(item: TradeItem) {
        // 1. Play heart animation
        withAnimation(.spring(duration: 0.3)) { showHeartOverlay = true }
        Haptics.shared.playSuccess()
        
        // 2. Save to interested items (DB Call)
        Task { await tradeManager.markAsInterested(item: item) }
        
        // 3. Hide heart and dismiss item after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                showHeartOverlay = false
            }
            // Move to next item
            dismissItem(item)
        }
    }
}

// MARK: - UUID Extension for Sheet Binding
extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}

// MARK: - Bottom Info Bar Component

struct FeedBottomBar: View {
    let item: TradeItem
    let onQuickOffer: () -> Void
    
    // Gamification Logic
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
    
    var body: some View {
        VStack(spacing: 12) {
            // Top Row: Title + Quick Offer Button
            HStack(alignment: .center, spacing: 12) {
                // Item Info
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(item.title)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    // Category + Rank Row
                    HStack(spacing: 8) {
                        // Category Pill
                        Text(item.category.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(4)
                        
                        // Rank Pill
                        Text(rankTitle.uppercased())
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(rankColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(rankColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                // Quick Offer Button
                Button(action: onQuickOffer) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .bold))
                        Text("Offer")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.cyan)
                    .clipShape(Capsule())
                }
            }
            
            // Bottom Row: User + Distance
            HStack(spacing: 8) {
                // User Info
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
                
                Text("•")
                    .foregroundStyle(.white.opacity(0.4))
                
                // Distance
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(.cyan)
                    Text("\(String(format: "%.1f", item.distance)) km")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 15, y: 8)
    }
}

// MARK: - SUBVIEWS

struct FullScreenItemCard: View {
    let item: TradeItem
    
    var isPremium: Bool {
        return item.ownerIsPremium ?? false
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. Full Screen Image
                AsyncImageView(filename: item.imageUrl)
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.1), .black.opacity(0.6)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
                
                // 2. PREMIUM BORDER (Visible only for Premium Users)
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
            }
        }
        .ignoresSafeArea()
        .background(Color.black)
    }
}
