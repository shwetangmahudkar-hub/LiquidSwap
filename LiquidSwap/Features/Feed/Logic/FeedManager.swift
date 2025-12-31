import Foundation
import Combine
import SwiftUI
import CoreLocation
import Supabase

@MainActor
class FeedManager: ObservableObject {
    // Singleton Instance
    static let shared = FeedManager()
    
    // Pagination State
    @Published var items: [TradeItem] = []
    @Published var isLoading = false
    @Published var error: String?
    
    // Internal Pagination Trackers
    private var currentPage = 0
    private let pageSize = 10 // 📉 COST OPTIMIZATION: Only 10 items at a time
    private var canLoadMore = true
    private var isFetchingNextPage = false
    
    // Debug info
    @Published var debugInfo: String = "Initializing..."
    
    private let db = DatabaseService.shared
    
    // Use computed property to avoid init cycles
    private var userManager: UserManager { UserManager.shared }
    private let locationManager = LocationManager.shared
    private let client = SupabaseConfig.client
    
    // Private init to enforce singleton usage
    private init() {}
    
    // MARK: - Public Actions
    
    /// Called on App Launch or Pull-to-Refresh
    func fetchFeed() async {
        self.isLoading = true
        self.error = nil
        self.items = [] // Clear existing items
        self.currentPage = 0
        self.canLoadMore = true
        
        await loadBatch()
        
        self.isLoading = false
    }
    
    /// Called when the card stack is getting low (Lazy Loading)
    func loadMoreIfNeeded() {
        guard !isLoading && !isFetchingNextPage && canLoadMore else { return }
        
        // Trigger if we have fewer than 3 items left
        if items.count < 3 {
            Task {
                await loadBatch()
            }
        }
    }
    
    func removeItem(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items.remove(at: index)
        }
        // Check if we need to refill the stack
        loadMoreIfNeeded()
    }
    
    // MARK: - Internal Loading Logic
    
    private func loadBatch() async {
        guard canLoadMore else { return }
        self.isFetchingNextPage = true
        self.debugInfo = "Loading Page \(currentPage)..."
        
        // 1. Get User ID
        var currentUserId = userManager.currentUser?.id
        if currentUserId == nil {
            if let session = try? await client.auth.session {
                currentUserId = session.user.id
            }
        }
        
        guard let userId = currentUserId else {
            self.debugInfo = "Error: No User Logged In"
            self.isFetchingNextPage = false
            return
        }
        
        // 2. Capture Context Data
        let userIsoCategories = userManager.currentUser?.isoCategories ?? []
        let blockedIDs = userManager.blockedUserIds
        let currentUserLocation = locationManager.userLocation
        
        do {
            // 3. Parallel Fetch (Batch + Likes)
            // We fetch likes every time to ensure we don't show items we just liked in a different session
            // Note: In a larger app, you'd cache 'likedItems' separately to save reads.
            async let feedResult = db.fetchFeedItems(currentUserId: userId, page: currentPage, pageSize: pageSize)
            async let likesResult = db.fetchLikedItems(userId: userId)
            
            let (fetchedItems, likedItems) = try await (feedResult, likesResult)
            
            // 4. Update Pagination State
            if fetchedItems.count < pageSize {
                self.canLoadMore = false // End of database reached
            }
            self.currentPage += 1
            
            // 5. Filter Items (Client Side)
            let likedIDs = Set(likedItems.map { $0.id })
            
            let visibleItems = fetchedItems.filter { item in
                let isLiked = likedIDs.contains(item.id)
                let isBlocked = blockedIDs.contains(item.ownerId)
                return !isLiked && !isBlocked
            }
            
            // Recursion: If all items in this batch were filtered out (e.g. all blocked), fetch the next page immediately
            if visibleItems.isEmpty && canLoadMore {
                print("⚠️ Page \(currentPage - 1) was empty after filtering. Fetching next page...")
                self.isFetchingNextPage = false
                await loadBatch()
                return
            }
            
            // 6. Hydration (Background Work)
            var enrichedItems: [TradeItem] = []
            
            await withTaskGroup(of: TradeItem.self) { group in
                for item in visibleItems {
                    group.addTask {
                        var modifiedItem = item
                        
                        // A. Calculate Distance
                        if let userLoc = currentUserLocation,
                           let lat = item.latitude,
                           let lon = item.longitude {
                            let itemLoc = CLLocation(latitude: lat, longitude: lon)
                            modifiedItem.distance = userLoc.distance(from: itemLoc)
                        }
                        
                        // B. Fetch Owner Data (Optimistic)
                        // Ideally, this should also be joined in the DB query to save reads,
                        // but for now we parallelize it.
                        async let rating = self.db.fetchUserRating(userId: item.ownerId)
                        async let profile = self.db.fetchProfile(userId: item.ownerId)
                        
                        let (r, p) = await (try? rating, try? profile)
                        
                        modifiedItem.ownerRating = r ?? 0.0
                        modifiedItem.ownerUsername = p?.username ?? "Trader"
                        modifiedItem.ownerIsVerified = p?.isVerified ?? false
                        
                        return modifiedItem
                    }
                }
                
                for await item in group {
                    enrichedItems.append(item)
                }
            }
            
            // 7. Smart Sort (Current Batch Only)
            let sortedBatch = enrichedItems.sorted { item1, item2 in
                let isIso1 = userIsoCategories.contains(item1.category)
                let isIso2 = userIsoCategories.contains(item2.category)
                
                if isIso1 && !isIso2 { return true }
                if !isIso1 && isIso2 { return false }
                
                return item1.distance < item2.distance
            }
            
            // 8. Append to Feed
            self.items.append(contentsOf: sortedBatch)
            
            self.debugInfo = "Loaded: \(self.items.count) items"
            print("✅ Added \(sortedBatch.count) items (Page \(currentPage)). Total: \(self.items.count)")
            
        } catch {
            self.debugInfo = "Error: \(error.localizedDescription)"
            print("🟥 FEED ERROR: \(error)")
        }
        
        self.isFetchingNextPage = false
    }
}
