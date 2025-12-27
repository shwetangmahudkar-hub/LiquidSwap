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
        
        // ✨ NEW: Grab User's ISO Categories for Filtering
        let userIsoCategories = userManager.currentUser?.isoCategories ?? []
        
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
            
            // 5. ✨ SMART SORT: ISO First, Then Distance
            self.allItems = enrichedItems.sorted { item1, item2 in
                let isIso1 = userIsoCategories.contains(item1.category)
                let isIso2 = userIsoCategories.contains(item2.category)
                
                // If item1 is ISO and item2 is NOT, item1 wins (return true)
                if isIso1 && !isIso2 { return true }
                // If item1 is NOT ISO and item2 IS, item2 wins (return false)
                if !isIso1 && isIso2 { return false }
                
                // Otherwise (both ISO or neither ISO), sort by distance
                return item1.distance < item2.distance
            }
            
            // 6. Set Final Items
            self.items = self.allItems
            
            self.debugInfo = "Cloud: \(fetchedItems.count) | ISO Matches: \(self.items.filter { userIsoCategories.contains($0.category) }.count)"
            print("✅ Feed Loaded: \(self.items.count) items (Smart Sorted).")
            
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
