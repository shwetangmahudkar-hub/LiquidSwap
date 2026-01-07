import Foundation
import Supabase
import SwiftUI

class DatabaseService {
    static let shared = DatabaseService()
    
    // Uses the client configured in SupabaseConfig.swift
    private let client = SupabaseConfig.client
    
    private init() {}
    
    // MARK: - FEED (✨ PAGINATION ADDED)
    
    func fetchFeedItems(page: Int, pageSize: Int) async throws -> [TradeItem] {
        // Calculate the range for Supabase (0-based index)
        let from = page * pageSize
        let to = from + pageSize - 1
        
        return try await client
            .from("items")
            .select()
            .order("created_at", ascending: false)
            .range(from: from, to: to)
            .execute()
            .value
    }
    
    // MARK: - ITEM ACTIONS
    
    func uploadImage(_ image: UIImage) async throws -> String {
        // 📉 COST OPTIMIZATION: Compress before upload
        guard let data = image.prepareForUpload() else {
            throw URLError(.badURL)
        }
        
        let filename = "\(UUID().uuidString).jpg"
        
        // Cache for 1 year (31536000)
        _ = try await client.storage.from("images").upload(
            filename,
            data: data,
            options: FileOptions(cacheControl: "31536000", contentType: "image/jpeg", upsert: false)
        )
        
        return try client.storage.from("images").getPublicURL(path: filename).absoluteString
    }
    
    func createItem(item: TradeItem) async throws {
        // ✨ DTO (Data Transfer Object) for safe insertion
        struct TradeItemInsert: Encodable {
            let id: UUID
            let owner_id: UUID
            let title: String
            let description: String
            let condition: String
            let category: String
            let image_url: String?
            let created_at: Date
            let price: Double?
            let is_donation: Bool
            let latitude: Double?
            let longitude: Double?
        }
        
        let insertData = TradeItemInsert(
            id: item.id,
            owner_id: item.ownerId,
            title: item.title,
            description: item.description,
            condition: item.condition,
            category: item.category,
            image_url: item.imageUrl,
            created_at: item.createdAt,
            price: item.price,
            is_donation: item.isDonation,
            latitude: item.latitude,
            longitude: item.longitude
        )
        
        try await client.from("items").insert(insertData).execute()
    }
    
    func fetchItem(id: UUID) async throws -> TradeItem {
        try await client.from("items").select().eq("id", value: id).single().execute().value
    }
    
    // ✨ NEW: Batch Fetch Items (Optimizes TradeManager Cost & Speed)
    func fetchBatchItems(ids: [UUID]) async throws -> [TradeItem] {
        let uniqueIds = Array(Set(ids))
        if uniqueIds.isEmpty { return [] }
        
        return try await client
            .from("items")
            .select()
            .in("id", values: uniqueIds)
            .execute()
            .value
    }
    
    func updateItem(_ item: TradeItem) async throws {
        try await client.from("items").update(item).eq("id", value: item.id).execute()
    }
    
    func deleteItem(id: UUID) async throws {
        try await client.from("items").delete().eq("id", value: id).execute()
    }
    
    func fetchUserItems(userId: UUID) async throws -> [TradeItem] {
        return try await client
            .from("items")
            .select()
            .eq("owner_id", value: userId)
            .execute()
            .value
    }
    
    // MARK: - PROFILE ACTIONS
    
    func fetchProfile(userId: UUID) async throws -> UserProfile {
        return try await client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
    }
    
    // ✨ Batch Fetching for Chat List Optimization
    func fetchProfiles(userIds: [UUID]) async throws -> [UserProfile] {
        let uniqueIds = Array(Set(userIds))
        if uniqueIds.isEmpty { return [] }
        
        let profiles: [UserProfile] = try await client
            .from("profiles")
            .select()
            .in("id", values: uniqueIds)
            .execute()
            .value
        
        return profiles
    }
    
    func upsertProfile(_ profile: UserProfile) async throws {
        try await client.from("profiles").upsert(profile).execute()
    }
    
    // ✨ NEW: XP Persistence
    func updateUserXP(userId: UUID, xp: Int) async throws {
        struct XPUpdate: Encodable {
            let xp: Int
        }
        // Minimal payload update to save bandwidth
        try await client
            .from("profiles")
            .update(XPUpdate(xp: xp))
            .eq("id", value: userId)
            .execute()
    }
    
    // MARK: - ✨ STREAK MANAGEMENT (NEW)
    
