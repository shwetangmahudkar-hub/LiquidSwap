import Foundation
import SwiftUI
import Combine
import Supabase
import CoreLocation

// MARK: - User Models

struct UserProfile: Codable {
    var id: UUID
    var username: String
    var bio: String
    var location: String
    var avatarUrl: String?
    var isoCategories: [String] = []
    
    // Verification & Access Status
    var isVerified: Bool = false
    var isPremium: Bool = false
    
    // ✨ Trade Count (fetched separately but can be cached)
    var completedTradeCount: Int = 0
    
    // ✨ NEW: Streak & XP Data (stored in DB)
    var lastActiveDate: Date?
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var xp: Int = 0 // ✨ NEW: Experience Points
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case bio
        case location
        case avatarUrl = "avatar_url"
        case isoCategories = "iso_categories"
        case isVerified = "is_verified"
        case isPremium = "is_premium"
        case lastActiveDate = "last_active_date"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case xp
    }
    
    // Fallback init for decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        bio = try container.decode(String.self, forKey: .bio)
        location = try container.decode(String.self, forKey: .location)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        isoCategories = try container.decodeIfPresent([String].self, forKey: .isoCategories) ?? []
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
        isPremium = try container.decodeIfPresent(Bool.self, forKey: .isPremium) ?? false
        lastActiveDate = try container.decodeIfPresent(Date.self, forKey: .lastActiveDate)
        currentStreak = try container.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        longestStreak = try container.decodeIfPresent(Int.self, forKey: .longestStreak) ?? 0
        xp = try container.decodeIfPresent(Int.self, forKey: .xp) ?? 0
    }
    
    // Explicit Init
    init(id: UUID, username: String, bio: String, location: String, avatarUrl: String?, isoCategories: [String], isVerified: Bool = false, isPremium: Bool = false, lastActiveDate: Date? = nil, currentStreak: Int = 0, longestStreak: Int = 0, xp: Int = 0) {
        self.id = id
        self.username = username
        self.bio = bio
        self.location = location
        self.avatarUrl = avatarUrl
        self.isoCategories = isoCategories
        self.isVerified = isVerified
        self.isPremium = isPremium
        self.lastActiveDate = lastActiveDate
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.xp = xp
    }
}

// MARK: - Level Definition

struct UserLevel {
    let tier: Int
    let title: String
    let minTrades: Int
    let maxTrades: Int
    let icon: String
    let color: Color
    let perks: [String]
    
    // All available levels
    static let all: [UserLevel] = [
        UserLevel(tier: 1, title: "Novice Swapper", minTrades: 0, maxTrades: 2, icon: "leaf", color: .gray, perks: ["Basic access", "List up to 20 items"]),
        UserLevel(tier: 2, title: "Eco Trader", minTrades: 3, maxTrades: 9, icon: "leaf.fill", color: .green, perks: ["Custom profile color", "Eco Trader badge"]),
        UserLevel(tier: 3, title: "Swap Savant", minTrades: 10, maxTrades: 24, icon: "star.fill", color: .cyan, perks: ["Priority in local feed", "Savant badge"]),
        UserLevel(tier: 4, title: "Circular Hero", minTrades: 25, maxTrades: 49, icon: "shield.fill", color: .purple, perks: ["Hero badge", "Extended item limit (30)"]),
        UserLevel(tier: 5, title: "Legendary Trader", minTrades: 50, maxTrades: Int.max, icon: "crown.fill", color: .yellow, perks: ["Legend flair", "Unlimited items", "Priority support"])
    ]
    
    static func forTradeCount(_ count: Int) -> UserLevel {
        return all.first { count >= $0.minTrades && count <= $0.maxTrades } ?? all[0]
    }
}

// MARK: - Trust Tier Definition

enum TrustTier: String, CaseIterable {
    case newcomer = "Newcomer"
    case bronze = "Bronze"
    case silver = "Silver"
    case gold = "Gold"
    case platinum = "Platinum"
    
