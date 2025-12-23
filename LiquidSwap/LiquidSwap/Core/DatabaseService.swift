import Foundation
import Supabase
import SwiftUI

class DatabaseService {
    static let shared = DatabaseService()
    private let client = SupabaseConfig.client
    
    private init() {}
    
    // MARK: - ITEM ACTIONS
    
    // 1. Upload Image to Storage Bucket
    func uploadImage(_ image: UIImage) async throws -> String {
        // Convert UIImage to Data
        guard let data = image.jpegData(compressionQuality: 0.5) else {
            throw URLError(.badURL)
        }
        
        let filename = "\(UUID().uuidString).jpg"
        
        // FIXED:
        // 1. Pass 'data' directly (not a File struct).
        // 2. Use 'options' label instead of 'fileOptions'.
        // 3. Set content type inside FileOptions.
        _ = try await client.storage
            .from("images")
            .upload(
                filename,
                data: data,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: false
                )
            )
        
        // FIXED: Use 'getPublicURL' (Capital URL)
        let publicURL = try client.storage
            .from("images")
            .getPublicURL(path: filename)
        
        return publicURL.absoluteString
    }
    
    // 2. Create Item in Database
    func createItem(item: TradeItem) async throws {
        try await client
            .from("items")
            .insert(item)
            .execute()
    }
    
    // 3. Fetch User's Items (Inventory)
    func fetchUserItems(userId: UUID) async throws -> [TradeItem] {
        let response: [TradeItem] = try await client
            .from("items")
            .select()
            .eq("owner_id", value: userId)
            .order("created_at", ascending: false) // Newest first
            .execute()
            .value
        
        return response
    }
    
    // 4. Fetch Feed Items (Everything EXCEPT current user's items)
    func fetchFeedItems(currentUserId: UUID) async throws -> [TradeItem] {
        let response: [TradeItem] = try await client
            .from("items")
            .select()
            .neq("owner_id", value: currentUserId) // Not Equal to Me
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    // 5. Delete Item
    func deleteItem(id: UUID) async throws {
        try await client
            .from("items")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