    /// Updates user's streak data in the database
    func updateStreak(userId: UUID, currentStreak: Int, longestStreak: Int, lastActiveDate: Date) async throws {
        struct StreakUpdate: Encodable {
            let current_streak: Int
            let longest_streak: Int
            let last_active_date: Date
        }
        
        let data = StreakUpdate(
            current_streak: currentStreak,
            longest_streak: longestStreak,
            last_active_date: lastActiveDate
        )
        
        try await client
            .from("profiles")
            .update(data)
            .eq("id", value: userId)
            .execute()
    }
    
    /// Fetches streak data for a specific user (useful for public profiles)
    func fetchStreakData(userId: UUID) async throws -> (current: Int, longest: Int) {
        struct StreakResponse: Decodable {
            let current_streak: Int?
            let longest_streak: Int?
        }
        
        let response: StreakResponse = try await client
            .from("profiles")
            .select("current_streak, longest_streak")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        
        return (response.current_streak ?? 0, response.longest_streak ?? 0)
    }
    
    // MARK: - ACTIVITY & EVENTS
    
    func fetchActivityEvents(for userId: UUID) async throws -> [ActivityEvent] {
        // 1. Get my items to see who liked them
        let myItems = try await fetchUserItems(userId: userId)
        let myItemIds = myItems.map { $0.id }
        if myItemIds.isEmpty { return [] }
        
        // 2. Fetch likes on these items
        struct LikeEntry: Decodable {
            let user_id: UUID
            let item_id: UUID
            let created_at: Date
        }
        
        let likes: [LikeEntry] = try await client
            .from("likes")
            .select()
            .in("item_id", values: myItemIds)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        if likes.isEmpty { return [] }
        
        // 3. Get the profiles of the actors (people who liked)
        let actorIds = likes.map { $0.user_id }
        let actors = try await fetchProfiles(userIds: actorIds)
        
        // 4. Create Lookup Dictionaries
        let actorsDict = Dictionary(uniqueKeysWithValues: actors.map { ($0.id, $0) })
        let itemsDict = Dictionary(uniqueKeysWithValues: myItems.map { ($0.id, $0) })
        
        // 5. Build Event Objects
        var events: [ActivityEvent] = []
        
        for like in likes {
            if let actor = actorsDict[like.user_id],
               let item = itemsDict[like.item_id] {
                
                // Don't show activity if I liked my own item
                if actor.id != userId {
                    let event = ActivityEvent(
                        id: UUID(),
                        actor: actor,
                        item: item,
                        createdAt: like.created_at,
                        status: .pending
                    )
                    events.append(event)
                }
            }
        }
        
        return events
    }
    
    // MARK: - LIKES
    
    func saveLike(userId: UUID, itemId: UUID) async throws {
        struct LikeData: Encodable {
            let user_id: UUID
            let item_id: UUID
        }
        let data = LikeData(user_id: userId, item_id: itemId)
        try await client.from("likes").insert(data).execute()
    }
    
    func fetchLikedItems(userId: UUID) async throws -> [TradeItem] {
        struct Like: Decodable { let item_id: UUID }
        let likes: [Like] = try await client
            .from("likes")
            .select("item_id")
            .eq("user_id", value: userId)
            .execute()
            .value
        
        let ids = likes.map { $0.item_id }
        if ids.isEmpty { return [] }
        
        return try await client
            .from("items")
            .select()
            .in("id", values: ids)
            .execute()
            .value
    }
    
    // MARK: - SOCIAL ACTIONS
    
    func blockUser(blockerId: UUID, blockedId: UUID) async throws {
        struct BlockData: Encodable {
            let blocker_id: UUID
            let blocked_id: UUID
        }
        let data = BlockData(blocker_id: blockerId, blocked_id: blockedId)
        try await client.from("blocks").insert(data).execute()
    }
    
    func unblockUser(blockerId: UUID, blockedId: UUID) async throws {
        try await client.from("blocks")
            .delete()
            .match(["blocker_id": blockerId, "blocked_id": blockedId])
            .execute()
    }
    
    func fetchBlockedUsers(userId: UUID) async throws -> [UUID] {
        struct BlockResponse: Decodable { let blocked_id: UUID }
        let blocks: [BlockResponse] = try await client
            .from("blocks")
            .select("blocked_id")
            .eq("blocker_id", value: userId)
            .execute()
            .value
        return blocks.map { $0.blocked_id }
    }
    
    func reportItem(itemId: UUID, userId: UUID, reason: String) async throws {
        struct ReportData: Encodable {
            let item_id: UUID
            let reporter_id: UUID
            let reason: String
        }
        let data = ReportData(item_id: itemId, reporter_id: userId, reason: reason)
        try await client.from("reports").insert(data).execute()
    }
    
