import Foundation
import SwiftUI
import Combine
import Supabase

class UserManager: ObservableObject {
    static let shared = UserManager()
    
    @Published var currentUser: UserProfile?
    @Published var userItems: [TradeItem] = []
    @Published var isLoading = false
    
    private let db = DatabaseService.shared
    private let auth = SupabaseConfig.client.auth
    
    private init() {
        Task {
            await loadUserData()
        }
    }
    
    // MARK: - Data Loading
    @MainActor
    func loadUserData() async {
        // 1. Check Auth Session
        guard let session = try? await auth.session else {
            print("⚠️ UserManager: No active session found.")
            return
        }
        
        let userId = session.user.id
        self.isLoading = true
        
        do {
            // 2. Fetch Items
            let items = try await db.fetchUserItems(userId: userId)
            self.userItems = items
            
            // 3. Set Profile
            self.currentUser = UserProfile(
                id: userId,
                username: session.user.email?.components(separatedBy: "@").first ?? "Trader",
                bio: "Ready to trade!",
                location: "Unknown",
                avatarUrl: nil
            )
            print("✅ User Data Loaded: \(self.userItems.count) items.")
            
        } catch {
            print("❌ Error loading user data: \(error)")
        }
        
        self.isLoading = false
    }
    
    // MARK: - Actions
    
    // UPDATED: Now 'async throws' so the UI can catch errors
    @MainActor
    func addItem(title: String, description: String, image: UIImage) async throws {
        self.isLoading = true
        
        // Ensure we have a user
        guard let userId = currentUser?.id else {
            self.isLoading = false
            throw NSError(domain: "App", code: 401, userInfo: [NSLocalizedDescriptionKey: "You must be logged in to post items."])
        }
        
        do {
            // 1. Upload Image
            let imageUrl = try await db.uploadImage(image)
            
            // 2. Create Object
            let newItem = TradeItem(
                ownerId: userId,
                title: title,
                description: description,
                condition: "Good",
                category: "General",
                imageUrl: imageUrl
            )
            
            // 3. Save to DB
            try await db.createItem(item: newItem)
            
            // 4. Refresh Data
            await loadUserData()
            
            self.isLoading = false
            print("✅ Item Saved Successfully!")
            
        } catch {
            self.isLoading = false
            print("❌ Failed to add item: \(error)")
            throw error // Pass error back to UI
        }
    }
    
    func deleteItem(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { userItems[$0] }
        userItems.remove(atOffsets: offsets)
        
        Task {
            for item in itemsToDelete {
                try? await db.deleteItem(id: item.id)
            }
        }
    }
    
    // Stubs for compatibility
    func updateProfile(username: String, bio: String, location: String) {}
    func updateAvatar(image: UIImage) {}
    func completeOnboarding(username: String, bio: String, image: UIImage?) {}
    func updateItem(item: TradeItem) {}
}

// Ensure Model is available here
struct UserProfile: Codable {
    var id: UUID
    var username: String
    var bio: String
    var location: String
    var avatarUrl: String?
}
