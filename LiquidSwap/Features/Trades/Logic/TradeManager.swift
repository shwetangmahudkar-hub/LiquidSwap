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
    
    // Error Handling Properties
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let db = DatabaseService.shared
    private let userManager = UserManager.shared
    private let client = SupabaseConfig.client
    
    // Realtime reference
    private var channel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    
    private init() {
        Task { await subscribeToRealtime() }
    }
    
    // MARK: - Error Handling
    private func handleError(_ error: Error, context: String) {
        print("🟥 [TradeManager Error] \(context): \(error.localizedDescription)")
        self.errorMessage = "Failed to \(context). Please try again."
        self.showError = true
    }
    
    func clearError() {
        self.errorMessage = nil
        self.showError = false
    }
    
    // MARK: - Data Loading
    func loadTradesData() async {
        guard let userId = userManager.currentUser?.id else { return }
        self.isLoading = true
        defer { self.isLoading = false }
        
        do {
            // Run all fetches in parallel
            async let interestedResult = loadInterestedItems(userId: userId)
            async let offersResult = loadIncomingOffers(userId: userId)
            async let activeResult = loadActiveTrades(userId: userId)
            
            let (interested, offers, active) = try await (interestedResult, offersResult, activeResult)
            
            self.interestedItems = interested
            self.incomingOffers = offers
            self.activeTrades = active
            
            print("✅ Loaded: \(interested.count) likes, \(offers.count) offers, \(active.count) chats")
        } catch {
            handleError(error, context: "load trades data")
        }
    }
    
    // Helper Loaders
    private func loadInterestedItems(userId: UUID) async throws -> [TradeItem] {
        try await db.fetchLikedItems(userId: userId)
    }
    
    private func loadIncomingOffers(userId: UUID) async throws -> [TradeOffer] {
        let offers = try await db.fetchIncomingOffers(userId: userId)
        return await hydrateTrades(offers)
    }
    
    private func loadActiveTrades(userId: UUID) async throws -> [TradeOffer] {
        let trades = try await db.fetchActiveTrades(userId: userId)
        return await hydrateTrades(trades)
    }
    
    // ✨ FIX: Use 'withTaskGroup' instead of 'withThrowingTaskGroup' to avoid unhandled errors
    private func hydrateTrades(_ trades: [TradeOffer]) async -> [TradeOffer] {
        var result = trades
        
        await withTaskGroup(of: (Int, TradeItem?, TradeItem?).self) { group in
            for (index, trade) in trades.enumerated() {
                group.addTask {
                    // We use try? here so it returns nil instead of throwing
                    async let offered = try? await self.db.fetchItem(id: trade.offeredItemId)
                    async let wanted = try? await self.db.fetchItem(id: trade.wantedItemId)
                    let (offeredItem, wantedItem) = await (offered, wanted)
                    return (index, offeredItem, wantedItem)
                }
            }
            
            for await (index, offeredItem, wantedItem) in group {
                if index < result.count {
                    result[index].offeredItem = offeredItem
                    result[index].wantedItem = wantedItem
                }
            }
        }
        return result
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
            print("✅ Subscribed to real-time trade updates")
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

    func sendOffer(wantedItem: TradeItem, myItem: TradeItem) async -> Bool {
        guard let senderId = userManager.currentUser?.id else { return false }
        if myItem.ownerId != senderId || wantedItem.ownerId == senderId { return false }
        
        if await checkIfOfferExists(wantedItemId: wantedItem.id, myItemId: myItem.id) { return false }
        
        let offer = TradeOffer(id: UUID(), senderId: senderId, receiverId: wantedItem.ownerId, offeredItemId: myItem.id, wantedItemId: wantedItem.id, status: "pending", createdAt: Date())
        do {
            try await db.createTradeOffer(offer: offer)
            interestedItems.removeAll { $0.id == wantedItem.id }
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
            return fullTrade
        } catch { return nil }
    }
}
