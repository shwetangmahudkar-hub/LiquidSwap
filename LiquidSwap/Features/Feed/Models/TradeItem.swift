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
    
    // Donation Flag
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
    
    // ✨ NEW: Gamification & Premium Stats
    var ownerTradeCount: Int? // Used to calculate Level (e.g. "Eco Trader")
    var ownerIsPremium: Bool? // Used to show Gold Badge
    
    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case title
        case description
        case condition
        case category
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case isDonation = "is_donation"
        case latitude
        case longitude
    }
    
    // Custom Decoder to handle optionals safely
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
        isDonation = try container.decodeIfPresent(Bool.self, forKey: .isDonation) ?? false
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        
        // Default UI properties
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
    
    // Mock Data (Updated for Testing)
    static func generateMockItems() -> [TradeItem] {
        return [
            TradeItem(
                title: "Vintage Camera",
                description: "Film camera.",
                condition: "Used",
                category: "Electronics",
                imageUrl: nil,
                isDonation: false,
                distance: 2.5,
                ownerRating: 4.5,
                ownerReviewCount: 12,
                ownerUsername: "CameraGuy",
                ownerIsVerified: true,
                ownerTradeCount: 15, // "Swap Savant"
                ownerIsPremium: true
            ),
            TradeItem(
                title: "Succulent",
                description: "Nice plant.",
                condition: "New",
                category: "Home & Garden",
                imageUrl: nil,
                isDonation: false,
                distance: 0.5,
                ownerRating: 5.0,
                ownerReviewCount: 3,
                ownerUsername: "PlantMom",
                ownerIsVerified: false,
                ownerTradeCount: 2, // "Novice"
                ownerIsPremium: false
            ),
            TradeItem(
                title: "Old Sofa",
                description: "Comfy but old. Free to anyone who can pick it up!",
                condition: "Fair",
                category: "Furniture",
                imageUrl: nil,
                isDonation: true,
                distance: 1.2,
                ownerRating: 4.8,
                ownerReviewCount: 20,
                ownerUsername: "FreeCycleFan",
                ownerIsVerified: true,
                ownerTradeCount: 55, // "Legendary"
                ownerIsPremium: true
            )
        ]
    }
}
