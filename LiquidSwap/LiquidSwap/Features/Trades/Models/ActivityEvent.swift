//
//  ActivityEvent.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-27.
//


import Foundation

struct ActivityEvent: Identifiable, Codable {
    let id: UUID
    let actor: UserProfile // The user who "Liked" your item
    let item: TradeItem    // Your item they liked
    let createdAt: Date
    
    // We add a "status" to track if you've acted on it yet
    var status: ActivityStatus
    
    enum ActivityStatus: String, Codable {
        case pending  // You haven't seen/acted on it
        case matched  // You swiped back (It's a match!)
        case ignored  // You dismissed it
    }
    
    // Custom Init for easier mapping
    init(id: UUID = UUID(), actor: UserProfile, item: TradeItem, createdAt: Date = Date(), status: ActivityStatus = .pending) {
        self.id = id
        self.actor = actor
        self.item = item
        self.createdAt = createdAt
        self.status = status
    }
}