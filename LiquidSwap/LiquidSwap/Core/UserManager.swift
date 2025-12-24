import Foundation
import SwiftUI
import Combine
import Supabase

class UserManager: ObservableObject {
    static let shared = UserManager()
    
    // User Data
    @Published var currentUser: UserProfile?
    @Published var userItems: [TradeItem] = []
    @Published var isLoading = false
    
    // Cloud References
    private let db = DatabaseService.shared
    private let auth = SupabaseConfig.client.auth
    
    // Logic: Enforce 5-item limit
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
            // 1. Fetch User's Items from Cloud
            let items = try await db.fetchUserItems(userId: userId)
            self.userItems = items
            
            // 2. Fetch/Setup Profile
            // Preserve existing ISO categories if we already loaded them, or load from disk
            let savedISO = UserDefaults.standard.stringArray(forKey: "userISO_\(userId)") ?? []
            let defaultName = session.user.email?.components(separatedBy: "@").first ?? "Trader"
            
            // If we already have a profile in memory, keep its text edits (Bio/Location), otherwise create new
            var profile = self.currentUser ?? UserProfile(
                id: userId,
                username: defaultName,
                bio: "Ready to trade!",
                location: "Unknown",
                avatarUrl: nil,
                isoCategories: savedISO
            )
            
            // Ensure ISO is synced
            profile.isoCategories = savedISO
            self.currentUser = profile
            
            print("✅ User Data Loaded: \(self.userItems.count) items.")
            
        } catch {
            print("❌ Error loading user data: \(error)")
        }
        
        self.isLoading = false
    }
    
    // MARK: - Inventory Actions
    
    @MainActor
    func addItem(title: String, description: String, image: UIImage) async throws {
        guard canAddItem else {
            throw NSError(domain: "App", code: 400, userInfo: [NSLocalizedDescriptionKey: "You have reached the 5-item limit. Delete an item to add a new one."])
        }
        
        self.isLoading = true
        guard let userId = currentUser?.id else { self.isLoading = false; return }
        
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
        self.isLoading = false
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
    
    // MARK: - Profile Actions
    
    func updateProfile(username: String, bio: String, location: String, isoCategories: [String]) {
        // Update local state
        currentUser?.username = username
        currentUser?.bio = bio
        currentUser?.location = location
        currentUser?.isoCategories = isoCategories
        
        // Persist ISO preferences
        if let uid = currentUser?.id {
            UserDefaults.standard.set(isoCategories, forKey: "userISO_\(uid)")
        }
    }
    
    func updateAvatar(image: UIImage) {
        Task {
            if let url = try? await db.uploadImage(image) {
                DispatchQueue.main.async {
                    self.currentUser?.avatarUrl = url
                }
            }
        }
    }
    
    // Compatibility
    func completeOnboarding(username: String, bio: String, image: UIImage?) {
        updateProfile(username: username, bio: bio, location: currentUser?.location ?? "Unknown", isoCategories: [])
        if let img = image {
            updateAvatar(image: img)
        }
    }
}

// Updated User Profile Model
struct UserProfile: Codable {
    var id: UUID
    var username: String
    var bio: String
    var location: String
    var avatarUrl: String?
    var isoCategories: [String] = [] // New Field
}
