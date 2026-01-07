import Foundation

// MARK: - ✨ Issue #10: Type-Safe Trade Status Enum

/// All possible trade statuses - eliminates magic strings
enum TradeStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case rejected = "rejected"
    case countered = "countered"
    case cancelled = "cancelled"
    case completed = "completed"
    
    // MARK: - Display Properties
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .rejected: return "Declined"
        case .countered: return "Countered"
        case .cancelled: return "Cancelled"
        case .completed: return "Completed"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .accepted: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        case .countered: return "arrow.triangle.2.circlepath"
        case .cancelled: return "trash.fill"
        case .completed: return "star.fill"
        }
    }
    
    // MARK: - Status Categories
    
    /// Statuses where the trade is still active/in-progress
    static var activeStatuses: [TradeStatus] {
        return [.pending, .accepted]
    }
    
    /// Statuses where the trade has ended
    static var finalStatuses: [TradeStatus] {
        return [.rejected, .cancelled, .completed]
    }
    
    /// Statuses where items are committed (can't be used elsewhere)
    static var committedStatuses: [TradeStatus] {
        return [.pending, .accepted]
    }
    
    var isActive: Bool {
        return Self.activeStatuses.contains(self)
    }
    
    var isFinal: Bool {
        return Self.finalStatuses.contains(self)
    }
    
    var isCommitted: Bool {
        return Self.committedStatuses.contains(self)
    }
}

// MARK: - Trade Offer Model

struct TradeOffer: Identifiable, Codable, Hashable {
    var id: UUID
    var senderId: UUID
    var receiverId: UUID
    
    // MARK: - Primary Items (Legacy Support)
    // These ensure 1-to-1 trades still work with older app versions
    var offeredItemId: UUID
    var wantedItemId: UUID
    
    // MARK: - Multi-Trade Support
    // Additional items added to the deal
    var additionalOfferedItemIds: [UUID] = []
    var additionalWantedItemIds: [UUID] = []
    
    // ✨ Issue #10: Now uses type-safe enum instead of String
    var status: TradeStatus
    var createdAt: Date
    
    // MARK: - ✨ Two-Phase Completion (Issue #2 Security Fix)
    // Both parties must confirm before trade is marked complete
    var senderConfirmedCompletion: Bool = false
    var receiverConfirmedCompletion: Bool = false
    var completedAt: Date?
    
    // MARK: - UI-Only Properties (Hydrated after fetch)
    var offeredItem: TradeItem?
    var wantedItem: TradeItem?
    
    // Arrays for the full deal visualization
    var additionalOfferedItems: [TradeItem] = []
    var additionalWantedItems: [TradeItem] = []
    
    // MARK: - Helper Computed Properties
    
    // Get All IDs involved
    var allOfferedIds: [UUID] {
        return [offeredItemId] + additionalOfferedItemIds
    }
    
    var allWantedIds: [UUID] {
        return [wantedItemId] + additionalWantedItemIds
    }
    
    // Get All Item Objects
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
    
    // MARK: - ✨ Completion Status Helpers
    
    /// Returns true if both parties have confirmed completion
    var isBothConfirmed: Bool {
        return senderConfirmedCompletion && receiverConfirmedCompletion
    }
    
    /// Returns true if the trade is fully completed
    var isCompleted: Bool {
        return status == .completed
    }
    
    /// Returns true if the trade is in an active state (can still be completed)
    var isActive: Bool {
        return status == .accepted
    }
    
    /// Returns true if trade is pending initial response
    var isPending: Bool {
        return status == .pending
    }
    
    /// Returns true if trade was countered
    var isCountered: Bool {
        return status == .countered
    }
    
    /// Returns true if trade was cancelled
    var isCancelled: Bool {
        return status == .cancelled
    }
    
    /// Returns true if trade was rejected
    var isRejected: Bool {
        return status == .rejected
    }
    
    /// Returns true if trade is waiting for the other party to confirm
    var isPendingPartnerConfirmation: Bool {
        return isActive && (senderConfirmedCompletion || receiverConfirmedCompletion) && !isBothConfirmed
    }
    
    /// Check if a specific user has confirmed
    func hasUserConfirmed(userId: UUID) -> Bool {
        if userId == senderId {
            return senderConfirmedCompletion
        } else if userId == receiverId {
            return receiverConfirmedCompletion
        }
        return false
    }
    
    /// Check if the partner of a specific user has confirmed
    func hasPartnerConfirmed(userId: UUID) -> Bool {
        if userId == senderId {
            return receiverConfirmedCompletion
        } else if userId == receiverId {
            return senderConfirmedCompletion
        }
        return false
    }
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case offeredItemId = "offered_item_id"
        case wantedItemId = "wanted_item_id"
        case additionalOfferedItemIds = "additional_offered_ids"
        case additionalWantedItemIds = "additional_wanted_ids"
        case status
        case createdAt = "created_at"
        // ✨ Completion fields
        case senderConfirmedCompletion = "sender_confirmed_completion"
        case receiverConfirmedCompletion = "receiver_confirmed_completion"
        case completedAt = "completed_at"
    }
    
    // MARK: - Custom Decoder (handles missing/null fields gracefully)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields
        id = try container.decode(UUID.self, forKey: .id)
        senderId = try container.decode(UUID.self, forKey: .senderId)
        receiverId = try container.decode(UUID.self, forKey: .receiverId)
        offeredItemId = try container.decode(UUID.self, forKey: .offeredItemId)
        wantedItemId = try container.decode(UUID.self, forKey: .wantedItemId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        
        // ✨ Issue #10: Decode status as enum (with fallback for unknown values)
        if let statusString = try? container.decode(String.self, forKey: .status),
           let decodedStatus = TradeStatus(rawValue: statusString) {
            status = decodedStatus
        } else {
            // Fallback for any unexpected status value
            status = .pending
        }
        
        // Optional array fields (default to empty)
        additionalOfferedItemIds = try container.decodeIfPresent([UUID].self, forKey: .additionalOfferedItemIds) ?? []
        additionalWantedItemIds = try container.decodeIfPresent([UUID].self, forKey: .additionalWantedItemIds) ?? []
        
        // ✨ Completion fields (default to false/nil for backward compatibility)
        senderConfirmedCompletion = try container.decodeIfPresent(Bool.self, forKey: .senderConfirmedCompletion) ?? false
        receiverConfirmedCompletion = try container.decodeIfPresent(Bool.self, forKey: .receiverConfirmedCompletion) ?? false
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
    }
    
    // MARK: - Custom Init
    
    init(id: UUID = UUID(),
         senderId: UUID,
         receiverId: UUID,
         offeredItemId: UUID,
         wantedItemId: UUID,
         additionalOfferedItemIds: [UUID] = [],
         additionalWantedItemIds: [UUID] = [],
         status: TradeStatus = .pending,
         createdAt: Date = Date(),
         senderConfirmedCompletion: Bool = false,
         receiverConfirmedCompletion: Bool = false,
         completedAt: Date? = nil) {
        
        self.id = id
        self.senderId = senderId
        self.receiverId = receiverId
        self.offeredItemId = offeredItemId
        self.wantedItemId = wantedItemId
        self.additionalOfferedItemIds = additionalOfferedItemIds
        self.additionalWantedItemIds = additionalWantedItemIds
        self.status = status
        self.createdAt = createdAt
        self.senderConfirmedCompletion = senderConfirmedCompletion
        self.receiverConfirmedCompletion = receiverConfirmedCompletion
        self.completedAt = completedAt
    }
}
