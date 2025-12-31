import Foundation

struct TradeOffer: Identifiable, Codable, Hashable {
    var id: UUID
    var senderId: UUID
    var receiverId: UUID
    
    // MARK: - Primary Items (Legacy Support)
    // These ensure 1-to-1 trades still work with older app versions
    var offeredItemId: UUID
    var wantedItemId: UUID
    
    // MARK: - Multi-Trade Support (New)
    // Additional items added to the deal
    var additionalOfferedItemIds: [UUID] = []
    var additionalWantedItemIds: [UUID] = []
    
    var status: String // "pending", "accepted", "rejected", "countered"
    var createdAt: Date
    
    // MARK: - UI-Only Properties (Hydrated after fetch)
    var offeredItem: TradeItem?
    var wantedItem: TradeItem?
    
    // Arrays for the full deal visualization
    var additionalOfferedItems: [TradeItem] = []
    var additionalWantedItems: [TradeItem] = []
    
    // Helper: Get All IDs involved
    var allOfferedIds: [UUID] {
        return [offeredItemId] + additionalOfferedItemIds
    }
    
    var allWantedIds: [UUID] {
        return [wantedItemId] + additionalWantedItemIds
    }
    
    // Helper: Get All Item Objects
    var allOfferedItems: [TradeItem] {
        var items: [TradeItem] = []
        if let primary = offeredItem { items.append(primary) }
        items.append(contentsOf: additionalOfferedItems)
        return items
    }
    
    var allWantedItems: [TradeItem] {
        var items: [TradeItem] = []
        if let primary = wantedItem { items.append(primary) }
        items.append(contentsOf: additionalWantedItems)
        return items
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case offeredItemId = "offered_item_id"
        case wantedItemId = "wanted_item_id"
        case additionalOfferedItemIds = "additional_offered_ids" // New DB Column
        case additionalWantedItemIds = "additional_wanted_ids"   // New DB Column
        case status
        case createdAt = "created_at"
    }
    
    // Custom Init
    init(id: UUID = UUID(),
         senderId: UUID,
         receiverId: UUID,
         offeredItemId: UUID,
         wantedItemId: UUID,
         additionalOfferedItemIds: [UUID] = [],
         additionalWantedItemIds: [UUID] = [],
         status: String = "pending",
         createdAt: Date = Date()) {
        
        self.id = id
        self.senderId = senderId
        self.receiverId = receiverId
        self.offeredItemId = offeredItemId
        self.wantedItemId = wantedItemId
        self.additionalOfferedItemIds = additionalOfferedItemIds
        self.additionalWantedItemIds = additionalWantedItemIds
        self.status = status
        self.createdAt = createdAt
    }
}