    var icon: String {
        switch self {
        case .newcomer: return "person.crop.circle"
        case .bronze: return "shield"
        case .silver: return "shield.fill"
        case .gold: return "shield.lefthalf.filled"
        case .platinum: return "checkmark.shield.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .newcomer: return .gray
        case .bronze: return .brown
        case .silver: return .gray
        case .gold: return .yellow
        case .platinum: return .cyan
        }
    }
    
    static func fromScore(_ score: Int) -> TrustTier {
        switch score {
        case 0..<50: return .newcomer
        case 50..<150: return .bronze
        case 150..<300: return .silver
        case 300..<600: return .gold
        default: return .platinum
        }
    }
}

// MARK: - User Manager

@MainActor
class UserManager: ObservableObject {
    static let shared = UserManager()
    
    // User Data
    @Published var currentUser: UserProfile?
    @Published var userItems: [TradeItem] = []
    
    // Rating Stats
    @Published var userRating: Double = 0.0
    @Published var userReviewCount: Int = 0
    @Published var completedTradeCount: Int = 0
    
    // ✨ NEW: Progression Stats
    @Published var reviewsGivenCount: Int = 0
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    
    @Published var isLoading = false
    
    // Blocked Users List
    @Published var blockedUserIds: [UUID] = []
    
    // Cloud References
    private let db = DatabaseService.shared
    private let client = SupabaseConfig.client
    
    // MARK: - Access Control
    
    var isPremium: Bool {
        return currentUser?.isPremium ?? false
    }
    
    var canAddItem: Bool {
        if isPremium { return true }
        // Level-based item limits
        let level = currentLevel
        if level.tier >= 5 { return true } // Legendary = unlimited
        if level.tier >= 4 { return userItems.count < 30 } // Hero = 30
        return userItems.count < 20 // Default = 20
    }
    
    // MARK: - Level System
    
    var currentLevel: UserLevel {
        return UserLevel.forTradeCount(completedTradeCount)
    }
    
    var currentLevelTitle: String {
        return currentLevel.title
    }
    
    var levelProgress: Double {
        let level = currentLevel
        if level.tier == 5 { return 1.0 } // Max level
        
        let progressInLevel = completedTradeCount - level.minTrades
        let levelRange = level.maxTrades - level.minTrades + 1
        return Double(progressInLevel) / Double(levelRange)
    }
    
    var tradesToNextLevel: Int {
        let level = currentLevel
        if level.tier == 5 { return 0 }
        return (level.maxTrades + 1) - completedTradeCount
    }
    
    var nextLevel: UserLevel? {
        let current = currentLevel
        return UserLevel.all.first { $0.tier == current.tier + 1 }
    }
    
    // MARK: - Trust Score System
    
    /// Calculates trust score based on multiple factors
    /// Formula: (trades × 5) + (rating × 10) + (reviews × 2) + (verified ? 50 : 0) + (streak × 1) + (XP / 10)
    var trustScore: Int {
        var score = 0
        score += completedTradeCount * 5
        score += Int(userRating * 10)
        score += userReviewCount * 2
        score += (currentUser?.isVerified == true) ? 50 : 0
        score += Int(Double(currentStreak) * 1.0)
        
        // ✨ XP Contribution (10 XP = 1 Trust Point)
        score += (currentUser?.xp ?? 0) / 10
        
        return score
    }
    
    var trustTier: TrustTier {
        return TrustTier.fromScore(trustScore)
    }
    
    // MARK: - Impact Statistics
    
    var carbonSaved: Double {
        return Double(completedTradeCount) * 2.5
    }
    
    var carbonSavedFormatted: String {
        if carbonSaved >= 1000 {
            return String(format: "%.1f tons", carbonSaved / 1000)
        }
        return String(format: "%.1f kg", carbonSaved)
    }
    
    var itemsSavedFromLandfill: Int {
        return completedTradeCount
    }
    
    /// Estimated money saved (rough average of $25 per trade)
    var estimatedMoneySaved: Int {
        return completedTradeCount * 25
    }
    
