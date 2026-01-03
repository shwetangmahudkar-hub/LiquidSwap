import SwiftUI
import CoreLocation

struct TradeItem: Identifiable, Codable, Hashable {
    var id: UUID
    var ownerId: UUID
    var title: String
    var description: String
    var condition: String
    var category: String
    var imageUrl: String?
    var createdAt: Date
    
    // ✨ Value & Donation
    var price: Double?        // Added to store the estimated value
    var isDonation: Bool
    
    // Coordinates
    var latitude: Double?
    var longitude: Double?
    
    // UI-Only Properties (Hydrated by FeedManager)
    var distance: Double = 0.0
    var ownerRating: Double?
    var ownerReviewCount: Int?
    var ownerUsername: String?
    var ownerIsVerified: Bool?
    
    // Gamification & Premium Stats
    var ownerTradeCount: Int?
    var ownerIsPremium: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case title
        case description
        case condition
        case category
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case price
        case isDonation = "is_donation"
        case latitude
        case longitude
        
        // Note: UI-only fields are usually not decoded from the 'items' table directly
        // unless you are using a view or join.
        // We exclude them here for the base table decode if they aren't columns.
        // If your Supabase query joins profiles, we handle that in the service.
    }
    
    // Custom Decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        ownerId = try container.decode(UUID.self, forKey: .ownerId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        condition = try container.decode(String.self, forKey: .condition)
        category = try container.decode(String.self, forKey: .category)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        price = try container.decodeIfPresent(Double.self, forKey: .price)
        isDonation = try container.decodeIfPresent(Bool.self, forKey: .isDonation) ?? false
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        
        // Defaults
        distance = 0.0
        ownerRating = nil
        ownerReviewCount = nil
        ownerUsername = nil
        ownerIsVerified = nil
        ownerTradeCount = nil
        ownerIsPremium = nil
    }
    
    // Memberwise Init
    init(id: UUID = UUID(),
         ownerId: UUID = UUID(),
         title: String,
         description: String,
         condition: String,
         category: String,
         imageUrl: String?,
         createdAt: Date = Date(),
         price: Double? = nil,
         isDonation: Bool = false,
         distance: Double = 0.0,
         latitude: Double? = nil,
         longitude: Double? = nil,
         ownerRating: Double? = nil,
         ownerReviewCount: Int? = nil,
         ownerUsername: String? = nil,
         ownerIsVerified: Bool? = nil,
         ownerTradeCount: Int? = nil,
         ownerIsPremium: Bool? = nil) {
        
        self.id = id
        self.ownerId = ownerId
        self.title = title
        self.description = description
        self.condition = condition
        self.category = category
        self.imageUrl = imageUrl
        self.createdAt = createdAt
        self.price = price
        self.isDonation = isDonation
        self.distance = distance
        self.latitude = latitude
        self.longitude = longitude
        self.ownerRating = ownerRating
        self.ownerReviewCount = ownerReviewCount
        self.ownerUsername = ownerUsername
        self.ownerIsVerified = ownerIsVerified
        self.ownerTradeCount = ownerTradeCount
        self.ownerIsPremium = ownerIsPremium
    }
    
    // Mock Data
    static func generateMockItems() -> [TradeItem] {
        return [
            TradeItem(
                title: "Vintage Camera",
                description: "Film camera.",
                condition: "Used",
                category: "Electronics",
                imageUrl: nil,
                price: 150.0,
                isDonation: false,
                distance: 2.5,
                ownerRating: 4.5,
                ownerReviewCount: 12,
                ownerUsername: "CameraGuy",
                ownerIsVerified: true,
                ownerTradeCount: 15,
                ownerIsPremium: true
            )
        ]
    }
}
