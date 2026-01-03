import SwiftUI

struct PublicProfileView: View {
    let userId: UUID
    var showActiveListings: Bool = true
    
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userManager = UserManager.shared
    
    // Data State
    @State private var profile: UserProfile?
    @State private var items: [TradeItem] = []
    @State private var rating: Double = 0.0
    @State private var reviewCount: Int = 0
    @State private var tradeCount: Int = 0
    @State private var isLoading = true
    
    // ✨ NEW: Progression State
    @State private var achievements: [Achievement] = []
    @State private var currentStreak: Int = 0
    @State private var longestStreak: Int = 0
    
    // Derived Stats
    @State private var topCategory: String = "General"
    
    // Alert State
    @State private var showBlockAlert = false
    @State private var showReportAlert = false
    
    // ✨ NEW: Sheet State for Achievements
    @State private var showAllAchievements = false
    
    // Computed: Trust Score for this profile
    private var profileTrustScore: Int {
        var score = 0
        score += tradeCount * 2
        score += Int(rating * 10)
        score += reviewCount
        score += (profile?.isVerified == true) ? 20 : 0
        score += Int(Double(currentStreak) * 0.5)
        return score
    }
    
    private var profileTrustTier: TrustTier {
        return TrustTier.fromScore(profileTrustScore)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LiquidBackground()
                
                if isLoading {
                    ProgressView().tint(.white)
                } else if let profile = profile {
                    ScrollView {
                        VStack(spacing: 24) {
                            
                            // --- HEADER ---
                            headerSection(profile: profile)
                            
                            Divider()
                                .background(Color.white.opacity(0.2))
                            
                            // --- ✨ ACHIEVEMENTS SECTION (NEW) ---
                            if !achievements.isEmpty {
                                achievementsSection
                            }
                            
                            // --- HIGHLIGHTS SECTION ---
                            highlightsSection
                            
                            // --- ✨ IMPACT DASHBOARD (ENHANCED) ---
                            impactDashboardSection
                            
                            // --- ACTIVE LISTINGS SECTION ---
                            if showActiveListings {
                                activeListingsSection
                            }
                            
                            Spacer(minLength: 50)
                        }
                    }
                } else {
                    Text("User not found")
                        .foregroundStyle(.gray)
                }
            }
            .navigationTitle("Trader Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                
                // Safety Menu
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(role: .destructive, action: { showBlockAlert = true }) {
                            Label("Block User", systemImage: "hand.raised.fill")
                        }
                        
                        Button(action: { showReportAlert = true }) {
                            Label("Report User", systemImage: "exclamationmark.bubble")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                }
            }
            .alert("Block User?", isPresented: $showBlockAlert) {
                Button("Block", role: .destructive) {
                    Task {
                        await userManager.blockUser(userId: userId)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You won't see their items or receive messages. Chats will be hidden.")
            }
            .alert("Report User?", isPresented: $showReportAlert) {
                Button("Spam", role: .destructive) { submitReport(reason: "Spam") }
                Button("Abusive", role: .destructive) { submitReport(reason: "Abusive") }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Why are you reporting this user?")
            }
            .sheet(isPresented: $showAllAchievements) {
                AllAchievementsSheet(achievements: achievements, tradeCount: tradeCount)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                loadPublicProfile()
            }
        }
    }
    
    // MARK: - Header Section
    
