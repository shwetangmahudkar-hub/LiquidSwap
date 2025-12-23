import SwiftUI
import Combine

class FeedViewModel: ObservableObject {
    @Published var items: [TradeItem] = []
    
    // Triggers the "It's a Match!" screen
    @Published var matchItem: TradeItem?
    
    // We keep a set of removed IDs to avoid showing the same card twice
    private var removedItemIDs: Set<UUID> = []
    
    init() {
        Task {
            await fetchItems()
        }
    }
    
    @MainActor
    func fetchItems() async {
        // 1. Get Current User ID (to filter out our own items)
        guard let currentUserId = UserManager.shared.currentUser?.id else {
            // If we don't know who we are yet, try loading mock data temporarily
            self.items = TradeItem.generateMockItems()
            return
        }
        
        do {
            // 2. Fetch REAL items from Cloud
            let cloudItems = try await DatabaseService.shared.fetchFeedItems(currentUserId: currentUserId)
            
            // 3. Filter out items we've already swiped on this session
            self.items = cloudItems.filter { !removedItemIDs.contains($0.id) }
            
            // 4. Fallback: If cloud is empty, show mock data so the app doesn't look broken
            if self.items.isEmpty {
                print("☁️ Cloud is empty, loading mock data.")
                self.items = TradeItem.generateMockItems()
            } else {
                print("☁️ Loaded \(self.items.count) items from Supabase!")
            }
            
        } catch {
            print("❌ Error loading feed: \(error)")
            self.items = TradeItem.generateMockItems()
        }
    }
    
    // MARK: - Swipe Actions
    
    func swipeRight() {
        guard let item = items.last else { return }
        saveSwipe(item: item, isLike: true)
        removeItem(item: item)
    }
    
    func swipeLeft() {
        guard let item = items.last else { return }
        saveSwipe(item: item, isLike: false)
        removeItem(item: item)
    }
    
    func removeItem(item: TradeItem) {
        removedItemIDs.insert(item.id)
        
        // Remove from the array (Animation handles the visual removal)
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
        }
        
        // If we run out of cards, try to fetch more
        if items.isEmpty {
            Task {
                // Wait a bit, then refresh
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                await fetchItems()
            }
        }
    }
    
    // Logic to handle "Likes" and Matches
    func saveSwipe(item: TradeItem, isLike: Bool) {
        if isLike {
            print("✅ Liked: \(item.title)")
            
            // SIMULATE A MATCH LOGIC
            let isMatch = Bool.random()
            if isMatch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.matchItem = item
                }
            }
        } else {
            print("❌ Passed: \(item.title)")
        }
    }
}