    func reportUser(reporterId: UUID, reportedId: UUID, reason: String, itemId: UUID? = nil) async throws {
        struct ReportData: Encodable {
            let item_id: UUID?
            let reporter_id: UUID
            let reason: String
        }
        let data = ReportData(item_id: itemId, reporter_id: reporterId, reason: reason)
        try await client.from("reports").insert(data).execute()
    }

    // MARK: - ✨ REVIEWS (Issue #8 Security Fix)
    
    /// Result type for review submission
    enum ReviewResult {
        case success
        case noCompletedTrade
        case alreadyReviewed
        case cannotReviewSelf
        case invalidRating
        case error(String)
    }
    
    /// Submits a review with full trade verification
    /// - Parameters:
    ///   - reviewerId: The user submitting the review
    ///   - reviewedId: The user being reviewed
    ///   - tradeId: The completed trade this review is for
    ///   - rating: Rating 1-5
    ///   - comment: Review comment
    /// - Returns: ReviewResult indicating success or failure
    func submitReviewWithVerification(
        reviewerId: UUID,
        reviewedId: UUID,
        tradeId: UUID,
        rating: Int,
        comment: String
    ) async throws -> ReviewResult {
        
        // 1. Cannot review yourself
        guard reviewerId != reviewedId else {
            return .cannotReviewSelf
        }
        
        // 2. Validate rating
        guard (1...5).contains(rating) else {
            return .invalidRating
        }
        
        // 3. Verify a completed trade exists between these users
        let tradeExists = try await verifyCompletedTrade(
            tradeId: tradeId,
            userId1: reviewerId,
            userId2: reviewedId
        )
        
        guard tradeExists else {
            print("❌ Review rejected: No completed trade found")
            return .noCompletedTrade
        }
        
        // 4. Check if already reviewed this trade
        let alreadyReviewed = try await hasReviewedTrade(
            reviewerId: reviewerId,
            tradeId: tradeId
        )
        
        guard !alreadyReviewed else {
            print("❌ Review rejected: Already reviewed this trade")
            return .alreadyReviewed
        }
        
        // 5. Submit the review with trade reference
        struct ReviewData: Encodable {
            let reviewer_id: UUID
            let reviewed_user_id: UUID
            let trade_id: UUID
            let rating: Int
            let comment: String
        }
        
        let data = ReviewData(
            reviewer_id: reviewerId,
            reviewed_user_id: reviewedId,
            trade_id: tradeId,
            rating: rating,
            comment: comment
        )
        
        try await client.from("reviews").insert(data).execute()
        print("✅ Review submitted successfully for trade: \(tradeId)")
        
        return .success
    }
    
    /// Verifies that a completed trade exists between two users
    private func verifyCompletedTrade(tradeId: UUID, userId1: UUID, userId2: UUID) async throws -> Bool {
        struct TradeCheck: Decodable {
            let id: UUID
            let sender_id: UUID
            let receiver_id: UUID
            let status: String
        }
        
        let trades: [TradeCheck] = try await client
            .from("trades")
            .select("id, sender_id, receiver_id, status")
            .eq("id", value: tradeId)
            .eq("status", value: "completed")
            .execute()
            .value
        
        guard let trade = trades.first else {
            return false
        }
        
        // Verify both users are participants in this trade
        let participants = [trade.sender_id, trade.receiver_id]
        return participants.contains(userId1) && participants.contains(userId2)
    }
    
    /// Checks if a user has already reviewed a specific trade
    private func hasReviewedTrade(reviewerId: UUID, tradeId: UUID) async throws -> Bool {
        let count = try await client
            .from("reviews")
            .select("id", head: true, count: .exact)
            .eq("reviewer_id", value: reviewerId)
            .eq("trade_id", value: tradeId)
            .execute()
            .count
        
        return (count ?? 0) > 0
    }
    
    /// Finds a completed trade between two users (for legacy support)
    func findCompletedTrade(userId1: UUID, userId2: UUID) async throws -> UUID? {
        struct TradeResult: Decodable {
            let id: UUID
        }
        
        let trades: [TradeResult] = try await client
            .from("trades")
            .select("id")
            .eq("status", value: "completed")
            .or("and(sender_id.eq.\(userId1),receiver_id.eq.\(userId2)),and(sender_id.eq.\(userId2),receiver_id.eq.\(userId1))")
            .order("completed_at", ascending: false)
            .limit(1)
            .execute()
            .value
        
        return trades.first?.id
    }
    
