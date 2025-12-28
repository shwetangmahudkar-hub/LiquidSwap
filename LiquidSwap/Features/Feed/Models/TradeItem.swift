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
    
    // Coordinates
    var latitude: Double?
    var longitude: Double?
    
    // UI-Only Properties (Calculated on the fly)
    var distance: Double = 0.0
    var ownerRating: Double? // Rating (0.0 - 5.0)
    var ownerReviewCount: Int? // Total reviews
    var ownerUsername: String? // Owner's Handle
    
    // ✨ NEW: Verification Status
    var ownerIsVerified: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case title
        case description
        case condition
        case category
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case latitude
        case longitude
        // Note: UI-only properties are excluded from DB coding keys
    }
    
    // Update Init
    init(id: UUID = UUID(),
         ownerId: UUID = UUID(),
         title: String,
         description: String,
         condition: String,
         category: String,
         imageUrl: String?,
         createdAt: Date = Date(),
         distance: Double = 0.0,
         latitude: Double? = nil,
         longitude: Double? = nil,
         ownerRating: Double? = nil,
         ownerReviewCount: Int? = nil,
         ownerUsername: String? = nil,
         ownerIsVerified: Bool? = nil) { // ✨ NEW param
        
        self.id = id
        self.ownerId = ownerId
        self.title = title
        self.description = description
        self.condition = condition
        self.category = category
        self.imageUrl = imageUrl
        self.createdAt = createdAt
        self.distance = distance
        self.latitude = latitude
        self.longitude = longitude
        self.ownerRating = ownerRating
        self.ownerReviewCount = ownerReviewCount
        self.ownerUsername = ownerUsername
        self.ownerIsVerified = ownerIsVerified
    }
    
    // Mock Data Update
    static func generateMockItems() -> [TradeItem] {
        return [
            TradeItem(
                title: "Vintage Camera",
                description: "Film camera.",
                condition: "Used",
                category: "Electronics",
                imageUrl: nil,
                distance: 2.5,
                ownerRating: 4.5,
                ownerReviewCount: 12,
                ownerUsername: "CameraGuy",
                ownerIsVerified: true // ✨ Verified
            ),
            TradeItem(
                title: "Succulent",
                description: "Nice plant.",
                condition: "New",
                category: "Home & Garden",
                imageUrl: nil,
                distance: 0.5,
                ownerRating: 5.0,
                ownerReviewCount: 3,
                ownerUsername: "PlantMom",
                ownerIsVerified: false // Not Verified
            )
        ]
    }
}
