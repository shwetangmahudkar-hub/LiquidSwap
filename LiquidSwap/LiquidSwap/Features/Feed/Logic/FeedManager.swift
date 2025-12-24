import Foundation
import Combine
import SwiftUI

@MainActor
class FeedManager: ObservableObject {
    private var allItems: [TradeItem] = []
    
    @Published var items: [TradeItem] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = DatabaseService.shared
    private let userManager = UserManager.shared
    
    func fetchFeed() async {
        guard let userId = userManager.currentUser?.id else { return }
        
        self.isLoading = true
        self.error = nil
        
        do {
            // 1. Fetch Feed Items AND Liked Items in parallel
            async let feedResult = db.fetchFeedItems(currentUserId: userId)
            async let likesResult = db.fetchLikedItems(userId: userId)
            
            let (fetchedItems, likedItems) = try await (feedResult, likesResult)
            
            // 2. Filter out items I've already liked
            let likedIDs = Set(likedItems.map { $0.id })
            self.allItems = fetchedItems.filter { !likedIDs.contains($0.id) }
            
            // 3. Apply Categories
            applyISOFilters()
            
        } catch {
            print("❌ Error fetching feed: \(error)")
            self.error = "Could not load items."
        }
        
        self.isLoading = false
    }
    
    private func applyISOFilters() {
        // 1. Get User's ISO preferences
        let isoList = userManager.currentUser?.isoCategories ?? []
        
        // 2. Logic: If user has NO ISOs, show ALL (Discovery).
        if isoList.isEmpty {
            self.items = allItems
        } else {
            self.items = allItems.filter { isoList.contains($0.category) }
        }
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
