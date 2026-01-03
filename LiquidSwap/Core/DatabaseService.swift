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
            .range(from: from, to: to) // ✨ Fetch only this batch
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
        // Only includes columns that actually exist in the 'items' table
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
            .in("id", value: uniqueIds)
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
            .in("id", value: uniqueIds)
            .execute()
            .value
        
        return profiles
    }
    
    func upsertProfile(_ profile: UserProfile) async throws {
        try await client.from("profiles").upsert(profile).execute()
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
            .in("item_id", value: myItemIds)
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
            // Ensure we have both the actor profile and the item data
            if let actor = actorsDict[like.user_id],
               let item = itemsDict[like.item_id] {
                
                // Don't show activity if I liked my own item (edge case)
                if actor.id != userId {
                    let event = ActivityEvent(
                        id: UUID(), // Ephemeral ID
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
            .in("id", value: ids)
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
    
    // ✨ NEW: Added to fix ProductDetailView error
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

    func submitReview(reviewerId: UUID, reviewedId: UUID, rating: Int, comment: String) async throws {
        struct ReviewData: Encodable {
            let reviewer_id: UUID
            let reviewed_user_id: UUID
            let rating: Int
            let comment: String
        }
        let data = ReviewData(reviewer_id: reviewerId, reviewed_user_id: reviewedId, rating: rating, comment: comment)
        try await client.from("reviews").insert(data).execute()
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
    
    func fetchReviewCount(userId: UUID) async throws -> Int {
        let count = try await client
            .from("reviews")
            .select("*", head: true, count: .exact)
            .eq("reviewed_user_id", value: userId)
            .execute()
            .count
        
        return count ?? 0
    }
    
    // MARK: - TRADES
    
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
}
