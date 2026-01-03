import SwiftUI

// ✅ REMOVED: @available(iOS 17.0, *) - Now works on iOS 16.6+
struct FeedView: View {
    // MARK: - Dependencies
    @ObservedObject var feedManager = FeedManager.shared
    @ObservedObject var tradeManager = TradeManager.shared
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var progressionManager = ProgressionManager.shared
    @ObservedObject var tabManager = TabBarManager.shared
    
    // MARK: - State: Navigation
    @State private var selectedDetailItem: TradeItem?
    @State private var itemForQuickOffer: TradeItem?
    
    // 🛠️ FIX: Use a wrapper struct for the sheet state
    @State private var selectedProfileSheet: ProfileSheetWrapper?
    
    @State private var showProgressionView = false
    
    // MARK: - State: Animations
    @State private var showHeartOverlay = false
    @State private var heartScale: CGFloat = 0.5
    @State private var heartRotation: Double = 0
    @State private var dragOffsetY: CGFloat = 0
    
    // ✅ iOS 16.6 FIX: State for empty view pulse animation
    @State private var emptyStatePulse = false
    
    // MARK: - State: Gamification (XP & Combo)
    @State private var xpToasts: [XPToast] = []
    @State private var showAchievementHint = false
    @State private var achievementHintType: AchievementType?
    @State private var comboCount: Int = 0
    @State private var comboScale: CGFloat = 1.0
    @State private var lastActionTime: Date = Date()
    @State private var showLevelUp = false
    @State private var previousLevel: Int = 1
    @State private var showConfetti = false
    
    // MARK: - Computed Props
    var currentItem: TradeItem? {
        feedManager.items.last
    }
    
