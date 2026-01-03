import SwiftUI

struct Message: Identifiable, Codable, Hashable {
    var id: UUID
    var senderId: UUID
    var receiverId: UUID
    var content: String
    var createdAt: Date
    
    // Optional Image URL
    var imageUrl: String?
    
    // ✨ NEW: Link message to a specific Trade
    var tradeId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case content
        case createdAt = "created_at"
        case imageUrl = "image_url"
        case tradeId = "trade_id" // ✨ Map to DB
    }
    
    var isCurrentUser: Bool {
        return senderId == UserManager.shared.currentUser?.id
    }
}
