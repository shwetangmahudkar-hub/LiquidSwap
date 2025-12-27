import Foundation
import Combine
import SwiftUI
import CoreLocation
import Supabase

@MainActor
class FeedManager: ObservableObject {
    private var allItems: [TradeItem] = []
    
    @Published var items: [TradeItem] = []
    @Published var isLoading = false
    @Published var error: String?
    
    // Debug info to verify it's working
    @Published var debugInfo: String = "Initializing..."
    
    private let db = DatabaseService.shared
    private let userManager = UserManager.shared
    private let locationManager = LocationManager.shared
    private let client = SupabaseConfig.client
    
    func fetchFeed() async {
        self.isLoading = true
        self.error = nil
        self.debugInfo = "Checking Auth..."
        
        // 1. Get User ID (Robust Check)
        var currentUserId = userManager.currentUser?.id
        if currentUserId == nil {
            if let session = try? await client.auth.session {
                currentUserId = session.user.id
            }
        }
        
        guard let userId = currentUserId else {
            self.debugInfo = "Error: No User Logged In"
            self.isLoading = false
            return
        }
        
        self.debugInfo = "Fetching from Cloud..."
        
        do {
            // 2. Parallel Fetch: Get Feed items AND Liked items
            async let feedResult = db.fetchFeedItems(currentUserId: userId)
            async let likesResult = db.fetchLikedItems(userId: userId)
            
            let (fetchedItems, likedItems) = try await (feedResult, likesResult)
            
            // 3. Filter out items I've already liked
            let likedIDs = Set(likedItems.map { $0.id })
            
            // 4. Calculate Distance & Sort
            self.allItems = fetchedItems
                .filter { !likedIDs.contains($0.id) }
                .map { item in
                    var modifiedItem = item
                    // If item has coords, calculate real distance
                    if let lat = item.latitude, let long = item.longitude {
                        modifiedItem.distance = locationManager.distanceFromUser(latitude: lat, longitude: long)
                    }
                    return modifiedItem
                }
                // Sort by Nearest First
                .sorted { $0.distance < $1.distance }
            
            // 5. SKIP ISO FILTERING - Show everything
            self.items = self.allItems
            
            self.debugInfo = "Cloud: \(fetchedItems.count) | Final: \(self.items.count) (Location Based)"
            print("✅ Feed Loaded: \(self.items.count) items sorted by distance.")
            
        } catch {
            self.debugInfo = "Error: \(error.localizedDescription)"
            print("🟥 FEED ERROR: \(error)")
        }
        
        self.isLoading = false
    }
    
    func removeItem(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items.remove(at: index)
        }
        if let masterIndex = allItems.firstIndex(where: { $0.id == id }) {
            allItems.remove(at: masterIndex)
        }
    }
}
