import Foundation
import Combine
import SwiftUI
import Supabase

@MainActor
class TradeManager: ObservableObject {
    static let shared = TradeManager()
    
    @Published var interestedItems: [TradeItem] = []
    @Published var incomingOffers: [TradeOffer] = []
    @Published var isLoading = false
    
    // Legacy properties kept to prevent View binding crashes, but they will remain inactive.
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let db = DatabaseService.shared
    private let userManager = UserManager.shared
    private let client = SupabaseConfig.client
    
    // Realtime reference
    private var channel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    
    private init() {
        // Start listening immediately
        Task {
            await subscribeToRealtime()
        }
    }
    
    // MARK: - Error Handling (Console Only)
    
    /// Log error to Xcode Console instead of UI
    private func handleError(_ error: Error, context: String) {
        print("🟥 [TradeManager Error] --------------------------------------")
        print("Context: \(context)")
        print("Description: \(error.localizedDescription)")
        print("Technical: \(error)")
        print("------------------------------------------------------------")
        
        // Note: We deliberately do NOT set self.showError = true anymore.
    }
    
    /// Clear the current error (No-op now)
    func clearError() {
        self.errorMessage = nil
        self.showError = false
    }
    
    // MARK: - Data Loading
    
    /// Load all trade-related data (interested items and incoming offers)
    func loadTradesData() async {
        guard let userId = userManager.currentUser?.id else {
            handleError(
                NSError(domain: "TradeManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]),
                context: "Loading trades"
            )
            return
        }
        
        self.isLoading = true
        defer { self.isLoading = false }
        
        do {
            // Load interested items and offers in parallel
            async let interestedResult = loadInterestedItems(userId: userId)
            async let offersResult = loadIncomingOffers(userId: userId)
            
            let (interested, offers) = try await (interestedResult, offersResult)
            
            self.interestedItems = interested
            self.incomingOffers = offers
            
            print("✅ Loaded \(interested.count) interested items, \(offers.count) offers")
            
        } catch {
            handleError(error, context: "Loading trades data")
            // Keep existing data on error rather than clearing it
        }
    }
    
    /// Load items the user has marked as interested
    private func loadInterestedItems(userId: UUID) async throws -> [TradeItem] {
        do {
            return try await db.fetchLikedItems(userId: userId)
        } catch {
            // Log warning but allow propagation
            print("⚠️ Failed to load interested items: \(error)")
            throw error
        }
    }
    
    /// Load and hydrate incoming trade offers
    private func loadIncomingOffers(userId: UUID) async throws -> [TradeOffer] {
        var offers = try await db.fetchIncomingOffers(userId: userId)
        
        // Hydrate offers with item details
        try await withThrowingTaskGroup(of: (Int, TradeItem?, TradeItem?).self) { group in
            for (index, offer) in offers.enumerated() {
                group.addTask {
                    async let offered = try? await self.db.fetchItem(id: offer.offeredItemId)
                    async let wanted = try? await self.db.fetchItem(id: offer.wantedItemId)
                    
                    let (offeredItem, wantedItem) = await (offered, wanted)
                    return (index, offeredItem, wantedItem)
                }
            }
            
            for try await (index, offeredItem, wantedItem) in group {
                if offeredItem == nil || wantedItem == nil {
                    print("⚠️ Failed to load items for offer \(offers[index].id)")
                }
                offers[index].offeredItem = offeredItem
                offers[index].wantedItem = wantedItem
            }
        }
        
        return offers
    }
    
    // MARK: - Realtime Subscription
    
    /// Subscribe to real-time updates for trade offers
    func subscribeToRealtime() async {
        // Clean up existing subscription
        if let existing = channel {
            await existing.unsubscribe()
        }
        realtimeTask?.cancel()
        
        let newChannel = client.channel("public:trades")
        self.channel = newChannel
        
        let changeStream = newChannel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "trades"
        )
        
        do {
            try await newChannel.subscribeWithError()
            print("✅ Subscribed to real-time trade updates")
        } catch {
            handleError(error, context: "Subscribing to real-time updates")
            // Don't fail completely - app can still work without realtime
            return
        }
        
        // Listen for changes in a detached task
        realtimeTask = Task { [weak self] in
            for await _ in changeStream {
                guard let self = self else { return }
                
                print("⚡️ Trade update detected! Refreshing...")
                await self.loadTradesData()
            }
        }
    }
    
