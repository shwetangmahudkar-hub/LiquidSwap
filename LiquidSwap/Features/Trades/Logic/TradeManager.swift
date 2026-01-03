import Foundation
import Combine
import SwiftUI
import Supabase

@MainActor
class TradeManager: ObservableObject {
    static let shared = TradeManager()
    
    @Published var interestedItems: [TradeItem] = []
    @Published var incomingOffers: [TradeOffer] = []
    @Published var activeTrades: [TradeOffer] = []
    
    // ✨ NEW: Cache profiles for chat list to avoid N+1 queries
    // Maps UserID -> UserProfile for O(1) lookup in views
    @Published var relatedProfiles: [UUID: UserProfile] = [:]
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let db = DatabaseService.shared
    private let userManager = UserManager.shared
    private let client = SupabaseConfig.client
    
    private var channel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    
    private init() {
        Task { await subscribeToRealtime() }
    }
    
    // MARK: - Data Loading
    func loadTradesData() async {
        guard let userId = userManager.currentUser?.id else { return }
        self.isLoading = true
        defer { self.isLoading = false }
        
        let blockedIDs = userManager.blockedUserIds
        
        do {
            async let interestedResult = loadInterestedItems(userId: userId)
            async let offersResult = loadIncomingOffers(userId: userId)
            async let activeResult = loadActiveTrades(userId: userId)
            
            let (interested, rawOffers, rawActive) = try await (interestedResult, offersResult, activeResult)
            
            // 1. Filter Blocked Users FIRST (Save costs by not hydrating them)
            let filteredOffers = rawOffers.filter { !blockedIDs.contains($0.senderId) }
            let filteredActive = rawActive.filter { trade in
                let partnerId = (trade.senderId == userId) ? trade.receiverId : trade.senderId
                return !blockedIDs.contains(partnerId)
            }
            
            // 2. Hydrate Item Data (✨ BATCH OPTIMIZED)
            // Fetch all items for all trades in one go
            let hydratedOffers = await hydrateTrades(filteredOffers)
            let hydratedActive = await hydrateTrades(filteredActive)
            
            self.interestedItems = interested
            self.incomingOffers = hydratedOffers
            self.activeTrades = hydratedActive
            
            // 3. Batch Load Profiles
            // This fetches all partner avatars/names in one go
            await loadRelatedProfiles(offers: hydratedOffers, active: hydratedActive, currentUserId: userId)
            
        } catch {
            print("Error loading trades: \(error)")
        }
    }
    
    // ✨ NEW: Batch Fetch Helper for Profiles
    private func loadRelatedProfiles(offers: [TradeOffer], active: [TradeOffer], currentUserId: UUID) async {
        var userIds = Set<UUID>()
        
        // Collect all partner IDs
        let allTrades = offers + active
        for trade in allTrades {
            if trade.senderId != currentUserId { userIds.insert(trade.senderId) }
            if trade.receiverId != currentUserId { userIds.insert(trade.receiverId) }
        }
        
        guard !userIds.isEmpty else { return }
        
        do {
            // Use the batch function in DatabaseService
            let profiles = try await db.fetchProfiles(userIds: Array(userIds))
            
            // Map to dictionary for O(1) lookup
            self.relatedProfiles = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
            print("✅ TradeManager: Batch loaded \(profiles.count) related profiles.")
        } catch {
            print("❌ Failed to batch load profiles: \(error)")
        }
    }
    
    // Helper Loaders
    private func loadInterestedItems(userId: UUID) async throws -> [TradeItem] {
        try await db.fetchLikedItems(userId: userId)
    }
    
    private func loadIncomingOffers(userId: UUID) async throws -> [TradeOffer] {
        return try await db.fetchIncomingOffers(userId: userId)
    }
    
    private func loadActiveTrades(userId: UUID) async throws -> [TradeOffer] {
        return try await db.fetchActiveTrades(userId: userId)
    }
    
    // MARK: - Hydration Logic (✨ HIGHLY OPTIMIZED)
    
