import Foundation
import SwiftUI
import Combine
import Supabase
import CoreLocation

// Model stays the same
struct UserProfile: Codable {
    var id: UUID
    var username: String
    var bio: String
    var location: String
    var avatarUrl: String?
    var isoCategories: [String] = []
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case bio
        case location
        case avatarUrl = "avatar_url"
        case isoCategories = "iso_categories"
    }
}

class UserManager: ObservableObject {
    static let shared = UserManager()
    
    // User Data
    @Published var currentUser: UserProfile?
    @Published var userItems: [TradeItem] = []
    
    // Rating Stats
    @Published var userRating: Double = 0.0
    @Published var userReviewCount: Int = 0
    
    @Published var isLoading = false
    
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
    
    @MainActor
    func clearData() {
        self.currentUser = nil
        self.userItems = []
        self.userRating = 0.0
        self.userReviewCount = 0
    }
    
    // MARK: - Data Loading
    @MainActor
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
            
            // 3. Fetch User's Profile
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
            
            // 4. Await all data
            self.userItems = try await itemsTask
            self.userRating = try await ratingTask
            self.userReviewCount = try await countTask
            self.currentUser = profile
            
            print("✅ User Data Loaded: \(profile.username) (Rating: \(self.userRating))")
            
        } catch {
            print("❌ Error loading user data: \(error)")
        }
        
        self.isLoading = false
    }
    
    // MARK: - Inventory Actions
    
    // 🛡️ SAFETY UPDATE: Added customLat/customLon parameters
    @MainActor
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
    
    @MainActor
    func updateItem(_ item: TradeItem) async throws {
        self.isLoading = true
        try await db.updateItem(item)
        if let index = userItems.firstIndex(where: { $0.id == item.id }) {
            userItems[index] = item
        }
        self.isLoading = false
    }
    
    @MainActor
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
    
    @MainActor
    func updateProfile(username: String, bio: String, location: String, isoCategories: [String]) async {
        guard var profile = currentUser else { return }
        profile.username = username
        profile.bio = bio
        profile.location = location
        profile.isoCategories = isoCategories
        self.currentUser = profile
        try? await db.upsertProfile(profile)
    }
    
    @MainActor
    func updateAvatar(image: UIImage) async {
        guard var profile = currentUser else { return }
        if let url = try? await db.uploadImage(image) {
            profile.avatarUrl = url
            self.currentUser = profile
            try? await db.upsertProfile(profile)
        }
    }
    
    @MainActor
    func completeOnboarding(username: String, bio: String, image: UIImage?) async {
        await updateProfile(username: username, bio: bio, location: "Unknown", isoCategories: [])
        if let img = image {
            await updateAvatar(image: img)
        }
    }
}
