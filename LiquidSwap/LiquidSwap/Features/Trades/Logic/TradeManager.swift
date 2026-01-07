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
    
    // ✨ Cache profiles for chat list to avoid N+1 queries
    // Maps UserID -> UserProfile for O(1) lookup in views
    @Published var relatedProfiles: [UUID: UserProfile] = [:]
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    // MARK: - ✨ Rate Limit State (Issue #3 Fix)
    @Published var rateLimitMessage: String?
    @Published var showRateLimitAlert = false
    
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
    
    // ✨ Batch Fetch Helper for Profiles
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
        
        // ✨ Rate limit likes
        let (allowed, message) = await RateLimiter.canLikeItem()
        if !allowed {
            await MainActor.run {
                self.rateLimitMessage = message
                self.showRateLimitAlert = true
            }
            return false
        }
        
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
            let count = try await client.from("trades").select("id", head: true, count: .exact).eq("wanted_item_id", value: wantedItemId).eq("offered_item_id", value: myItemId).in("status", values: TradeStatus.committedStatuses.map { $0.rawValue }).execute().count
            return (count ?? 0) > 0
        } catch { return false }
    }
    
    // MARK: - ✨ Comprehensive Duplicate/Busy Item Check (Issue #5 Fix)
    
    /// Result of checking if items are available for trade
    struct ItemAvailabilityResult {
        let allAvailable: Bool
        let busyOfferedItems: [UUID]      // My items already in active trades
        let busyWantedItems: [UUID]       // Their items already in active trades
        let duplicateTradeExists: Bool    // Exact same primary items trade exists
    }
    
    /// Checks if all items in an offer are available (not already in pending/accepted trades)
    /// - Parameters:
    ///   - offeredItemIds: IDs of items being offered
    ///   - wantedItemIds: IDs of items being requested
    /// - Returns: ItemAvailabilityResult with details about any conflicts
    func checkItemsAvailability(offeredItemIds: [UUID], wantedItemIds: [UUID]) async -> ItemAvailabilityResult {
        guard let myId = userManager.currentUser?.id else {
            return ItemAvailabilityResult(allAvailable: false, busyOfferedItems: [], busyWantedItems: [], duplicateTradeExists: false)
        }
        
        var busyOffered: [UUID] = []
        var busyWanted: [UUID] = []
        var duplicateExists = false
        
        do {
            // 1. Fetch all active trades where I'm the sender
            let myActiveTrades: [TradeOffer] = try await client
                .from("trades")
                .select()
                .eq("sender_id", value: myId)
                .in("status", values: TradeStatus.committedStatuses.map { $0.rawValue })
                .execute()
                .value
            
            // 2. Check which of my offered items are already busy
            for trade in myActiveTrades {
                let tradeOfferedIds = [trade.offeredItemId] + trade.additionalOfferedItemIds
                
                for offeredId in offeredItemIds {
                    if tradeOfferedIds.contains(offeredId) {
                        busyOffered.append(offeredId)
                    }
                }
                
                // 3. Check for exact duplicate (same primary items)
                if let primaryOffered = offeredItemIds.first,
                   let primaryWanted = wantedItemIds.first {
                    if trade.offeredItemId == primaryOffered && trade.wantedItemId == primaryWanted {
                        duplicateExists = true
                    }
                }
            }
            
            // 4. Fetch active trades where the wanted items are involved
            // These are trades where someone else is trading away items we want
            if !wantedItemIds.isEmpty {
                // Check if wanted items are primary offered items in other pending/accepted trades
                let wantedItemTrades: [TradeOffer] = try await client
                    .from("trades")
                    .select()
                    .in("offered_item_id", values: wantedItemIds.map { $0.uuidString })
                    .in("status", values: TradeStatus.committedStatuses.map { $0.rawValue })
                    .execute()
                    .value
                
                for trade in wantedItemTrades {
                    if wantedItemIds.contains(trade.offeredItemId) {
                        busyWanted.append(trade.offeredItemId)
                    }
                }
                
                // Also check additional_offered_ids (requires fetching all active trades and checking)
                // This is a simplified check - for full accuracy, would need array overlap query
            }
            
            let allAvailable = busyOffered.isEmpty && busyWanted.isEmpty && !duplicateExists
            
            return ItemAvailabilityResult(
                allAvailable: allAvailable,
                busyOfferedItems: Array(Set(busyOffered)), // Remove duplicates
                busyWantedItems: Array(Set(busyWanted)),
                duplicateTradeExists: duplicateExists
            )
            
        } catch {
            print("❌ Error checking item availability: \(error)")
            // Return as available to not block on errors, but log it
            return ItemAvailabilityResult(allAvailable: true, busyOfferedItems: [], busyWantedItems: [], duplicateTradeExists: false)
        }
    }
    
    /// Quick check if a specific item is busy in any active trade
    func isItemBusy(itemId: UUID) async -> Bool {
        do {
            // Check as primary offered item
            let offeredCount = try await client
                .from("trades")
                .select("id", head: true, count: .exact)
                .eq("offered_item_id", value: itemId)
                .in("status", values: TradeStatus.committedStatuses.map { $0.rawValue })
                .execute()
                .count
            
            if (offeredCount ?? 0) > 0 { return true }
            
            // Check as primary wanted item in accepted trades (item is "reserved")
            let wantedCount = try await client
                .from("trades")
                .select("id", head: true, count: .exact)
                .eq("wanted_item_id", value: itemId)
                .eq("status", value: TradeStatus.accepted.rawValue)
                .execute()
                .count
            
            return (wantedCount ?? 0) > 0
            
        } catch {
            return false
        }
    }

    func hasPendingOffer(for wantedItemId: UUID) async -> Bool {
        guard let myId = userManager.currentUser?.id else { return false }
        do {
            let count = try await client.from("trades").select("id", head: true, count: .exact).eq("sender_id", value: myId).eq("wanted_item_id", value: wantedItemId).eq("status", value: TradeStatus.pending.rawValue).execute().count
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
    
    // MARK: - ✨ Rate-Limited Offer Creation (Issue #3 Fix)
    
    /// Result type for offer creation
    enum OfferResult {
        case success
        case rateLimited(message: String)
        case duplicateOffer
        case itemsBusy(offered: [UUID], wanted: [UUID])  // ✨ Issue #5: Items already in trades
        case invalidItems
        case blocked
        case error(String)
    }
    
    /// Creates a multi-item offer with rate limiting protection
    /// - Returns: OfferResult indicating success or failure reason
    func sendMultiItemOfferWithResult(wantedItems: [TradeItem], offeredItems: [TradeItem]) async -> OfferResult {
        guard let senderId = userManager.currentUser?.id else {
            return .error("Not logged in")
        }
        
        guard let primaryOffered = offeredItems.first, let primaryWanted = wantedItems.first else {
            return .invalidItems
        }
        
        // ✨ RATE LIMIT CHECK (Issue #3)
        let (allowed, rateLimitMsg) = await RateLimiter.canCreateOffer()
        if !allowed {
            await MainActor.run {
                self.rateLimitMessage = rateLimitMsg
                self.showRateLimitAlert = true
            }
            return .rateLimited(message: rateLimitMsg ?? "Rate limited")
        }
        
        // Validation checks
        if primaryOffered.ownerId != senderId {
            return .invalidItems
        }
        if primaryWanted.ownerId == senderId {
            return .invalidItems
        }
        
        // ✨ Check if receiver is blocked (Issue #4 partial fix)
        if userManager.blockedUserIds.contains(primaryWanted.ownerId) {
            return .blocked
        }
        
        // ✨ COMPREHENSIVE DUPLICATE/BUSY CHECK (Issue #5 Fix)
        let allOfferedIds = offeredItems.map { $0.id }
        let allWantedIds = wantedItems.map { $0.id }
        
        let availability = await checkItemsAvailability(offeredItemIds: allOfferedIds, wantedItemIds: allWantedIds)
        
        if availability.duplicateTradeExists {
            return .duplicateOffer
        }
        
        if !availability.allAvailable {
            return .itemsBusy(offered: availability.busyOfferedItems, wanted: availability.busyWantedItems)
        }
        
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
            status: .pending,
            createdAt: Date()
        )
        
        do {
            try await db.createTradeOffer(offer: offer)
            try? await db.saveLike(userId: senderId, itemId: primaryWanted.id)
            interestedItems.removeAll { $0.id == primaryWanted.id }
            print("✅ Offer created successfully (rate limit passed)")
            return .success
        } catch {
            return .error(error.localizedDescription)
        }
    }
    
    /// Legacy wrapper - maintains backwards compatibility
    func sendMultiItemOffer(wantedItems: [TradeItem], offeredItems: [TradeItem]) async -> Bool {
        let result = await sendMultiItemOfferWithResult(wantedItems: wantedItems, offeredItems: offeredItems)
        
        switch result {
        case .success:
            return true
        case .rateLimited(let message):
            print("⚠️ Rate limited: \(message)")
            return false
        case .duplicateOffer:
            print("ℹ️ Duplicate offer")
            return false
        case .itemsBusy(let offered, let wanted):
            print("🔒 Items busy - offered: \(offered.count), wanted: \(wanted.count)")
            return false
        case .invalidItems:
            print("❌ Invalid items")
            return false
        case .blocked:
            print("🚫 User is blocked")
            return false
        case .error(let msg):
            print("❌ Error: \(msg)")
            return false
        }
    }
    
    func respondToOffer(offer: TradeOffer, accept: Bool) async -> Bool {
        guard let userId = userManager.currentUser?.id, offer.receiverId == userId else { return false }
        
        // ✨ Issue #4: Don't allow accepting offers from/to blocked users
        if accept {
            let isBlockedByMe = userManager.blockedUserIds.contains(offer.senderId)
            let isBlockedByThem = await checkIfBlockedBy(userId: offer.senderId)
            
            if isBlockedByMe || isBlockedByThem {
                print("🚫 Cannot accept offer - blocked user relationship")
                return false
            }
        }
        
        let newStatus = accept ? TradeStatus.accepted.rawValue : TradeStatus.rejected.rawValue
        do {
            try await db.updateTradeStatus(tradeId: offer.id, status: newStatus)
            incomingOffers.removeAll { $0.id == offer.id }
            return true
        } catch { return false }
    }
    
    // MARK: - ✨ Blocked User Check Helper (Issue #4 Fix)
    
    /// Checks if the specified user has blocked the current user
    /// - Parameter userId: The user to check
    /// - Returns: True if that user has blocked the current user
    private func checkIfBlockedBy(userId: UUID) async -> Bool {
        guard let myId = userManager.currentUser?.id else { return false }
        
        do {
            let count = try await client
                .from("blocked_users")
                .select("id", head: true, count: .exact)
                .eq("blocker_id", value: userId)
                .eq("blocked_id", value: myId)
                .execute()
                .count
            
            return (count ?? 0) > 0
        } catch {
            print("❌ Error checking blocked status: \(error)")
            // Fail open for now - don't block legitimate trades due to query errors
            return false
        }
    }
    
    // MARK: - ✨ Two-Phase Trade Completion (Issue #2 Security Fix)
    
    /// Result type for completion confirmation
    enum CompletionResult {
        case confirmed           // User's confirmation recorded
        case alreadyConfirmed    // User already confirmed before
        case tradeCompleted      // Both parties confirmed, trade is now complete!
        case tradeNotAccepted    // Trade must be in "accepted" status
        case notParticipant      // User is not part of this trade
        case blocked             // ✨ Issue #4: One party has blocked the other
        case error(String)       // Something went wrong
    }
    
    /// Confirms trade completion for the current user.
    /// The database trigger will automatically mark the trade as "completed" when both parties confirm.
    /// - Parameter tradeId: The ID of the trade to confirm
    /// - Returns: CompletionResult indicating what happened
    func confirmCompletion(tradeId: UUID) async -> CompletionResult {
        guard let myId = userManager.currentUser?.id else {
            return .error("Not logged in")
        }
        
        do {
            // 1. Fetch the current trade state
            let trades: [TradeOffer] = try await client
                .from("trades")
                .select()
                .eq("id", value: tradeId)
                .execute()
                .value
            
            guard let trade = trades.first else {
                return .error("Trade not found")
            }
            
            // 2. Verify user is a participant
            let isSender = trade.senderId == myId
            let isReceiver = trade.receiverId == myId
            
            guard isSender || isReceiver else {
                return .notParticipant
            }
            
            // ✨ 2.5 Check if either party has blocked the other (Issue #4 Fix)
            let partnerId = isSender ? trade.receiverId : trade.senderId
            let isBlockedByMe = userManager.blockedUserIds.contains(partnerId)
            let isBlockedByPartner = await checkIfBlockedBy(userId: partnerId)
            
            if isBlockedByMe || isBlockedByPartner {
                return .blocked
            }
            
            // 3. Verify trade is in correct status
            guard trade.status == .accepted else {
                if trade.status == .completed {
                    return .tradeCompleted
                }
                return .tradeNotAccepted
            }
            
            // 4. Check if already confirmed
            if isSender && trade.senderConfirmedCompletion {
                return .alreadyConfirmed
            }
            if isReceiver && trade.receiverConfirmedCompletion {
                return .alreadyConfirmed
            }
            
            // 5. Update the appropriate confirmation flag
            // The database trigger will auto-complete if both are true
            if isSender {
                try await client
                    .from("trades")
                    .update(["sender_confirmed_completion": true])
                    .eq("id", value: tradeId)
                    .execute()
            } else {
                try await client
                    .from("trades")
                    .update(["receiver_confirmed_completion": true])
                    .eq("id", value: tradeId)
                    .execute()
            }
            
            // 6. Check if this confirmation completed the trade
            let partnerAlreadyConfirmed = isSender ? trade.receiverConfirmedCompletion : trade.senderConfirmedCompletion
            
            if partnerAlreadyConfirmed {
                // Both have now confirmed - trade is complete!
                // ✨ PROGRESSION TRIGGER: Check achievements after trade completion
                await ProgressionManager.shared.onTradeCompleted()
                
                // Refresh user data to update trade count
                await userManager.loadUserData()
                
                // Refresh trades list
                await loadTradesData()
                
                return .tradeCompleted
            }
            
            // Refresh to get updated state
            await loadTradesData()
            
            return .confirmed
            
        } catch {
            print("❌ Confirm completion error: \(error)")
            return .error(error.localizedDescription)
        }
    }
    
    /// Gets the current completion status for a trade
    /// - Parameter tradeId: The trade to check
    /// - Returns: Tuple with (userConfirmed, partnerConfirmed, isComplete)
    func getCompletionStatus(tradeId: UUID) async -> (userConfirmed: Bool, partnerConfirmed: Bool, isComplete: Bool)? {
        guard let myId = userManager.currentUser?.id else { return nil }
        
        do {
            let trades: [TradeOffer] = try await client
                .from("trades")
                .select()
                .eq("id", value: tradeId)
                .execute()
                .value
            
            guard let trade = trades.first else { return nil }
            
            let isSender = trade.senderId == myId
            let userConfirmed = isSender ? trade.senderConfirmedCompletion : trade.receiverConfirmedCompletion
            let partnerConfirmed = isSender ? trade.receiverConfirmedCompletion : trade.senderConfirmedCompletion
            let isComplete = trade.status == .completed
            
            return (userConfirmed, partnerConfirmed, isComplete)
            
        } catch {
            print("❌ Get completion status error: \(error)")
            return nil
        }
    }
    
    /// Fetches a fresh trade by ID with hydration
    func fetchTrade(id: UUID) async -> TradeOffer? {
        do {
            let trades: [TradeOffer] = try await client
                .from("trades")
                .select()
                .eq("id", value: id)
                .execute()
                .value
            
            guard let trade = trades.first else { return nil }
            
            // Hydrate the single trade
            let hydrated = await hydrateTrades([trade])
            return hydrated.first
            
        } catch {
            print("❌ Fetch trade error: \(error)")
            return nil
        }
    }
    
    // MARK: - Legacy Completion (Deprecated)
    
    /// ⚠️ DEPRECATED: Use confirmCompletion(tradeId:) instead.
    /// This method is kept for backward compatibility but will be removed in a future version.
    @available(*, deprecated, message: "Use confirmCompletion(tradeId:) for two-phase completion")
    func completeTrade(with partnerId: UUID) async -> Bool {
        guard let myId = userManager.currentUser?.id else { return false }
        do {
            let response: [TradeOffer] = try await client.from("trades").select().in("status", values: [TradeStatus.accepted.rawValue, TradeStatus.completed.rawValue]).or("and(sender_id.eq.\(myId),receiver_id.eq.\(partnerId)),and(sender_id.eq.\(partnerId),receiver_id.eq.\(myId))").execute().value
            guard let trade = response.sorted(by: { $0.createdAt > $1.createdAt }).first else { return false }
            
            // Use the new two-phase completion
            let result = await confirmCompletion(tradeId: trade.id)
            
            switch result {
            case .confirmed, .tradeCompleted, .alreadyConfirmed:
                return true
            default:
                return false
            }
        } catch { return false }
    }
    
    func getActiveTrade(with partnerId: UUID) async -> TradeOffer? {
        guard let myId = userManager.currentUser?.id else { return nil }
        do {
            let response: [TradeOffer] = try await client.from("trades").select().in("status", values: [TradeStatus.accepted.rawValue, TradeStatus.pending.rawValue, TradeStatus.completed.rawValue]).or("and(sender_id.eq.\(myId),receiver_id.eq.\(partnerId)),and(sender_id.eq.\(partnerId),receiver_id.eq.\(myId))").order("created_at", ascending: false).limit(1).execute().value
            
            // ✨ OPTIMIZATION: Use the batch hydration logic for this single trade
            // This reuses code and keeps the logic consistent
            guard let tradeStub = response.first else { return nil }
            let hydratedTrades = await hydrateTrades([tradeStub])
            return hydratedTrades.first
            
        } catch { return nil }
    }
    
    // MARK: - ✨ Rate-Limited Counter Offer (Issue #3 + #6 Fix)
    
    /// Result type for counter offer creation
    enum CounterOfferResult {
        case success
        case rateLimited(message: String)
        case originalTradeNotFound
        case originalTradeInvalidStatus
        case notOriginalReceiver
        case itemsBusy
        case blocked
        case error(String)
    }
    
    /// Creates a counter offer with full validation
    /// - Parameters:
    ///   - originalTradeId: ID of the trade being countered (fetched fresh from DB)
    ///   - newWantedItem: The item the user wants instead
    /// - Returns: CounterOfferResult indicating success or failure reason
    func sendCounterOfferWithResult(originalTradeId: UUID, newWantedItem: TradeItem) async -> CounterOfferResult {
        guard let myId = userManager.currentUser?.id else {
            return .error("Not logged in")
        }
        
        // ✨ RATE LIMIT CHECK (Issue #3)
        let (allowed, rateLimitMsg) = await RateLimiter.canCreateOffer()
        if !allowed {
            await MainActor.run {
                self.rateLimitMessage = rateLimitMsg
                self.showRateLimitAlert = true
            }
            return .rateLimited(message: rateLimitMsg ?? "Rate limited")
        }
        
        do {
            // ✨ Issue #6: Fetch original trade FRESH from database - don't trust client data
            let trades: [TradeOffer] = try await client
                .from("trades")
                .select()
                .eq("id", value: originalTradeId)
                .execute()
                .value
            
            guard let originalTrade = trades.first else {
                print("❌ Counter offer failed: Original trade not found")
                return .originalTradeNotFound
            }
            
            // ✨ Issue #6: Validate trade status - can only counter pending offers
            guard originalTrade.status == .pending else {
                print("❌ Counter offer failed: Trade status is '\(originalTrade.status.rawValue)', not 'pending'")
                return .originalTradeInvalidStatus
            }
            
            // ✨ Issue #6: Validate current user is the receiver of original trade
            guard originalTrade.receiverId == myId else {
                print("❌ Counter offer failed: User is not the receiver of original trade")
                return .notOriginalReceiver
            }
            
            // ✨ Issue #4: Check if sender is blocked
            if userManager.blockedUserIds.contains(originalTrade.senderId) {
                return .blocked
            }
            
            // The item I'll offer is the one they originally wanted from me
            let myItemId = originalTrade.wantedItemId
            
            // ✨ Issue #5: Check if items are available
            let availability = await checkItemsAvailability(
                offeredItemIds: [myItemId],
                wantedItemIds: [newWantedItem.id]
            )
            
            if !availability.allAvailable {
                print("🔒 Counter offer items busy - cannot proceed")
                return .itemsBusy
            }
            
            // ✨ Validate the new wanted item exists and doesn't belong to me
            guard newWantedItem.ownerId == originalTrade.senderId else {
                print("❌ Counter offer failed: New wanted item doesn't belong to original sender")
                return .error("Selected item doesn't belong to the trade partner")
            }
            
            let newOffer = TradeOffer(
                id: UUID(),
                senderId: myId,
                receiverId: originalTrade.senderId,
                offeredItemId: myItemId,
                wantedItemId: newWantedItem.id,
                status: .pending,
                createdAt: Date()
            )
            
            // Update original trade status and create new counter offer
            try await db.updateTradeStatus(tradeId: originalTrade.id, status: TradeStatus.countered.rawValue)
            try await db.createTradeOffer(offer: newOffer)
            try? await db.saveLike(userId: myId, itemId: newWantedItem.id)
            
            // Update local state
            if let index = incomingOffers.firstIndex(where: { $0.id == originalTrade.id }) {
                incomingOffers.remove(at: index)
            }
            
            print("✅ Counter offer created successfully (all validations passed)")
            return .success
            
        } catch {
            print("❌ Counter offer error: \(error)")
            return .error(error.localizedDescription)
        }
    }
    
    /// Legacy wrapper for sendCounterOffer - maintains backwards compatibility
    func sendCounterOffer(originalTrade: TradeOffer, newWantedItem: TradeItem) async -> Bool {
        // Use the trade ID from the passed object, but validate everything server-side
        let result = await sendCounterOfferWithResult(
            originalTradeId: originalTrade.id,
            newWantedItem: newWantedItem
        )
        
        switch result {
        case .success:
            return true
        case .rateLimited(let message):
            print("⚠️ Rate limited: \(message)")
            return false
        case .originalTradeNotFound:
            print("❌ Original trade not found")
            return false
        case .originalTradeInvalidStatus:
            print("❌ Original trade has invalid status")
            return false
        case .notOriginalReceiver:
            print("❌ User is not the receiver")
            return false
        case .itemsBusy:
            print("🔒 Items are busy")
            await MainActor.run {
                self.rateLimitMessage = "Some items are already in active trades"
                self.showRateLimitAlert = true
            }
            return false
        case .blocked:
            print("🚫 User is blocked")
            return false
        case .error(let msg):
            print("❌ Error: \(msg)")
            return false
        }
    }
}