    var moneySavedFormatted: String {
        let amount = estimatedMoneySaved
        if amount >= 1000 {
            return String(format: "$%.1fK", Double(amount) / 1000)
        }
        return "$\(amount)"
    }
    
    // MARK: - Streak Helpers
    
    var streakStatus: String {
        if currentStreak == 0 {
            return "Start your streak!"
        } else if currentStreak == 1 {
            return "1 day streak 🔥"
        } else {
            return "\(currentStreak) day streak 🔥"
        }
    }
    
    var isOnStreak: Bool {
        return currentStreak > 0
    }
    
    // MARK: - Init
    
    private init() {
        setupAuthListener()
    }
    
    // MARK: - Auto-Sync Logic
    
    private func setupAuthListener() {
        Task {
            for await state in client.auth.authStateChanges {
                if let _ = state.session {
                    print("👤 UserManager: Session detected. Loading data...")
                    await loadUserData()
                } else {
                    print("👤 UserManager: No session. Clearing data.")
                    clearData()
                }
            }
        }
    }
    
    func clearData() {
        self.currentUser = nil
        self.userItems = []
        self.userRating = 0.0
        self.userReviewCount = 0
        self.completedTradeCount = 0
        self.reviewsGivenCount = 0
        self.currentStreak = 0
        self.longestStreak = 0
        self.blockedUserIds = []
        
        // ✨ Clear progression data on logout
        ProgressionManager.shared.clearData()
    }
    
    // MARK: - Data Loading
    
    func loadUserData() async {
        guard let session = try? await client.auth.session else {
            print("❌ UserManager: No active session")
            return
        }
        let userId = session.user.id
        self.isLoading = true
        
        do {
            // Fetch everything concurrently
            async let items = db.fetchUserItems(userId: userId)
            async let rating = db.fetchUserRating(userId: userId)
            async let reviews = db.fetchReviewCount(userId: userId)
            async let blocked = db.fetchBlockedUsers(userId: userId)
            async let tradeCount = fetchRealCompletedTradeCount(userId: userId)
            async let givenReviews = db.fetchReviewsGivenCount(userId: userId)
            
            // Handle Profile - Create if doesn't exist
            let profile = await getOrCreateProfile(userId: userId, email: session.user.email)
            
            // Await all other results
            let (fetchedItems, fetchedRating, fetchedReviews, fetchedBlocked, count, given) = try await (items, rating, reviews, blocked, tradeCount, givenReviews)
            
            // Update state
            self.userItems = fetchedItems
            self.userRating = fetchedRating
            self.userReviewCount = fetchedReviews
            self.blockedUserIds = fetchedBlocked
            self.completedTradeCount = count
            self.reviewsGivenCount = given
            self.currentUser = profile
            
            // Sync streak data from profile
            self.currentStreak = profile?.currentStreak ?? 0
            self.longestStreak = profile?.longestStreak ?? 0
            
            // ✨ Update streak on app open
            await updateLoginStreak()
            
            print("✅ User Data Loaded: \(profile?.username ?? "Unknown") | Trades: \(count) | Streak: \(currentStreak) | XP: \(profile?.xp ?? 0)")
            
        } catch {
            print("❌ Error loading user data: \(error)")
        }
        
        self.isLoading = false
        
        // ✨ PROGRESSION TRIGGER: Check achievements on login
        await ProgressionManager.shared.onUserLogin()
    }
    
    // ✨ NEW: Lightweight Count Query
    private func fetchRealCompletedTradeCount(userId: UUID) async throws -> Int {
        let count = try await client
            .from("trades")
            .select("id", head: true, count: .exact)
            .or("sender_id.eq.\(userId),receiver_id.eq.\(userId)")
            .eq("status", value: "completed")
            .execute()
            .count
        
        return count ?? 0
    }
    
    // MARK: - Streak Management
    
