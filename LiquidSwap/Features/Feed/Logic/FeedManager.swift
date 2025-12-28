import Foundation
import Combine
import SwiftUI
import CoreLocation
import Supabase

@MainActor
class FeedManager: ObservableObject {
    // Singleton Instance
    static let shared = FeedManager()
    
    private var allItems: [TradeItem] = []
    
    @Published var items: [TradeItem] = []
    @Published var isLoading = false
    @Published var error: String?
    
    // Debug info
    @Published var debugInfo: String = "Initializing..."
    
    private let db = DatabaseService.shared
    
    // Use computed property to avoid init cycles
    private var userManager: UserManager { UserManager.shared }
    private let locationManager = LocationManager.shared
    private let client = SupabaseConfig.client
    
    // Private init to enforce singleton usage
    private init() {}
    
    func fetchFeed() async {
        self.isLoading = true
        self.error = nil
        self.debugInfo = "Checking Auth..."
        
        // 1. Get User ID
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
        
        // 2. Capture MainActor Data BEFORE background tasks
        // We grab these here to avoid "Main actor-isolated" errors inside the TaskGroup
        let userIsoCategories = userManager.currentUser?.isoCategories ?? []
        let blockedIDs = userManager.blockedUserIds
        let currentUserLocation = locationManager.userLocation // Capture CLLocation directly
        
        self.debugInfo = "Fetching from Cloud..."
        
        do {
            // 3. Parallel Fetch from DB
            async let feedResult = db.fetchFeedItems(currentUserId: userId)
            async let likesResult = db.fetchLikedItems(userId: userId)
            
            let (fetchedItems, likedItems) = try await (feedResult, likesResult)
            
            // 4. Filter Items
            let likedIDs = Set(likedItems.map { $0.id })
            
            let visibleItems = fetchedItems.filter { item in
                let isLiked = likedIDs.contains(item.id)
                let isBlocked = blockedIDs.contains(item.ownerId)
                return !isLiked && !isBlocked
            }
            
            // 5. Hydration (Background Work)
            // We pass the captured 'currentUserLocation' into the task so we don't touch LocationManager
            var enrichedItems: [TradeItem] = []
            
            await withTaskGroup(of: TradeItem.self) { group in
                for item in visibleItems {
                    group.addTask {
                        var modifiedItem = item
                        
                        // A. Calculate Distance using captured location (Safe)
                        if let userLoc = currentUserLocation,
                           let lat = item.latitude,
                           let lon = item.longitude {
                            let itemLoc = CLLocation(latitude: lat, longitude: lon)
                            // Calculate distance in meters, convert to kilometers if needed
                            // Storing raw meters as per standard 'distance' field expectation
                            modifiedItem.distance = userLoc.distance(from: itemLoc)
                        }
                        
                        // B. Fetch Owner Data
                        // These DB calls are async and safe to call here
                        async let rating = self.db.fetchUserRating(userId: item.ownerId)
                        async let count = self.db.fetchReviewCount(userId: item.ownerId)
                        async let profile = self.db.fetchProfile(userId: item.ownerId)
                        
                        let (r, c, p) = await (try? rating, try? count, try? profile)
                        
                        modifiedItem.ownerRating = r ?? 0.0
                        modifiedItem.ownerReviewCount = c ?? 0
                        modifiedItem.ownerUsername = p?.username ?? "Trader"
                        modifiedItem.ownerIsVerified = p?.isVerified ?? false
                        
                        return modifiedItem
                    }
                }
                
                for await item in group {
                    enrichedItems.append(item)
                }
            }
            
            // 6. Smart Sort
            self.allItems = enrichedItems.sorted { item1, item2 in
                let isIso1 = userIsoCategories.contains(item1.category)
                let isIso2 = userIsoCategories.contains(item2.category)
                
                if isIso1 && !isIso2 { return true }
                if !isIso1 && isIso2 { return false }
                
                return item1.distance < item2.distance
            }
            
            self.items = self.allItems
            
            self.debugInfo = "Cloud: \(fetchedItems.count) | Hidden: \(fetchedItems.count - self.items.count)"
            print("✅ Feed Loaded: \(self.items.count) items.")
            
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