    /// Clean up realtime subscriptions
    func unsubscribeFromRealtime() async {
        realtimeTask?.cancel()
        realtimeTask = nil
        
        if let channel = channel {
            await channel.unsubscribe()
            self.channel = nil
        }
    }
    
    // MARK: - User Actions
    
    /// Mark an item as interesting (add to "interested" list)
    func markAsInterested(item: TradeItem) async -> Bool {
        guard let userId = userManager.currentUser?.id else {
            handleError(
                NSError(domain: "TradeManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]),
                context: "Marking item as interested"
            )
            return false
        }
        
        do {
            try await db.saveLike(userId: userId, itemId: item.id)
            
            // Optimistically update UI
            if !interestedItems.contains(where: { $0.id == item.id }) {
                interestedItems.append(item)
            }
            
            print("✅ Marked item '\(item.title)' as interested")
            return true
            
        } catch {
            handleError(error, context: "Marking item as interested")
            return false
        }
    }
    
    /// Remove an item from the interested list
    func removeInterest(item: TradeItem) async -> Bool {
        guard let userId = userManager.currentUser?.id else {
            handleError(
                NSError(domain: "TradeManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]),
                context: "Removing interest"
            )
            return false
        }
        
        do {
            // Assuming you have this method in DatabaseService
            // If not, you'll need to add it
            struct DeleteLike: Encodable {
                let user_id: UUID
                let item_id: UUID
            }
            
            try await client
                .from("likes")
                .delete()
                .eq("user_id", value: userId)
                .eq("item_id", value: item.id)
                .execute()
            
            // Update UI
            interestedItems.removeAll { $0.id == item.id }
            
            print("✅ Removed interest in item '\(item.title)'")
            return true
            
        } catch {
            handleError(error, context: "Removing interest")
            return false
        }
    }
    
    // MARK: - Trade Offers
    
    /// Send a trade offer to another user
    func sendOffer(wantedItem: TradeItem, myItem: TradeItem) async -> Bool {
        guard let senderId = userManager.currentUser?.id else {
            handleError(
                NSError(domain: "TradeManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]),
                context: "Sending trade offer"
            )
            return false
        }
        
        // Validation
        if myItem.ownerId != senderId {
            handleError(
                NSError(domain: "TradeManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "You don't own this item"]),
                context: "Sending trade offer"
            )
            return false
        }
        
        if wantedItem.ownerId == senderId {
            handleError(
                NSError(domain: "TradeManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "You can't trade with yourself"]),
                context: "Sending trade offer"
            )
            return false
        }
        
        let offer = TradeOffer(
            id: UUID(),
            senderId: senderId,
            receiverId: wantedItem.ownerId,
            offeredItemId: myItem.id,
            wantedItemId: wantedItem.id,
            status: "pending",
            createdAt: Date()
        )
        
        do {
            try await db.createTradeOffer(offer: offer)
            
            // Optimistically update UI - remove from interested list
            interestedItems.removeAll { $0.id == wantedItem.id }
            
            print("✅ Sent trade offer: '\(myItem.title)' for '\(wantedItem.title)'")
            return true
            
        } catch {
            handleError(error, context: "Sending trade offer")
            return false
        }
    }
    
    /// Respond to an incoming trade offer (accept or reject)
    func respondToOffer(offer: TradeOffer, accept: Bool) async -> Bool {
        guard let userId = userManager.currentUser?.id else {
            handleError(
                NSError(domain: "TradeManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]),
                context: "Responding to trade offer"
            )
            return false
        }
        
        // Verify user is the receiver
        if offer.receiverId != userId {
            handleError(
                NSError(domain: "TradeManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "You are not authorized to respond to this offer"]),
                context: "Responding to trade offer"
            )
            return false
        }
        
        let newStatus = accept ? "accepted" : "rejected"
        
        do {
            try await db.updateTradeStatus(tradeId: offer.id, status: newStatus)
            
            // Update UI - remove from incoming offers
            incomingOffers.removeAll { $0.id == offer.id }
            
            let action = accept ? "Accepted" : "Rejected"
            print("✅ \(action) trade offer")
            return true
            
        } catch {
            handleError(error, context: "Responding to trade offer")
            return false
        }
    }
}

