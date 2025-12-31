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
    var isPremium: Bool = false // Internal variable, mapped to "Early Access" in UI
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case bio
        case location
        case avatarUrl = "avatar_url"
        case isoCategories = "iso_categories"
        case isVerified = "is_verified"
        case isPremium = "is_premium"
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
    }
    
    // Explicit Init
    init(id: UUID, username: String, bio: String, location: String, avatarUrl: String?, isoCategories: [String], isVerified: Bool = false, isPremium: Bool = false) {
        self.id = id
        self.username = username
        self.bio = bio
        self.location = location
        self.avatarUrl = avatarUrl
        self.isoCategories = isoCategories
        self.isVerified = isVerified
        self.isPremium = isPremium
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
    
    @Published var isLoading = false
    
    // Blocked Users List
    @Published var blockedUserIds: [UUID] = []
    
    // Cloud References
    private let db = DatabaseService.shared
    private let client = SupabaseConfig.client
    
    // MARK: - Access Control
    
    // ✨ LOGIC RESTORED: Now strictly checks the user profile
    var isPremium: Bool {
        return currentUser?.isPremium ?? false
    }
    
    // Logic: Enforce 20-item limit ONLY for regular users
    var canAddItem: Bool {
        if isPremium { return true }
        return userItems.count < 20
    }
    
    // MARK: - Gamification Computed Properties
    
    var currentLevelTitle: String {
        switch completedTradeCount {
        case 0...2: return "Novice Swapper"
        case 3...9: return "Eco Trader"
        case 10...24: return "Swap Savant"
        case 25...49: return "Circular Hero"
        default: return "Legendary Trader"
    }
    }
    
    var levelProgress: Double {
        let count = Double(completedTradeCount)
        switch completedTradeCount {
        case 0...2: return count / 3.0
        case 3...9: return (count - 3) / 7.0
        case 10...24: return (count - 10) / 15.0
        case 25...49: return (count - 25) / 25.0
        default: return 1.0
        }
    }
    
    var carbonSaved: String {
        let kg = Double(completedTradeCount) * 2.5
        return String(format: "%.1f kg", kg)
    }
    
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
                    await clearData()
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
        self.blockedUserIds = []
    }
    
    // MARK: - Data Loading
    
    func loadUserData() async {
        guard let session = try? await client.auth.session else { return }
        let userId = session.user.id
        self.isLoading = true
        
        do {
            // Fetch everything concurrently
            async let items = db.fetchUserItems(userId: userId)
            async let rating = db.fetchUserRating(userId: userId)
            async let reviews = db.fetchReviewCount(userId: userId)
            async let blocked = db.fetchBlockedUsers(userId: userId)
            async let trades = db.fetchActiveTrades(userId: userId)
            
            // Handle Profile separately as it might not exist
            var profile: UserProfile
            do {
                profile = try await db.fetchProfile(userId: userId)
            } catch {
                print("👤 No profile found, creating default.")
                let emailName = session.user.email?.components(separatedBy: "@").first ?? "Trader"
                profile = UserProfile(
                    id: userId,
                    username: emailName,
                    bio: "Ready to trade!",
                    location: "Unknown",
                    avatarUrl: nil,
                    isoCategories: [],
                    isPremium: false
                )
                try? await db.upsertProfile(profile)
            }
            
            // Await all other results
            let (fetchedItems, fetchedRating, fetchedReviews, fetchedBlocked, fetchedTrades) = try await (items, rating, reviews, blocked, trades)
            
            // Update state
            self.userItems = fetchedItems
            self.userRating = fetchedRating
            self.userReviewCount = fetchedReviews
            self.blockedUserIds = fetchedBlocked
            self.completedTradeCount = fetchedTrades.count
            self.currentUser = profile
            
            print("✅ User Data Loaded: \(profile.username) | Early Access: \(isPremium)")
            
        } catch {
            print("❌ Error loading user data: \(error)")
        }
        
        self.isLoading = false
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
        guard var profile = currentUser else { return }
        profile.username = username
        profile.bio = bio
        profile.location = location
        profile.isoCategories = isoCategories
        self.currentUser = profile
        try? await db.upsertProfile(profile)
    }
    
    func updateAvatar(image: UIImage) async {
        guard var profile = currentUser else { return }
        if let url = try? await db.uploadImage(image) {
            profile.avatarUrl = url
            self.currentUser = profile
            try? await db.upsertProfile(profile)
        }
    }
    
    func upgradeToPremium() async {
        guard var profile = currentUser else { return }
        profile.isPremium = true
        self.currentUser = profile
        try? await db.upsertProfile(profile)
        print("🎉 User upgraded to Early Access!")
    }
    
    // ✨ NEW: Dev Tool for Testing
    func debugTogglePremium() {
        guard var profile = currentUser else { return }
        profile.isPremium.toggle()
        self.currentUser = profile
        
        Task {
            try? await db.upsertProfile(profile)
            print("🔧 Dev Mode: Access is now \(profile.isPremium)")
        }
    }
    
    func markAsVerified() async {
        guard var profile = currentUser else { return }
        profile.isVerified = true
        self.currentUser = profile
        try? await db.upsertProfile(profile)
    }
    
    func completeOnboarding(username: String, bio: String, image: UIImage?) async {
        await updateProfile(username: username, bio: bio, location: "Unknown", isoCategories: [])
        if let img = image {
            await updateAvatar(image: img)
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
