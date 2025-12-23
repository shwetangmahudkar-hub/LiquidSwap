import SwiftUI

struct Message: Identifiable, Codable, Hashable {
    let id: UUID
    let content: String
    let isCurrentUser: Bool
    let timestamp: Date
    
    // NEW: Status for "Read" receipts
    var status: MessageStatus = .sent
    
    init(id: UUID = UUID(), content: String, isCurrentUser: Bool, timestamp: Date = Date(), status: MessageStatus = .sent) {
        self.id = id
        self.content = content
        self.isCurrentUser = isCurrentUser
        self.timestamp = timestamp
        self.status = status
    }
}

enum MessageStatus: String, Codable {
    case sent
    case delivered
    case read
}