    var bottomBarPadding: CGFloat {
        tabManager.isVisible ? 95 : 20
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. Global Background
                LiquidBackground().ignoresSafeArea()
                
                // 2. Main Content
                if feedManager.isLoading && feedManager.items.isEmpty {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                } else if feedManager.items.isEmpty {
                    emptyStateView
                } else {
                    cardStackLayer
                }
                
                // 3. UI Overlays (Top to Bottom)
                VStack {
                    progressionHeader
                    Spacer()
                }
                .zIndex(10) // ✅ FIX: Bring header above card stack
                
                // 4. Interaction Feedback Layers
                if showHeartOverlay {
                    heartAnimationLayer
                }
                
                ForEach(xpToasts) { toast in
                    XPToastView(toast: toast)
                        .zIndex(110)
                }
                
                if comboCount >= 2 {
                    comboIndicatorLayer
                }
                
                // 5. Bottom Info Bar
                if let item = currentItem {
                    bottomInfoLayer(item: item)
                }
                
                // 6. Celebrations & Errors
                if showConfetti {
                    ConfettiCannon(count: 50).zIndex(199)
                }
                
                if showLevelUp {
                    LevelUpCelebration(level: userManager.currentLevel) {
                        withAnimation { showLevelUp = false }
                    }
                    .zIndex(200)
                }
                
                if let newAchievement = progressionManager.newlyUnlockedAchievement {
                    AchievementCelebrationOverlay(type: newAchievement) {
                        progressionManager.dismissCelebration()
                    }
                    .zIndex(201)
                }
                
                if let error = feedManager.error {
                    errorToast(error)
                }
            }
            .task {
                if feedManager.items.isEmpty {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await feedManager.fetchFeed()
                }
                previousLevel = userManager.currentLevel.tier
                showRandomAchievementHint()
            }
            // ✅ iOS 16.6 FIX: Use single-parameter .onChange syntax
            .onChange(of: userManager.currentLevel.tier) { newValue in
                if newValue > previousLevel { triggerBigCelebration() }
                previousLevel = newValue
            }
            // MARK: - Sheets
            .sheet(item: $selectedDetailItem) { item in
                NavigationStack { ProductDetailView(item: item) }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $itemForQuickOffer) { item in
                QuickOfferSheet(wantedItem: item)
                    .presentationDetents([.medium, .large])
            }
            // 🛠️ FIX: Update sheet to use the wrapper
            .sheet(item: $selectedProfileSheet) { wrapper in
                NavigationStack { PublicProfileView(userId: wrapper.id) }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showProgressionView) {
                NavigationStack { ProgressionView() }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    // MARK: - Sub-Views (Local)
    
    private var cardStackLayer: some View {
        ForEach(feedManager.items.suffix(2)) { item in
            let isTop = feedManager.items.last?.id == item.id
            
            FullScreenItemCard(item: item)
                .zIndex(isTop ? 2 : 1)
                .offset(y: isTop ? dragOffsetY : 0)
                .scaleEffect(isTop ? 1.0 : 0.95)
                .opacity(isTop ? 1.0 : (dragOffsetY < -50 ? 0.0 : 1.0))
                .onTapGesture(count: 2) { if isTop { handleDoubleTap(item: item) } }
                .onTapGesture(count: 1) { if isTop { selectedDetailItem = item } }
                .gesture(isTop ? makeDragGesture(for: item) : nil)
        }
    }
    
    private var heartAnimationLayer: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 100))
            .foregroundStyle(LinearGradient(colors: [.pink, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
            .shadow(color: .red.opacity(0.5), radius: 20)
            .scaleEffect(heartScale)
            .rotationEffect(.degrees(heartRotation))
            .transition(.scale.combined(with: .opacity))
            .zIndex(100)
    }
    
    private var comboIndicatorLayer: some View {
        VStack {
            Spacer()
            ComboIndicator(count: comboCount)
                .scaleEffect(comboScale)
                .rotationEffect(.degrees(Double.random(in: -3...3)))
                .padding(.bottom, 220)
                .id("combo-\(comboCount)")
        }
        .transition(.scale.combined(with: .opacity))
        .zIndex(50)
    }
    
    private func bottomInfoLayer(item: TradeItem) -> some View {
        VStack {
            Spacer()
            
            if showAchievementHint, let hintType = achievementHintType {
                AchievementHintBanner(type: hintType, progress: progressionManager.progress(for: hintType))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            FeedBottomBar(
                item: item,
                onQuickOffer: {
                    itemForQuickOffer = item
                    awardXP(amount: 15, reason: "Offer Started")
                }
            )
            .padding(.horizontal, 20)
            .padding(.bottom, bottomBarPadding)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: tabManager.isVisible)
        }
        .zIndex(5)
    }
    
    private func errorToast(_ error: String) -> some View {
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
    
    private var progressionHeader: some View {
        HStack(spacing: 12) {
            Text("swappr.")
                .font(.system(size: 28, weight: .heavy, design: .default))
                .foregroundStyle(.white)
                .shadow(color: .cyan.opacity(0.3), radius: 5)
            
            Spacer()
            
            Button {
                Haptics.shared.playLight()
                showProgressionView = true
            } label: {
                HStack(spacing: 8) {
                    if userManager.currentStreak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill").foregroundStyle(.orange)
                            Text("\(userManager.currentStreak)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(Capsule())
                    }
                    
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 3)
                            .frame(width: 36, height: 36)
                        Circle()
                            .trim(from: 0, to: userManager.levelProgress)
                            .stroke(userManager.currentLevel.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 36, height: 36)
                        Text("\(userManager.currentLevel.tier)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }
    
    // ✅ iOS 16.6 FIX: Custom pulse animation instead of .symbolEffect
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.cyan)
                .scaleEffect(emptyStatePulse ? 1.1 : 1.0)
                .opacity(emptyStatePulse ? 1.0 : 0.8)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: emptyStatePulse
                )
                .onAppear {
                    emptyStatePulse = true
                }
            
            Text("All Caught Up!")
                .font(.title2).bold()
                .foregroundStyle(.white)
            
            Text("You've viewed all nearby items.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            
            Button("Refresh Feed") {
                Haptics.shared.playMedium()
                Task {
                    await feedManager.fetchFeed()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.2))
            .clipShape(Capsule())
        }
    }
    
    // MARK: - Logic & Gestures
    
    private func makeDragGesture(for item: TradeItem) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height < 0 {
                    dragOffsetY = value.translation.height
                } else {
                    dragOffsetY = value.translation.height / 5
                }
            }
            .onEnded { value in
                let horizontalAmount = value.translation.width
                let verticalAmount = value.translation.height
                
                if abs(horizontalAmount) > abs(verticalAmount) {
                    if horizontalAmount < -50 {
                        openOwnerProfile(item: item)
                    } else if horizontalAmount > 50 {
                        openProductDetail(item: item)
                    }
                    withAnimation(.spring()) { dragOffsetY = 0 }
                } else {
                    if verticalAmount < -150 {
                        dismissItem(item)
                    } else {
                        withAnimation(.spring()) { dragOffsetY = 0 }
                    }
                }
            }
    }
    
    private func awardXP(amount: Int, reason: String) {
        userManager.awardXP(amount: amount)
        let toast = XPToast(amount: amount, reason: reason)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            xpToasts.append(toast)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { xpToasts.removeAll { $0.id == toast.id } }
        }
        updateCombo()
    }
    
    private func updateCombo() {
        let now = Date()
        let timeSinceLastAction = now.timeIntervalSince(lastActionTime)
        
        if timeSinceLastAction < 3.0 {
            comboCount += 1
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { comboScale = 1.3 }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.1)) { comboScale = 1.0 }
            
            if comboCount == 5 {
                awardXP(amount: 25, reason: "5x Streak!")
                Haptics.shared.playSuccess()
            } else if comboCount == 10 {
                awardXP(amount: 50, reason: "UNSTOPPABLE!")
                triggerConfetti()
                Haptics.shared.playSuccess()
            } else {
                Haptics.shared.playLight()
            }
        } else {
            comboCount = 1
        }
        lastActionTime = now
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if Date().timeIntervalSince(self.lastActionTime) >= 3.0 {
                withAnimation(.easeOut) { self.comboCount = 0 }
            }
        }
    }
    
    private func triggerBigCelebration() {
        withAnimation(.spring()) { showLevelUp = true }
        triggerConfetti()
        Haptics.shared.playSuccess()
    }
    
    private func triggerConfetti() {
        withAnimation { showConfetti = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation { showConfetti = false }
        }
    }
    
    private func dismissItem(_ item: TradeItem) {
        awardXP(amount: 2, reason: "Browsing")
        withAnimation(.easeOut(duration: 0.2)) { dragOffsetY = -1000 }
        Haptics.shared.playLight()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            feedManager.removeItem(id: item.id)
            dragOffsetY = 0
        }
    }
    
    private func openOwnerProfile(item: TradeItem) {
        Haptics.shared.playMedium()
        // 🛠️ FIX: Wrap the ID
        selectedProfileSheet = ProfileSheetWrapper(id: item.ownerId)
        awardXP(amount: 5, reason: "Scouting")
    }
    
    private func openProductDetail(item: TradeItem) {
        Haptics.shared.playMedium()
        selectedDetailItem = item
        awardXP(amount: 5, reason: "Interest")
    }
    
    private func handleDoubleTap(item: TradeItem) {
        heartScale = 0.5
        heartRotation = Double.random(in: -15...15)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            showHeartOverlay = true
            heartScale = 1.2
        }
        Haptics.shared.playSuccess()
        awardXP(amount: 10, reason: "Liked!")
        Task { await tradeManager.markAsInterested(item: item) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.2)) {
                showHeartOverlay = false
                heartScale = 0.1
            }
            dismissItem(item)
        }
    }
    
    private func showRandomAchievementHint() {
        guard let nextAchievement = progressionManager.nextAchievementToUnlock else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if Bool.random() && !progressionManager.isUnlocked(nextAchievement) {
                achievementHintType = nextAchievement
                withAnimation(.spring()) { showAchievementHint = true }
                Haptics.shared.playLight()
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation { showAchievementHint = false }
                }
            }
        }
    }
}

// 🛠️ FIX: Helper Struct for Identifiable UUID
struct ProfileSheetWrapper: Identifiable {
    let id: UUID
}