    private func headerSection(profile: UserProfile) -> some View {
        VStack(spacing: 12) {
            // Avatar with Level Ring
            ZStack {
                // Progress Ring Background
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 4)
                    .frame(width: 100, height: 100)
                
                // Live Level Progress Ring
                Circle()
                    .trim(from: 0, to: calculateLevelProgress(count: tradeCount))
                    .stroke(
                        AngularGradient(colors: [.cyan, .purple, .cyan], center: .center),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 100, height: 100)
                    .shadow(color: .cyan.opacity(0.5), radius: 10)
                
                AsyncImageView(filename: profile.avatarUrl)
                    .frame(width: 92, height: 92)
                    .clipShape(Circle())
                
                // Premium Crown
                if profile.isPremium {
                    VStack {
                        Spacer()
                        Image(systemName: "crown.fill")
                            .font(.headline)
                            .foregroundStyle(.yellow)
                            .padding(6)
                            .background(Circle().fill(.black))
                            .offset(y: 10)
                    }
                }
            }
            
            // Name, Rank & Verification
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text(profile.username)
                        .font(.title2).bold()
                        .foregroundStyle(.white)
                    
                    if profile.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.cyan)
                            .font(.headline)
                    }
                }
                
                // ✨ Level Badge with Trust Tier
                HStack(spacing: 8) {
                    // Level Badge
                    let level = UserLevel.forTradeCount(tradeCount)
                    HStack(spacing: 4) {
                        Image(systemName: level.icon)
                            .font(.system(size: 10))
                        Text(level.title.uppercased())
                            .font(.system(size: 10, weight: .black))
                    }
                    .foregroundStyle(level.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(level.color.opacity(0.15))
                    .clipShape(Capsule())
                    
                    // Trust Tier Badge
                    HStack(spacing: 4) {
                        Image(systemName: profileTrustTier.icon)
                            .font(.system(size: 10))
                        Text(profileTrustTier.rawValue.uppercased())
                            .font(.system(size: 10, weight: .black))
                    }
                    .foregroundStyle(profileTrustTier.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(profileTrustTier.color.opacity(0.15))
                    .clipShape(Capsule())
                }
                
                // Location & Streak
                HStack(spacing: 12) {
                    Text(profile.location)
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    if currentStreak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("\(currentStreak)")
                                .foregroundStyle(.orange)
                        }
                        .font(.caption.bold())
                    }
                }
                .padding(.top, 2)
            }
            
            // Bio
            Text(profile.bio.isEmpty ? "No bio provided." : profile.bio)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 20)
    }
    
    // MARK: - ✨ Achievements Section (NEW)
    
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ACHIEVEMENTS")
                    .font(.caption)
                    .fontWeight(.black)
                    .foregroundStyle(.white.opacity(0.5))
                
                Spacer()
                
                Button {
                    showAllAchievements = true
                } label: {
                    Text("See All")
                        .font(.caption.bold())
                        .foregroundStyle(.cyan)
                }
            }
            .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(achievements.prefix(6)) { achievement in
                        AchievementBadgeView(type: achievement.type, isUnlocked: true)
                    }
                    
                    // Show placeholder for locked achievements
                    if achievements.count < 3 {
                        ForEach(0..<(3 - achievements.count), id: \.self) { _ in
                            LockedAchievementBadge()
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    // MARK: - Highlights Section
    
    var highlightsSection: some View {
        VStack(spacing: 24) {
            // 1. Reputation Card
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(String(format: "%.1f", rating))")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(.yellow)
                    HStack(spacing: 2) {
                        ForEach(0..<5) { i in
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(Double(i) < rating ? .yellow : .gray.opacity(0.3))
                        }
                    }
                    Text("\(reviewCount) reviews")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Divider().frame(height: 40).background(Color.white.opacity(0.2))
                
                VStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.largeTitle)
                        .foregroundStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom))
                    
                    Text(rating >= 4.5 ? "Top Rated" : (reviewCount > 5 ? "Reliable" : "New Trader"))
                        .font(.headline).bold()
                        .foregroundStyle(.white)
                    
                    Text("Community Status")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .padding(.horizontal)
            
            // 2. Stats Grid (Gamified)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    GlassStatPill(icon: "cube.box.fill", value: "\(items.count)", label: "Items")
                    GlassStatPill(icon: "arrow.triangle.2.circlepath", value: "\(tradeCount)", label: "Trades", color: .purple)
                    GlassStatPill(icon: "tag.fill", value: topCategory, label: "Top Category")
                    
                    if profile?.isVerified == true {
                        GlassStatPill(icon: "checkmark.shield.fill", value: "Verified", label: "Identity", color: .cyan)
                    }
                }
                .padding(.horizontal)
            }
            
            // 3. ISO Categories
            VStack(alignment: .leading, spacing: 10) {
                Text("INTERESTED IN")
                    .font(.caption)
                    .fontWeight(.black)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 24)
                
                if let isos = profile?.isoCategories, !isos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(isos, id: \.self) { iso in
                                Text(iso.uppercased())
                                    .font(.caption).bold()
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.cyan.opacity(0.2))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.cyan.opacity(0.5), lineWidth: 1))
                                    .foregroundStyle(.cyan)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                } else {
                    Text("No specific interests listed.")
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 24)
                }
            }
        }
    }
    
    // MARK: - ✨ Impact Dashboard Section (NEW)
    
    private var impactDashboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ENVIRONMENTAL IMPACT")
                .font(.caption)
                .fontWeight(.black)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 24)
            
            HStack(spacing: 12) {
                // Carbon Saved
                ImpactCard(
                    icon: "leaf.fill",
                    value: calculateCarbonSaved(count: tradeCount),
                    label: "CO₂ Saved",
                    color: .green
                )
                
                // Items Saved
                ImpactCard(
                    icon: "arrow.3.trianglepath",
                    value: "\(tradeCount)",
                    label: "Items Saved",
                    color: .cyan
                )
                
                // Money Saved
                ImpactCard(
                    icon: "dollarsign.circle.fill",
                    value: calculateMoneySaved(count: tradeCount),
                    label: "Est. Saved",
                    color: .yellow
                )
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Active Listings Section
    
    private var activeListingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Active Listings")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
            
            if items.isEmpty {
                Text("No active listings.")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 20)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                    ForEach(items) { item in
                        InventoryItemCard(item: item)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Logic
    
    func loadPublicProfile() {
        isLoading = true
        Task {
            do {
                // Parallel Fetching
                async let pTask = DatabaseService.shared.fetchProfile(userId: userId)
                async let iTask = DatabaseService.shared.fetchUserItems(userId: userId)
                async let rTask = DatabaseService.shared.fetchUserRating(userId: userId)
                async let cTask = DatabaseService.shared.fetchReviewCount(userId: userId)
                async let tTask = DatabaseService.shared.fetchActiveTrades(userId: userId)
                async let aTask = ProgressionManager.shared.fetchAchievements(for: userId)
                
                let (p, allItems, r, c, activeTrades, userAchievements) = try await (pTask, iTask, rTask, cTask, tTask, aTask)
                
                // Calculate Top Category
                let categories = allItems.map { $0.category }
                let counts = categories.reduce(into: [:]) { $0[$1, default: 0] += 1 }
                let top = counts.max(by: { $0.value < $1.value })?.key ?? "None"
                
                await MainActor.run {
                    self.profile = p
                    self.items = allItems
                    self.rating = r
                    self.reviewCount = c
                    self.tradeCount = activeTrades.count
                    self.topCategory = top
                    self.achievements = userAchievements
                    self.currentStreak = p.currentStreak
                    self.longestStreak = p.longestStreak
                    self.isLoading = false
                }
            } catch {
                print("Error loading profile: \(error)")
                await MainActor.run { isLoading = false }
            }
        }
    }
    
    // MARK: - Gamification Helpers
    
    func calculateLevelTitle(count: Int) -> String {
        return UserLevel.forTradeCount(count).title
    }
    
    func calculateLevelProgress(count: Int) -> Double {
        let level = UserLevel.forTradeCount(count)
        if level.tier == 5 { return 1.0 }
        let progressInLevel = count - level.minTrades
        let levelRange = level.maxTrades - level.minTrades + 1
        return Double(progressInLevel) / Double(levelRange)
    }
    
    func calculateCarbonSaved(count: Int) -> String {
        let kg = Double(count) * 2.5
        if kg >= 1000 {
            return String(format: "%.1ft", kg / 1000)
        }
        return String(format: "%.1fkg", kg)
    }
    
    func calculateMoneySaved(count: Int) -> String {
        let amount = count * 25
        if amount >= 1000 {
            return String(format: "$%.1fK", Double(amount) / 1000)
        }
        return "$\(amount)"
    }
    
    func submitReport(reason: String) {
        guard let myId = userManager.currentUser?.id else { return }
        Task {
            try? await DatabaseService.shared.reportUser(reporterId: myId, reportedId: userId, reason: reason)
            dismiss()
        }
    }
}

// MARK: - Achievement Badge View

struct AchievementBadgeView: View {
    let type: AchievementType
    let isUnlocked: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Glow effect based on rarity
                Circle()
                    .fill(type.gradient)
                    .frame(width: 56, height: 56)
                    .blur(radius: type.rarity.glowOpacity > 0 ? 8 : 0)
                    .opacity(type.rarity.glowOpacity)
                
                Circle()
                    .fill(type.gradient)
                    .frame(width: 50, height: 50)
                
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            
            Text(type.title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .frame(width: 60)
        }
    }
}

