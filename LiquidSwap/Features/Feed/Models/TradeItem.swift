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
    
    // NEW: Coordinates
    var latitude: Double?
    var longitude: Double?
    
    // UI-Only Property (Calculated on the fly)
    var distance: Double = 0.0
    
    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case title
        case description
        case condition
        case category
        case imageUrl = "image_url"
        case createdAt = "created_at"
        // Map new fields
        case latitude
        case longitude
        // Note: We deliberately exclude 'distance' from CodingKeys if it's not in DB,
        // OR we map it if it is. Since we added it in SQL previously, we keep it here,
        // but we will overwrite it in the app logic.
        case distance
    }
    
    // Update Init
    init(id: UUID = UUID(), ownerId: UUID = UUID(), title: String, description: String, condition: String, category: String, imageUrl: String?, createdAt: Date = Date(), distance: Double = 0.0, latitude: Double? = nil, longitude: Double? = nil) {
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
    }
    
    // Mock Data Update
    static func generateMockItems() -> [TradeItem] {
        return [
            TradeItem(title: "Vintage Camera", description: "Film camera.", condition: "Used", category: "Electronics", imageUrl: nil, distance: 2.5),
            TradeItem(title: "Succulent", description: "Nice plant.", condition: "New", category: "Home & Garden", imageUrl: nil, distance: 0.5)
        ]
    }
}
