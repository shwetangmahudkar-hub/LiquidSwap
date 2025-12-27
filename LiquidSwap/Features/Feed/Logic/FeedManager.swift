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
            let visibleItems = fetchedItems.filter { !likedIDs.contains($0.id) }
            
            // 4. HYDRATION: Calculate Distance & Fetch Ratings (Parallel)
            var enrichedItems: [TradeItem] = []
            
            await withTaskGroup(of: TradeItem.self) { group in
                for item in visibleItems {
                    group.addTask {
                        var modifiedItem = item
                        
                        // A. Calculate Distance
                        if let lat = item.latitude, let long = item.longitude {
                            modifiedItem.distance = self.locationManager.distanceFromUser(latitude: lat, longitude: long)
                        }
                        
                        // B. Fetch Owner Rating (Async)
                        // We use try? to prevent one failed rating from breaking the whole feed
                        async let rating = self.db.fetchUserRating(userId: item.ownerId)
                        async let count = self.db.fetchReviewCount(userId: item.ownerId)
                        
                        let (r, c) = await (try? rating, try? count)
                        modifiedItem.ownerRating = r ?? 0.0
                        modifiedItem.ownerReviewCount = c ?? 0
                        
                        return modifiedItem
                    }
                }
                
                for await item in group {
                    enrichedItems.append(item)
                }
            }
            
            // 5. Sort by Nearest First
            self.allItems = enrichedItems.sorted { $0.distance < $1.distance }
            
            // 6. SKIP ISO FILTERING - Show everything
            self.items = self.allItems
            
            self.debugInfo = "Cloud: \(fetchedItems.count) | Final: \(self.items.count) (Enriched)"
            print("✅ Feed Loaded: \(self.items.count) items with ratings.")
            
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