    /// Updates login streak when user opens app
    private func updateLoginStreak() async {
        guard var profile = currentUser else { return }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastActive = profile.lastActiveDate {
            let lastActiveDay = calendar.startOfDay(for: lastActive)
            let daysDifference = calendar.dateComponents([.day], from: lastActiveDay, to: today).day ?? 0
            
            if daysDifference == 0 {
                // Same day - no change needed
                return
            } else if daysDifference == 1 {
                // Consecutive day - increment streak
                profile.currentStreak += 1
                if profile.currentStreak > profile.longestStreak {
                    profile.longestStreak = profile.currentStreak
                }
            } else {
                // Streak broken - reset
                profile.currentStreak = 1
            }
        } else {
            // First login ever
            profile.currentStreak = 1
            profile.longestStreak = 1
        }
        
        profile.lastActiveDate = today
        
        // Update local state
        self.currentStreak = profile.currentStreak
        self.longestStreak = profile.longestStreak
        self.currentUser = profile
        
        // Persist to database
        do {
            try await db.updateStreak(
                userId: profile.id,
                currentStreak: profile.currentStreak,
                longestStreak: profile.longestStreak,
                lastActiveDate: today
            )
        } catch {
            print("❌ Failed to update streak: \(error)")
        }
    }
    
    // MARK: - XP Management
    
    /// Awards XP to the current user and persists it
    func awardXP(amount: Int) {
        guard var profile = currentUser else { return }
        
        // 1. Optimistic Update (Instant Feedback)
        profile.xp += amount
        self.currentUser = profile
        
        print("⚡️ XP Awarded: +\(amount) | Total: \(profile.xp)")
        
        // 2. Persist to DB (Fire & Forget)
        Task {
            do {
                try await db.updateUserXP(userId: profile.id, xp: profile.xp)
            } catch {
                print("❌ Failed to persist XP: \(error)")
            }
        }
    }
    
    // MARK: - Profile Creation Helper
    
    private func getOrCreateProfile(userId: UUID, email: String?) async -> UserProfile? {
        do {
            let existingProfile = try await db.fetchProfile(userId: userId)
            return existingProfile
        } catch {
            print("👤 No profile found, creating new profile...")
        }
        
        let emailName = email?.components(separatedBy: "@").first ?? "Trader"
        let newProfile = UserProfile(
            id: userId,
            username: emailName,
            bio: "Ready to trade!",
            location: "Unknown",
            avatarUrl: nil,
            isoCategories: [],
            isVerified: false,
            isPremium: false,
            lastActiveDate: Date(),
            currentStreak: 1,
            longestStreak: 1,
            xp: 0
        )
        
        do {
            try await db.upsertProfile(newProfile)
            print("✅ New profile created successfully for: \(newProfile.username)")
            return newProfile
        } catch {
            print("❌ CRITICAL: Failed to create profile: \(error)")
            return newProfile
        }
    }
    
    // MARK: - Inventory Actions
    
    func addItem(title: String, description: String, image: UIImage, customLat: Double? = nil, customLon: Double? = nil) async throws {
        guard canAddItem else {
            throw NSError(domain: "App", code: 400, userInfo: [NSLocalizedDescriptionKey: "Limit Reached"])
        }
        
        self.isLoading = true
        defer { self.isLoading = false }
        
        guard let userId = currentUser?.id else { return }
        
        let location = LocationManager.shared.userLocation
        let finalLat = customLat ?? location?.coordinate.latitude
        let finalLon = customLon ?? location?.coordinate.longitude
        
        let imageUrl = try await db.uploadImage(image)
        let newItem = TradeItem(
            ownerId: userId,
            title: title,
            description: description,
            condition: "Good",
            category: "General",
            imageUrl: imageUrl,
            latitude: finalLat,
            longitude: finalLon
        )
        
        try await db.createItem(item: newItem)
        await loadUserData()
        
        // ✨ PROGRESSION TRIGGER: Check achievements after listing item
        await ProgressionManager.shared.onItemListed()
        
        // ✨ XP Reward for Listing
        awardXP(amount: 50)
    }
    
    func updateItem(_ item: TradeItem) async throws {
        self.isLoading = true
        try await db.updateItem(item)
        if let index = userItems.firstIndex(where: { $0.id == item.id }) {
            userItems[index] = item
        }
        self.isLoading = false
    }
    
