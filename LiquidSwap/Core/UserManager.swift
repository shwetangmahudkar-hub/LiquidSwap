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
    
    // Verification Status
    var isVerified: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case bio
        case location
        case avatarUrl = "avatar_url"
        case isoCategories = "iso_categories"
        case isVerified = "is_verified"
    }
    
    // Fallback init for decoding if column is missing (Backward Compatibility)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        bio = try container.decode(String.self, forKey: .bio)
        location = try container.decode(String.self, forKey: .location)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        isoCategories = try container.decodeIfPresent([String].self, forKey: .isoCategories) ?? []
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
    }
    
    // Explicit Init
    init(id: UUID, username: String, bio: String, location: String, avatarUrl: String?, isoCategories: [String], isVerified: Bool = false) {
        self.id = id
        self.username = username
        self.bio = bio
        self.location = location
        self.avatarUrl = avatarUrl
        self.isoCategories = isoCategories
        self.isVerified = isVerified
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
    
    @Published var isLoading = false
    
    // Blocked Users List
    @Published var blockedUserIds: [UUID] = []
    
    // Cloud References
    private let db = DatabaseService.shared
    private let client = SupabaseConfig.client
    
    // Logic: Enforce 5-item limit
    var canAddItem: Bool {
        return userItems.count < 5
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
        self.blockedUserIds = [] // Clear blocks
    }
    
    // MARK: - Data Loading
    
    func loadUserData() async {
        guard let session = try? await client.auth.session else { return }
        let userId = session.user.id
        self.isLoading = true
        
        do {
            // 1. Fetch User's Items (Inventory)
            async let itemsTask = db.fetchUserItems(userId: userId)
            
            // 2. Fetch Rating Stats in Parallel
            async let ratingTask = db.fetchUserRating(userId: userId)
            async let countTask = db.fetchReviewCount(userId: userId)
            
            // 3. Fetch Blocked Users
            async let blockedTask = db.fetchBlockedUsers(userId: userId)
            
            // 4. Fetch User's Profile
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
                    isoCategories: []
                )
                try? await db.upsertProfile(profile)
            }
            
            // 5. Await all data
            self.userItems = try await itemsTask
            self.userRating = try await ratingTask
            self.userReviewCount = try await countTask
            self.blockedUserIds = try await blockedTask
            self.currentUser = profile
            
            print("✅ User Data Loaded: \(profile.username) (Rating: \(self.userRating), Blocked: \(self.blockedUserIds.count))")
            
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
        
        // Use custom coords (fuzzed) if provided, otherwise fall back to raw location
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
        
        // Optimistic Update
        if !blockedUserIds.contains(userId) {
            blockedUserIds.append(userId)
        }
        
        do {
            try await db.blockUser(blockerId: myId, blockedId: userId)
            print("✅ Blocked user \(userId)")
            
            // Post-Block Cleanup: Force Feed & Trades to refresh
            // NOTE: This 'await' is now valid because FeedManager.fetchFeed is async
            await FeedManager.shared.fetchFeed()
            
            // If you have a TradeManager, refresh it too (commented out if not available yet)
            // await TradeManager.shared.loadTradesData()
            
        } catch {
            print("❌ Failed to block: \(error)")
            // Revert
            if let index = blockedUserIds.firstIndex(of: userId) {
                blockedUserIds.remove(at: index)
            }
        }
    }
    
    func unblockUser(userId: UUID) async {
        guard let myId = currentUser?.id else { return }
        
        // Optimistic Update
        if let index = blockedUserIds.firstIndex(of: userId) {
            blockedUserIds.remove(at: index)
        }
        
        do {
            try await db.unblockUser(blockerId: myId, blockedId: userId)
            print("✅ Unblocked user \(userId)")
        } catch {
            print("❌ Failed to unblock: \(error)")
            // Revert
            blockedUserIds.append(userId)
        }
    }
}