    /// Batches all item IDs from all trades and fetches them in a single network request.
    /// Replaces the old N+1 loop logic.
    private func hydrateTrades(_ trades: [TradeOffer]) async -> [TradeOffer] {
        if trades.isEmpty { return [] }
        
        // 1. Collect ALL unique Item IDs involved in these trades
        var allItemIds = Set<UUID>()
        for trade in trades {
            allItemIds.insert(trade.offeredItemId)
            allItemIds.insert(trade.wantedItemId)
            trade.additionalOfferedItemIds.forEach { allItemIds.insert($0) }
            trade.additionalWantedItemIds.forEach { allItemIds.insert($0) }
        }
        
        // 2. Single DB Call
        guard !allItemIds.isEmpty else { return trades }
        
        do {
            // Fetch items using the new DatabaseService batch function
            let fetchedItems = try await db.fetchBatchItems(ids: Array(allItemIds))
            
            // Create a lookup map for O(1) access
            let itemMap = Dictionary(uniqueKeysWithValues: fetchedItems.map { ($0.id, $0) })
            
            // 3. Assign items back to trades
            return trades.map { trade in
                var hydrated = trade
                
                // Hydrate Primary Items
                hydrated.offeredItem = itemMap[trade.offeredItemId]
                hydrated.wantedItem = itemMap[trade.wantedItemId]
                
                // Hydrate Additional Items
                hydrated.additionalOfferedItems = trade.additionalOfferedItemIds.compactMap { itemMap[$0] }
                hydrated.additionalWantedItems = trade.additionalWantedItemIds.compactMap { itemMap[$0] }
                
                return hydrated
            }
        } catch {
            print("❌ Hydration Error: \(error)")
            // Return existing trades (partially unhydrated) rather than crashing
            return trades
        }
    }
    
    // MARK: - Realtime
    func subscribeToRealtime() async {
        if let existing = channel { await existing.unsubscribe() }
        realtimeTask?.cancel()
        
        let newChannel = client.channel("public:trades")
        self.channel = newChannel
        let changeStream = newChannel.postgresChange(AnyAction.self, schema: "public", table: "trades")
        
        do {
            try await newChannel.subscribeWithError()
        } catch { return }
        
        realtimeTask = Task { [weak self] in
            for await _ in changeStream {
                await self?.loadTradesData()
            }
        }
    }
    
    // MARK: - Actions
    func markAsInterested(item: TradeItem) async -> Bool {
        guard let userId = userManager.currentUser?.id else { return false }
        do {
            try await db.saveLike(userId: userId, itemId: item.id)
            if !interestedItems.contains(where: { $0.id == item.id }) { interestedItems.append(item) }
            return true
        } catch { return false }
    }
    
    func removeInterest(item: TradeItem) async -> Bool {
        guard let userId = userManager.currentUser?.id else { return false }
        do {
            try await client.from("likes").delete().eq("user_id", value: userId).eq("item_id", value: item.id).execute()
            interestedItems.removeAll { $0.id == item.id }
            return true
        } catch { return false }
    }
    
    func checkIfOfferExists(wantedItemId: UUID, myItemId: UUID) async -> Bool {
        do {
            let count = try await client.from("trades").select("id", head: true, count: .exact).eq("wanted_item_id", value: wantedItemId).eq("offered_item_id", value: myItemId).in("status", values: ["pending", "accepted"]).execute().count
            return (count ?? 0) > 0
        } catch { return false }
    }

    func hasPendingOffer(for wantedItemId: UUID) async -> Bool {
        guard let myId = userManager.currentUser?.id else { return false }
        do {
            let count = try await client.from("trades").select("id", head: true, count: .exact).eq("sender_id", value: myId).eq("wanted_item_id", value: wantedItemId).eq("status", value: "pending").execute().count
            return (count ?? 0) > 0
        } catch { return false }
    }
    
    func sendInquiry(wantedItem: TradeItem) async -> Bool {
        if await hasPendingOffer(for: wantedItem.id) {
            print("ℹ️ Trade already exists, skipping creation.")
            return true
        }
        
        guard let placeholderItem = userManager.userItems.first else {
            print("❌ sendInquiry Failed: User has no items to trade.")
            return false
        }
        
        return await sendOffer(wantedItem: wantedItem, myItem: placeholderItem)
    }

    func sendOffer(wantedItem: TradeItem, myItem: TradeItem) async -> Bool {
        return await sendMultiItemOffer(wantedItems: [wantedItem], offeredItems: [myItem])
    }
    
