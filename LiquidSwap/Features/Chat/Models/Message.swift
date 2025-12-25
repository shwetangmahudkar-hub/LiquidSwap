import SwiftUI

struct Message: Identifiable, Codable, Hashable {
    var id: UUID
    var senderId: UUID
    var receiverId: UUID
    var content: String
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case content
        case createdAt = "created_at"
    }
    
    // Helper to check if I sent this message
    var isCurrentUser: Bool {
        return senderId == UserManager.shared.currentUser?.id
    }
}
