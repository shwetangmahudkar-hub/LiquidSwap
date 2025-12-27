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
    var ownerRating: Double? // ✨ NEW: Rating (0.0 - 5.0)
    var ownerReviewCount: Int? // ✨ NEW: Total reviews
    
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
        // Note: distance, ownerRating, and ownerReviewCount are excluded
        // because they are not columns in the 'items' table.
    }
    
    // Update Init
    init(id: UUID = UUID(), ownerId: UUID = UUID(), title: String, description: String, condition: String, category: String, imageUrl: String?, createdAt: Date = Date(), distance: Double = 0.0, latitude: Double? = nil, longitude: Double? = nil, ownerRating: Double? = nil, ownerReviewCount: Int? = nil) {
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
    }
    
    // Mock Data Update
    static func generateMockItems() -> [TradeItem] {
        return [
            TradeItem(title: "Vintage Camera", description: "Film camera.", condition: "Used", category: "Electronics", imageUrl: nil, distance: 2.5, ownerRating: 4.5, ownerReviewCount: 12),
            TradeItem(title: "Succulent", description: "Nice plant.", condition: "New", category: "Home & Garden", imageUrl: nil, distance: 0.5, ownerRating: 5.0, ownerReviewCount: 3)
        ]
    }
}