    func sendMultiItemOffer(wantedItems: [TradeItem], offeredItems: [TradeItem]) async -> Bool {
        guard let senderId = userManager.currentUser?.id else { return false }
        guard let primaryOffered = offeredItems.first, let primaryWanted = wantedItems.first else { return false }
        
        if primaryOffered.ownerId != senderId { return false }
        if primaryWanted.ownerId == senderId { return false }
        if await checkIfOfferExists(wantedItemId: primaryWanted.id, myItemId: primaryOffered.id) { return false }
        
        let additionalOfferedIds = offeredItems.dropFirst().map { $0.id }
        let additionalWantedIds = wantedItems.dropFirst().map { $0.id }
        
        let offer = TradeOffer(
            id: UUID(),
            senderId: senderId,
            receiverId: primaryWanted.ownerId,
            offeredItemId: primaryOffered.id,
            wantedItemId: primaryWanted.id,
            additionalOfferedItemIds: additionalOfferedIds,
            additionalWantedItemIds: additionalWantedIds,
            status: "pending",
            createdAt: Date()
        )
        
        do {
            try await db.createTradeOffer(offer: offer)
            try? await db.saveLike(userId: senderId, itemId: primaryWanted.id)
            interestedItems.removeAll { $0.id == primaryWanted.id }
            return true
        } catch { return false }
    }
    
    func respondToOffer(offer: TradeOffer, accept: Bool) async -> Bool {
        guard let userId = userManager.currentUser?.id, offer.receiverId == userId else { return false }
        let newStatus = accept ? "accepted" : "rejected"
        do {
            try await db.updateTradeStatus(tradeId: offer.id, status: newStatus)
            incomingOffers.removeAll { $0.id == offer.id }
            return true
        } catch { return false }
    }
    
    func completeTrade(with partnerId: UUID) async -> Bool {
        guard let myId = userManager.currentUser?.id else { return false }
        do {
            let response: [TradeOffer] = try await client.from("trades").select().in("status", values: ["accepted", "completed"]).or("and(sender_id.eq.\(myId),receiver_id.eq.\(partnerId)),and(sender_id.eq.\(partnerId),receiver_id.eq.\(myId))").execute().value
            guard let trade = response.sorted(by: { $0.createdAt > $1.createdAt }).first else { return false }
            if trade.status == "accepted" { try await db.updateTradeStatus(tradeId: trade.id, status: "completed") }
            return true
        } catch { return false }
    }
    
    func getActiveTrade(with partnerId: UUID) async -> TradeOffer? {
        guard let myId = userManager.currentUser?.id else { return nil }
        do {
            let response: [TradeOffer] = try await client.from("trades").select().in("status", values: ["accepted", "pending", "completed"]).or("and(sender_id.eq.\(myId),receiver_id.eq.\(partnerId)),and(sender_id.eq.\(partnerId),receiver_id.eq.\(myId))").order("created_at", ascending: false).limit(1).execute().value
            
            // ✨ OPTIMIZATION: Use the batch hydration logic for this single trade
            // This reuses code and keeps the logic consistent
            guard let tradeStub = response.first else { return nil }
            let hydratedTrades = await hydrateTrades([tradeStub])
            return hydratedTrades.first
            
        } catch { return nil }
    }
    
    func sendCounterOffer(originalTrade: TradeOffer, newWantedItem: TradeItem) async -> Bool {
        guard let myId = userManager.currentUser?.id else { return false }
        guard originalTrade.receiverId == myId else { return false }
        
        let myItemId = originalTrade.wantedItemId
        let newOffer = TradeOffer(
            id: UUID(),
            senderId: myId,
            receiverId: originalTrade.senderId,
            offeredItemId: myItemId,
            wantedItemId: newWantedItem.id,
            status: "pending",
            createdAt: Date()
        )
        do {
            try await db.updateTradeStatus(tradeId: originalTrade.id, status: "countered")
            try await db.createTradeOffer(offer: newOffer)
            try? await db.saveLike(userId: myId, itemId: newWantedItem.id)
            if let index = incomingOffers.firstIndex(where: { $0.id == originalTrade.id }) { incomingOffers.remove(at: index) }
            return true
        } catch { return false }
    }
}
