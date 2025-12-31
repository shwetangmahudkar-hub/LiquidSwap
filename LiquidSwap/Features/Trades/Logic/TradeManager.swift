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
            
            let filteredOffers = rawOffers.filter { !blockedIDs.contains($0.senderId) }
            let filteredActive = rawActive.filter { trade in
                let partnerId = (trade.senderId == userId) ? trade.receiverId : trade.senderId
                return !blockedIDs.contains(partnerId)
            }
            
            self.interestedItems = interested
            self.incomingOffers = await hydrateTrades(filteredOffers)
            self.activeTrades = await hydrateTrades(filteredActive)
            
        } catch {
            print("Error loading trades: \(error)")
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
    
    // MARK: - Hydration Logic
    private func hydrateTrades(_ trades: [TradeOffer]) async -> [TradeOffer] {
        var result = trades
        await withTaskGroup(of: (Int, TradeOffer).self) { group in
            for (index, trade) in trades.enumerated() {
                group.addTask {
                    var hydratedTrade = trade
                    async let offered = try? await self.db.fetchItem(id: trade.offeredItemId)
                    async let wanted = try? await self.db.fetchItem(id: trade.wantedItemId)
                    let (offeredItem, wantedItem) = await (offered, wanted)
                    hydratedTrade.offeredItem = offeredItem
                    hydratedTrade.wantedItem = wantedItem
                    
                    if !trade.additionalOfferedItemIds.isEmpty {
                        hydratedTrade.additionalOfferedItems = await self.fetchItems(ids: trade.additionalOfferedItemIds)
                    }
                    if !trade.additionalWantedItemIds.isEmpty {
                        hydratedTrade.additionalWantedItems = await self.fetchItems(ids: trade.additionalWantedItemIds)
                    }
                    return (index, hydratedTrade)
                }
            }
            for await (index, hydratedTrade) in group {
                if index < result.count { result[index] = hydratedTrade }
            }
        }
        return result
    }
    
    nonisolated private func fetchItems(ids: [UUID]) async -> [TradeItem] {
        if ids.isEmpty { return [] }
        var items: [TradeItem] = []
        await withTaskGroup(of: TradeItem?.self) { group in
            for id in ids {
                group.addTask { return try? await DatabaseService.shared.fetchItem(id: id) }
            }
            for await item in group {
                if let item = item { items.append(item) }
            }
        }
        return items
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
    
    // ✨ FIX: Removed unused variable warning
    func sendInquiry(wantedItem: TradeItem) async -> Bool {
        // 1. Check if we already have an open trade for this item
        if await hasPendingOffer(for: wantedItem.id) {
            print("ℹ️ Trade already exists, skipping creation.")
            return true
        }
        
        // 2. Select a "Placeholder" Item from my inventory
        guard let placeholderItem = userManager.userItems.first else {
            print("❌ sendInquiry Failed: User has no items to trade.")
            return false
        }
        
        // 3. Create the Trade Offer
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
            guard let tradeStub = response.first else { return nil }
            
            async let offered = try? await self.db.fetchItem(id: tradeStub.offeredItemId)
            async let wanted = try? await self.db.fetchItem(id: tradeStub.wantedItemId)
            let (offeredItem, wantedItem) = await (offered, wanted)
            
            var fullTrade = tradeStub
            fullTrade.offeredItem = offeredItem
            fullTrade.wantedItem = wantedItem
            
            if !fullTrade.additionalOfferedItemIds.isEmpty {
                fullTrade.additionalOfferedItems = await self.fetchItems(ids: fullTrade.additionalOfferedItemIds)
            }
            if !fullTrade.additionalWantedItemIds.isEmpty {
                fullTrade.additionalWantedItems = await self.fetchItems(ids: fullTrade.additionalWantedItemIds)
            }
            return fullTrade
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