    /// Checks if a review is pending for a completed trade
    func canReviewTrade(reviewerId: UUID, tradeId: UUID) async throws -> Bool {
        // First verify the trade is completed and user is participant
        struct TradeCheck: Decodable {
            let sender_id: UUID
            let receiver_id: UUID
            let status: String
        }
        
        let trades: [TradeCheck] = try await client
            .from("trades")
            .select("sender_id, receiver_id, status")
            .eq("id", value: tradeId)
            .execute()
            .value
        
        guard let trade = trades.first,
              trade.status == "completed",
              (trade.sender_id == reviewerId || trade.receiver_id == reviewerId) else {
            return false
        }
        
        // Check if already reviewed
        let alreadyReviewed = try await hasReviewedTrade(reviewerId: reviewerId, tradeId: tradeId)
        
        return !alreadyReviewed
    }
    
    /// Legacy method - maintains backwards compatibility but now requires verification
    @available(*, deprecated, message: "Use submitReviewWithVerification for secure reviews")
    func submitReview(reviewerId: UUID, reviewedId: UUID, rating: Int, comment: String) async throws {
        // Try to find a completed trade between these users
        guard let tradeId = try await findCompletedTrade(userId1: reviewerId, userId2: reviewedId) else {
            throw NSError(domain: "ReviewError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No completed trade found between users"])
        }
        
        let result = try await submitReviewWithVerification(
            reviewerId: reviewerId,
            reviewedId: reviewedId,
            tradeId: tradeId,
            rating: rating,
            comment: comment
        )
        
