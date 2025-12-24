//
//  TradeOffer.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-24.
//


import Foundation

struct TradeOffer: Identifiable, Codable, Hashable {
    var id: UUID
    var senderId: UUID
    var receiverId: UUID
    var offeredItemId: UUID
    var wantedItemId: UUID
    var status: String // "pending", "accepted", "rejected"
    var createdAt: Date
    
    // Expanded properties for UI (Filled manually after fetching)
    var offeredItem: TradeItem?
    var wantedItem: TradeItem?
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case offeredItemId = "offered_item_id"
        case wantedItemId = "wanted_item_id"
        case status
        case createdAt = "created_at"
    }
}