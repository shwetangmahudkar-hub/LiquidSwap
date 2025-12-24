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
        guard let data = image.jpegData(compressionQuality: 0.5) else {
            throw URLError(.badURL)
        }
        let filename = "\(UUID().uuidString).jpg"
        _ = try await client.storage.from("images").upload(filename, data: data, options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: false))
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
        
        // FIXED: Use upsert to handle duplicates gracefully
        try await client.from("likes").upsert(data).execute()
    }
    
    func fetchLikedItems(userId: UUID) async throws -> [TradeItem] {
            struct LikeResponse: Decodable { let item_id: UUID }
            // 1. Get IDs of liked items
            let likes: [LikeResponse] = try await client
                .from("likes")
                .select("item_id")
                .eq("user_id", value: userId)
                .execute()
                .value
            
            let ids = likes.map { $0.item_id }
            
            if ids.isEmpty { return [] }
            
            // 2. Fetch the actual items
            // FIXED TYPO: Changed 'values:' to 'value:'
            return try await client
                .from("items")
                .select()
                .in("id", value: ids) // <--- THIS WAS THE ISSUE
                .execute()
                .value
        }
    
    // MARK: - TRADES (OFFERS)
    
    func createTradeOffer(offer: TradeOffer) async throws {
        try await client.from("trades").insert(offer).execute()
    }
    
    func fetchIncomingOffers(userId: UUID) async throws -> [TradeOffer] {
        return try await client.from("trades").select().eq("receiver_id", value: userId).eq("status", value: "pending").execute().value
    }
    
    func updateTradeStatus(tradeId: UUID, status: String) async throws {
        struct UpdateData: Encodable { let status: String }
        try await client.from("trades").update(UpdateData(status: status)).eq("id", value: tradeId).execute()
    }
}