    func deleteItem(item: TradeItem) async throws {
        self.isLoading = true
        defer { self.isLoading = false }
        
        do {
            try await db.deleteItem(id: item.id)
            await loadUserData()
            print("✅ Item deleted successfully")
        } catch {
            print("❌ Failed to delete item: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Profile Actions
    
    func updateProfile(username: String, bio: String, location: String, isoCategories: [String]) async {
        var userId: UUID?
        if let currentId = currentUser?.id {
            userId = currentId
        } else if let session = try? await client.auth.session {
            userId = session.user.id
        }
        
        guard let userId = userId else { return }
        
        var profile = currentUser ?? UserProfile(
            id: userId,
            username: username,
            bio: bio,
            location: location,
            avatarUrl: nil,
            isoCategories: isoCategories,
            isVerified: false,
            isPremium: false,
            xp: 0
        )
        
        profile.username = username
        profile.bio = bio
        profile.location = location
        profile.isoCategories = isoCategories
        
        self.currentUser = profile
        
        do {
            try await db.upsertProfile(profile)
        } catch {
            print("❌ Failed to update profile: \(error)")
        }
    }
    
    func updateAvatar(image: UIImage) async {
        guard var profile = currentUser else { return }
        
        do {
            let url = try await db.uploadImage(image)
            profile.avatarUrl = url
            self.currentUser = profile
            try await db.upsertProfile(profile)
        } catch {
            print("❌ Failed to update avatar: \(error)")
        }
    }
    
    func upgradeToPremium() async {
        guard var profile = currentUser else { return }
        profile.isPremium = true
        self.currentUser = profile
        try? await db.upsertProfile(profile)
    }
    
    func debugTogglePremium() {
        guard var profile = currentUser else { return }
        profile.isPremium.toggle()
        self.currentUser = profile
        Task { try? await db.upsertProfile(profile) }
    }
    
    func markAsVerified() async {
        guard var profile = currentUser else { return }
        profile.isVerified = true
        self.currentUser = profile
        Task { try? await db.upsertProfile(profile) }
    }
    
    func completeOnboarding(username: String, bio: String, image: UIImage?) async {
        var userId: UUID?
        if let currentId = currentUser?.id {
            userId = currentId
        } else if let session = try? await client.auth.session {
            userId = session.user.id
        }
        
        guard let userId = userId else { return }
        
        var profile = currentUser ?? UserProfile(
            id: userId,
            username: username,
            bio: bio,
            location: "Unknown",
            avatarUrl: nil,
            isoCategories: [],
            isVerified: false,
            isPremium: false,
            lastActiveDate: Date(),
            currentStreak: 1,
            longestStreak: 1,
            xp: 0
        )
        
        profile.username = username
        profile.bio = bio
        
        if let img = image {
            if let url = try? await db.uploadImage(img) {
                profile.avatarUrl = url
            }
        }
        
        do {
            try await db.upsertProfile(profile)
            self.currentUser = profile
            
            // ✨ Bonus XP for onboarding
            awardXP(amount: 100)
        } catch {
            print("❌ Failed to save profile: \(error)")
            self.currentUser = profile
        }
    }
    
    // MARK: - Blocking Actions
    
    func blockUser(userId: UUID) async {
        guard let myId = currentUser?.id else { return }
        if !blockedUserIds.contains(userId) { blockedUserIds.append(userId) }
        
        do {
            try await db.blockUser(blockerId: myId, blockedId: userId)
            await FeedManager.shared.fetchFeed()
        } catch {
            if let index = blockedUserIds.firstIndex(of: userId) { blockedUserIds.remove(at: index) }
        }
    }
    
    func unblockUser(userId: UUID) async {
        guard let myId = currentUser?.id else { return }
        if let index = blockedUserIds.firstIndex(of: userId) { blockedUserIds.remove(at: index) }
        
        do {
            try await db.unblockUser(blockerId: myId, blockedId: userId)
        } catch {
            blockedUserIds.append(userId)
        }
    }
}
