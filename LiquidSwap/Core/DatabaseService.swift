import Foundation
import Supabase
import SwiftUI

class DatabaseService {
    static let shared = DatabaseService()
    
    // Uses the client configured in SupabaseConfig.swift
    private let client = SupabaseConfig.client
    
    private init() {}
    
    // MARK: - ITEM ACTIONS
    
    func uploadImage(_ image: UIImage) async throws -> String {
        guard let data = image.prepareForUpload() else {
            throw URLError(.badURL)
        }
        
        let filename = "\(UUID().uuidString).jpg"
        
        _ = try await client.storage.from("images").upload(
            filename,
            data: data,
            options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: false)
        )
        
        return try client.storage.from("images").getPublicURL(path: filename).absoluteString
    }
    
    func createItem(item: TradeItem) async throws {
        try await client.from("items").insert(item).execute()
    }
    
    func updateItem(_ item: TradeItem) async throws {
        try await client.from("items").update(item).eq("id", value: item.id).execute()
    }
    
    func deleteItem(id: UUID) async throws {
        try await client.from("items").delete().eq("id", value: id).execute()
    }
    
    // MARK: - FETCHING ITEMS
    
    func fetchUserItems(userId: UUID) async throws -> [TradeItem] {
        return try await client.from("items").select().eq("owner_id", value: userId).order("created_at", ascending: false).execute().value
    }
    
    func fetchFeedItems(currentUserId: UUID) async throws -> [TradeItem] {
        return try await client.from("items").select().neq("owner_id", value: currentUserId).order("created_at", ascending: false).execute().value
    }
    
    func fetchItem(id: UUID) async throws -> TradeItem {
        return try await client.from("items").select().eq("id", value: id).single().execute().value
    }
    
    // MARK: - LIKES (INTERESTED)
    
    func saveLike(userId: UUID, itemId: UUID) async throws {
        struct LikeData: Encodable {
            let user_id: UUID
            let item_id: UUID
        }
        let data = LikeData(user_id: userId, item_id: itemId)
        try await client.from("likes").upsert(data).execute()
    }
    
    func fetchLikedItems(userId: UUID) async throws -> [TradeItem] {
        struct LikeResponse: Decodable { let item_id: UUID }
        
        let likes: [LikeResponse] = try await client
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
    
    func fetchActivityEvents(for userId: UUID) async throws -> [ActivityEvent] {
        // 1. Get My Items
        let myItems = try await fetchUserItems(userId: userId)
        if myItems.isEmpty {
            print("🔍 Activity Debug: User has no items.")
            return []
        }
        
        let myItemMap = Dictionary(uniqueKeysWithValues: myItems.map { ($0.id, $0) })
        let myItemIds = myItems.map { $0.id }
        
        print("🔍 Activity Debug: Checking likes for \(myItemIds.count) items...")
        
        // 2. Find who liked them
        struct RawLike: Decodable {
            let userId: UUID
            let itemId: UUID
            let createdAt: Date?
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case itemId = "item_id"
                case createdAt = "created_at"
            }
        }
        
        let interests: [RawLike] = try await client
            .from("likes")
            .select("user_id, item_id, created_at")
            .in("item_id", value: myItemIds)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        print("🔍 Activity Debug: Found \(interests.count) raw likes.")
        
        // 3. Hydrate (Fetch Profiles of Likers)
        var events: [ActivityEvent] = []
        let likerIds = Array(Set(interests.map { $0.userId }))
        
        var profileMap: [UUID: UserProfile] = [:]
        for uid in likerIds {
            if uid != userId {
                if let p = try? await fetchProfile(userId: uid) {
                    profileMap[uid] = p
                }
            }
        }
        
        for interest in interests {
            if let item = myItemMap[interest.itemId],
               let actor = profileMap[interest.userId] {
                
                if actor.id != userId {
                    let event = ActivityEvent(
                        actor: actor,
                        item: item,
                        createdAt: interest.createdAt ?? Date(),
                        status: .pending
                    )
                    events.append(event)
                }
            }
        }
        
        return events
    }
    
    // MARK: - TRADES (OFFERS)
    
    func createTradeOffer(offer: TradeOffer) async throws {
        try await client.from("trades").insert(offer).execute()
    }
    
    func fetchIncomingOffers(userId: UUID) async throws -> [TradeOffer] {
        return try await client.from("trades").select().eq("receiver_id", value: userId).eq("status", value: "pending").execute().value
    }
    
    func fetchActiveTrades(userId: UUID) async throws -> [TradeOffer] {
        return try await client
            .from("trades")
            .select()
            .or("sender_id.eq.\(userId),receiver_id.eq.\(userId)")
            .in("status", values: ["accepted", "completed"])
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    
    func updateTradeStatus(tradeId: UUID, status: String) async throws {
        struct UpdateData: Encodable { let status: String }
        try await client.from("trades").update(UpdateData(status: status)).eq("id", value: tradeId).execute()
    }
    
    // MARK: - PROFILES
    
    func fetchProfile(userId: UUID) async throws -> UserProfile {
        return try await client.from("profiles").select().eq("id", value: userId).single().execute().value
    }
    
    func upsertProfile(_ profile: UserProfile) async throws {
        try await client.from("profiles").upsert(profile).execute()
    }
    
    // MARK: - BLOCKING (SAFETY)
    
    func blockUser(blockerId: UUID, blockedId: UUID) async throws {
        struct BlockData: Encodable {
            let blocker_id: UUID
            let blocked_id: UUID
        }
        let data = BlockData(blocker_id: blockerId, blocked_id: blockedId)
        try await client.from("blocked_users").insert(data).execute()
    }
    
    func unblockUser(blockerId: UUID, blockedId: UUID) async throws {
        try await client.from("blocked_users")
            .delete()
            .eq("blocker_id", value: blockerId)
            .eq("blocked_id", value: blockedId)
            .execute()
    }
    
    func fetchBlockedUsers(userId: UUID) async throws -> [UUID] {
        struct BlockedResponse: Decodable {
            let blocked_id: UUID
        }
        
        let records: [BlockedResponse] = try await client
            .from("blocked_users")
            .select("blocked_id")
            .eq("blocker_id", value: userId)
            .execute()
            .value
            
        return records.map { $0.blocked_id }
    }
    
    // MARK: - REPORTING & REVIEWS
    
    func reportItem(itemId: UUID, userId: UUID, reason: String) async throws {
        struct ReportData: Encodable {
            let item_id: UUID
            let reporter_id: UUID
            let reason: String
        }
        let data = ReportData(item_id: itemId, reporter_id: userId, reason: reason)
        try await client.from("reports").insert(data).execute()
    }
    
    func reportUser(reporterId: UUID, reportedId: UUID, reason: String) async throws {
         // Re-using the same reports table but we might need a null item_id or a specific user report structure.
         // For MVP, we will assume we add a 'reported_user_id' column or just log it.
         // We'll stick to blocking for immediate safety, but here is a placeholder.
         print("User reported: \(reportedId)")
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
        let reviews: [RatingResponse] = try await client.from("reviews").select("rating").eq("reviewed_user_id", value: userId).execute().value
        if reviews.isEmpty { return 0.0 }
        let total = reviews.reduce(0) { $0 + $1.rating }
        return Double(total) / Double(reviews.count)
    }
    
    func fetchReviewCount(userId: UUID) async throws -> Int {
        let count = try await client.from("reviews").select("*", head: true, count: .exact).eq("reviewed_user_id", value: userId).execute().count
        return count ?? 0
    }
}
