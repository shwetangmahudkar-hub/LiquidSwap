import SwiftUI
import Observation

@Observable
class FeedViewModel {
    var items: [TradeItem] = []
    
    init() {
        loadInitialData()
    }
    
    func loadInitialData() {
        // 1. Get all possible items
        let allItems = TradeItem.mockData
        
        // 2. Get User's ISO preferences
        let userISO = UserManager.shared.isoCategories
        
        print("--------------------------------------------------")
        print("DEBUG: User ISO Settings are: \(userISO)")
        
        // 3. Filter Logic
        if userISO.isEmpty {
            // Fallback: If you selected NOTHING, we show EVERYTHING (Discovery Mode)
            print("DEBUG: ISO is empty. Defaulting to SHOW ALL.")
            self.items = allItems
        } else {
            // Strict Filter: Only show what matches the ISO set
            self.items = allItems.filter { item in
                // Normalize strings to be safe (e.g. "Plants" == "plants")
                let itemCategory = item.category.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
                
                // Check if our list contains this category
                let isMatch = userISO.contains { iso in
                    iso.trimmingCharacters(in: .whitespacesAndNewlines).capitalized == itemCategory
                }
                
                if isMatch {
                    print("DEBUG: MATCH FOUND - Keeping '\(item.title)' (\(itemCategory))")
                } else {
                    print("DEBUG: NO MATCH - Hiding '\(item.title)' (\(itemCategory))")
                }
                
                return isMatch
            }
        }
        print("DEBUG: Final Feed Count: \(self.items.count)")
        print("--------------------------------------------------")
    }
    
    func removeCard(_ item: TradeItem, direction: SwipeDirection) {
        withAnimation {
            items.removeAll { $0.id == item.id }
        }
        
        if items.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.loadInitialData()
            }
        }
    }
}

enum SwipeDirection {
    case left
    case right
}
