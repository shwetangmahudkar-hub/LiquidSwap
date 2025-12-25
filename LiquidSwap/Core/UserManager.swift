import Foundation
import SwiftUI
import Combine
import Supabase

// 1. Update Model to match SQL Table exactly
struct UserProfile: Codable {
    var id: UUID
    var username: String
    var bio: String
    var location: String
    var avatarUrl: String?
    var isoCategories: [String] = [] // Maps to text[] in SQL
    
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
    @Published var isLoading = false
    
    // Cloud References
    private let db = DatabaseService.shared
    private let auth = SupabaseConfig.client.auth
    
    var canAddItem: Bool {
        return userItems.count < 5
    }
    
    private init() {
        Task { await loadUserData() }
    }
    
    // MARK: - Data Loading
    @MainActor
    func loadUserData() async {
        guard let session = try? await auth.session else { return }
        let userId = session.user.id
        self.isLoading = true
        
        do {
            // 1. Fetch User's Items (Inventory)
            async let itemsTask = db.fetchUserItems(userId: userId)
            
            // 2. Fetch User's Profile (Cloud)
            // We use a Task to handle the "Profile might not exist yet" scenario
            var profile: UserProfile
            do {
                profile = try await db.fetchProfile(userId: userId)
            } catch {
                // Profile doesn't exist yet (First login)? Create default.
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
                // Save this default immediately so it exists next time
                try? await db.upsertProfile(profile)
            }
            
            // 3. Update State
            self.userItems = try await itemsTask
            self.currentUser = profile
            
            print("✅ User Data Synced: \(profile.username)")
            
        } catch {
            print("❌ Error loading user data: \(error)")
        }
        
        self.isLoading = false
    }
    
    // MARK: - Inventory Actions
    
    @MainActor
    func addItem(title: String, description: String, image: UIImage) async throws {
        guard canAddItem else {
            throw NSError(domain: "App", code: 400, userInfo: [NSLocalizedDescriptionKey: "Limit Reached"])
        }
        
        self.isLoading = true
        defer { self.isLoading = false }
        
        guard let userId = currentUser?.id else { return }
        
        let imageUrl = try await db.uploadImage(image)
        let newItem = TradeItem(
            ownerId: userId,
            title: title,
            description: description,
            condition: "Good",
            category: "General",
            imageUrl: imageUrl
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
        try await db.deleteItem(id: item.id)
        await loadUserData()
        self.isLoading = false
    }
    
    // MARK: - Profile Actions (Now Async & Cloud Synced)
    
    @MainActor
    func updateProfile(username: String, bio: String, location: String, isoCategories: [String]) async {
        guard var profile = currentUser else { return }
        
        // 1. Update Local State (Optimistic)
        profile.username = username
        profile.bio = bio
        profile.location = location
        profile.isoCategories = isoCategories
        self.currentUser = profile
        
        // 2. Sync to Cloud
        do {
            try await db.upsertProfile(profile)
            print("✅ Profile synced to Supabase")
        } catch {
            print("❌ Failed to sync profile: \(error)")
        }
    }
    
    @MainActor
    func updateAvatar(image: UIImage) async {
        guard var profile = currentUser else { return }
        
        do {
            // Upload Image
            let url = try await db.uploadImage(image)
            
            // Update Profile with new URL
            profile.avatarUrl = url
            self.currentUser = profile
            
            // Sync
            try await db.upsertProfile(profile)
            print("✅ Avatar updated")
        } catch {
            print("❌ Failed to update avatar: \(error)")
        }
    }
    
    // Compatibility for Onboarding
    @MainActor
    func completeOnboarding(username: String, bio: String, image: UIImage?) async {
        // Create base profile
        await updateProfile(username: username, bio: bio, location: "Unknown", isoCategories: [])
        
        if let img = image {
            await updateAvatar(image: img)
        }
    }
}