        switch result {
        case .success:
            return
        case .noCompletedTrade:
            throw NSError(domain: "ReviewError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No completed trade found"])
        case .alreadyReviewed:
            throw NSError(domain: "ReviewError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Already reviewed this trade"])
        case .cannotReviewSelf:
            throw NSError(domain: "ReviewError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot review yourself"])
        case .invalidRating:
            throw NSError(domain: "ReviewError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid rating"])
        case .error(let msg):
            throw NSError(domain: "ReviewError", code: 5, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }
    
    func fetchUserRating(userId: UUID) async throws -> Double {
        struct RatingResponse: Decodable { let rating: Int }
        let reviews: [RatingResponse] = try await client
            .from("reviews")
            .select("rating")
            .eq("reviewed_user_id", value: userId)
            .execute()
            .value
        
        if reviews.isEmpty { return 0.0 }
        let total = reviews.reduce(0) { $0 + $1.rating }
        return Double(total) / Double(reviews.count)
    }
    
    /// Count of reviews received by a user
    func fetchReviewCount(userId: UUID) async throws -> Int {
        let count = try await client
            .from("reviews")
            .select("*", head: true, count: .exact)
            .eq("reviewed_user_id", value: userId)
            .execute()
            .count
        
        return count ?? 0
    }
    
    // ✨ NEW: Count of reviews given by a user (for Community Star achievement)
    func fetchReviewsGivenCount(userId: UUID) async throws -> Int {
        let count = try await client
            .from("reviews")
            .select("*", head: true, count: .exact)
            .eq("reviewer_id", value: userId)
            .execute()
            .count
        
        return count ?? 0
    }
    
    // ✨ NEW: Fetch recent reviews for display
    func fetchUserReviews(userId: UUID, limit: Int = 10) async throws -> [UserReview] {
        return try await client
            .from("reviews")
            .select()
            .eq("reviewed_user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }
    
    // MARK: - TRADES
    
    /// ✨ Issue #9: Cancel all trades involving a specific item before deletion
    /// Returns the count of cancelled trades
    @discardableResult
    func cancelTradesForItem(itemId: UUID) async throws -> Int {
        // Find all active trades where this item is involved
        // (as offered item, wanted item, or in additional items arrays)
        struct TradeToCancel: Decodable {
            let id: UUID
            let offered_item_id: UUID
            let wanted_item_id: UUID
            let additional_offered_item_ids: [UUID]?
            let additional_wanted_item_ids: [UUID]?
            let status: String
        }
        
        // Fetch all non-completed, non-cancelled trades
        let trades: [TradeToCancel] = try await client
            .from("trades")
            .select("id, offered_item_id, wanted_item_id, additional_offered_item_ids, additional_wanted_item_ids, status")
            .in("status", values: TradeStatus.committedStatuses.map { $0.rawValue })
            .execute()
            .value
        
        // Filter trades that involve this item
        var tradesToCancel: [UUID] = []
        
        for trade in trades {
            var involvesItem = false
            
            // Check primary items
            if trade.offered_item_id == itemId || trade.wanted_item_id == itemId {
                involvesItem = true
            }
            
            // Check additional offered items
            if let additionalOffered = trade.additional_offered_item_ids,
               additionalOffered.contains(itemId) {
                involvesItem = true
            }
            
            // Check additional wanted items
            if let additionalWanted = trade.additional_wanted_item_ids,
               additionalWanted.contains(itemId) {
                involvesItem = true
            }
            
            if involvesItem {
                tradesToCancel.append(trade.id)
            }
        }
        
        // Cancel all found trades
        if !tradesToCancel.isEmpty {
            struct StatusUpdate: Encodable {
                let status: String
            }
            
            for tradeId in tradesToCancel {
                try await client
                    .from("trades")
                    .update(StatusUpdate(status: TradeStatus.cancelled.rawValue))
                    .eq("id", value: tradeId)
                    .execute()
            }
            
            print("🗑️ Cancelled \(tradesToCancel.count) trades for deleted item: \(itemId)")
        }
        
        return tradesToCancel.count
    }
    
    func fetchIncomingOffers(userId: UUID) async throws -> [TradeOffer] {
        return try await client
            .from("trades")
            .select()
            .eq("receiver_id", value: userId)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    
    func fetchActiveTrades(userId: UUID) async throws -> [TradeOffer] {
        return try await client
            .from("trades")
            .select()
            .or("sender_id.eq.\(userId),receiver_id.eq.\(userId)")
            .neq("status", value: "cancelled")
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    
    func updateTradeStatus(tradeId: UUID, status: String) async throws {
        struct UpdateStatus: Encodable { let status: String }
        try await client
            .from("trades")
            .update(UpdateStatus(status: status))
            .eq("id", value: tradeId)
            .execute()
    }
    
    func createTradeOffer(offer: TradeOffer) async throws {
        try await client.from("trades").insert(offer).execute()
    }
    
    // MARK: - ✨ PROGRESSION STATISTICS (NEW)
    
    /// Fetches trades within a date range (for streak calculations & achievements)
    func fetchTradesInDateRange(userId: UUID, from startDate: Date, to endDate: Date) async throws -> Int {
        let count = try await client
            .from("trades")
            .select("id", head: true, count: .exact)
            .or("sender_id.eq.\(userId),receiver_id.eq.\(userId)")
            .eq("status", value: "completed")
            .gte("created_at", value: startDate.ISO8601Format())
            .lte("created_at", value: endDate.ISO8601Format())
            .execute()
            .count
        
        return count ?? 0
    }
    
    /// Fetches category breakdown for a user's completed trades (for Category King achievement)
    func fetchTradeCategoryBreakdown(userId: UUID) async throws -> [String: Int] {
        // First get all completed trades for this user
        struct TradeWithItems: Decodable {
            let offered_item_id: UUID
            let wanted_item_id: UUID
        }
        
        let trades: [TradeWithItems] = try await client
            .from("trades")
            .select("offered_item_id, wanted_item_id")
            .or("sender_id.eq.\(userId),receiver_id.eq.\(userId)")
            .eq("status", value: "completed")
            .execute()
            .value
        
        if trades.isEmpty { return [:] }
        
        // Collect all item IDs
        var itemIds = Set<UUID>()
        for trade in trades {
            itemIds.insert(trade.offered_item_id)
            itemIds.insert(trade.wanted_item_id)
        }
        
        // Fetch items to get categories
        let items = try await fetchBatchItems(ids: Array(itemIds))
        
        // Count categories
        var categoryCount: [String: Int] = [:]
        for item in items {
            categoryCount[item.category, default: 0] += 1
        }
        
        return categoryCount
    }
    
    /// Checks if user has received any 5-star reviews (for Five Star achievement)
    func hasReceivedFiveStarReview(userId: UUID) async throws -> Bool {
        let count = try await client
            .from("reviews")
            .select("id", head: true, count: .exact)
            .eq("reviewed_user_id", value: userId)
            .eq("rating", value: 5)
            .execute()
            .count
        
        return (count ?? 0) > 0
    }
}

// MARK: - ✨ UserReview Model (NEW)

struct UserReview: Codable, Identifiable {
    let id: UUID
    let reviewerId: UUID
    let reviewedUserId: UUID
    let rating: Int
    let comment: String
    let createdAt: Date
    let tradeId: UUID?  // ✨ Added trade reference
    
    // Optional: Hydrated reviewer profile
    var reviewerProfile: UserProfile?
    
    enum CodingKeys: String, CodingKey {
        case id
        case reviewerId = "reviewer_id"
        case reviewedUserId = "reviewed_user_id"
        case rating
        case comment
        case createdAt = "created_at"
        case tradeId = "trade_id"
    }
}