// MARK: - Locked Achievement Badge

struct LockedAchievementBadge: View {
    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.3))
                )
            
            Text("Locked")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}

// MARK: - Impact Card

struct ImpactCard: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = .green
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(.white)
            
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - All Achievements Sheet

struct AllAchievementsSheet: View {
    let achievements: [Achievement]
    let tradeCount: Int
    
    private var unlockedTypes: Set<AchievementType> {
        Set(achievements.map { $0.type })
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Progress Header
                        VStack(spacing: 8) {
                            Text("\(achievements.count)/\(AchievementType.allCases.count)")
                                .font(.system(size: 48, weight: .heavy))
                                .foregroundStyle(.white)
                            
                            Text("Achievements Unlocked")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                            
                            // Progress Bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 8)
                                    
                                    Capsule()
                                        .fill(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geo.size.width * CGFloat(achievements.count) / CGFloat(AchievementType.allCases.count), height: 8)
                                }
                            }
                            .frame(height: 8)
                            .padding(.horizontal, 40)
                            .padding(.top, 8)
                        }
                        .padding(.top, 20)
                        
                        // Achievement Grid
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 16)], spacing: 20) {
                            ForEach(AchievementType.allCases.sorted { $0.sortOrder < $1.sortOrder }, id: \.self) { type in
                                AchievementGridItem(
                                    type: type,
                                    isUnlocked: unlockedTypes.contains(type),
                                    unlockDate: achievements.first { $0.type == type }?.unlockedAt
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Achievement Grid Item

struct AchievementGridItem: View {
    let type: AchievementType
    let isUnlocked: Bool
    let unlockDate: Date?
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if isUnlocked {
                    // Glow
                    Circle()
                        .fill(type.gradient)
                        .frame(width: 64, height: 64)
                        .blur(radius: type.rarity.glowOpacity > 0 ? 10 : 0)
                        .opacity(type.rarity.glowOpacity)
                    
                    Circle()
                        .fill(type.gradient)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: type.icon)
                        .font(.title)
                        .foregroundStyle(.white)
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    
                    Image(systemName: type.icon)
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.2))
                }
            }
            
            Text(type.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isUnlocked ? .white : .white.opacity(0.4))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            Text(type.description)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            if isUnlocked, let date = unlockDate {
                Text(date, style: .date)
                    .font(.system(size: 8))
                    .foregroundStyle(.cyan.opacity(0.8))
            }
        }
        .frame(width: 100)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isUnlocked ? Color.white.opacity(0.05) : Color.clear)
        )
    }
}

// MARK: - Subviews

struct GlassStatPill: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = .cyan
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.headline).bold()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(width: 100, height: 80)
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
