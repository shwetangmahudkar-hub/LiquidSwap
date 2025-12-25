import SwiftUI
import CoreLocation

struct TradeItem: Identifiable, Codable, Hashable {
    var id: UUID
    var ownerId: UUID // Links to the user who posted it
    var title: String
    var description: String
    var condition: String
    var category: String
    var imageUrl: String? // The Cloud URL (was imageFilename)
    var createdAt: Date
    
    // We keep this for backward compatibility with the Feed UI
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
    }
    
    // Default Initializer
    init(id: UUID = UUID(), ownerId: UUID = UUID(), title: String, description: String, condition: String, category: String, imageUrl: String?, createdAt: Date = Date(), distance: Double = 0.0) {
        self.id = id
        self.ownerId = ownerId
        self.title = title
        self.description = description
        self.condition = condition
        self.category = category
        self.imageUrl = imageUrl
        self.createdAt = createdAt
        self.distance = distance
    }
    
    // Mock Data Generator (Updated for Cloud Model)
    static func generateMockItems() -> [TradeItem] {
        return [
            TradeItem(title: "Vintage Camera", description: "Film camera.", condition: "Used", category: "Electronics", imageUrl: nil, distance: 2.5),
            TradeItem(title: "Succulent", description: "Nice plant.", condition: "New", category: "Home & Garden", imageUrl: nil, distance: 0.5),
            TradeItem(title: "Fixie Bike", description: "Fast bike.", condition: "Fair", category: "Sports", imageUrl: nil, distance: 5.0)
        ]
    }
}
