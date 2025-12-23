import SwiftUI

struct TradeItem: Identifiable, Hashable, Equatable, Codable {
    var id = UUID()
    let title: String
    let description: String
    let distance: String
    let category: String
    let ownerName: String
    let systemImage: String
    let colorString: String
    
    // NEW: We only save the filename, not the heavy data
    var imageFilename: String?
    
    // Computed: Fetch from Disk on demand
    var uiImage: UIImage? {
        if let filename = imageFilename {
            return DiskManager.shared.loadImage(filename: filename)
        }
        return nil
    }
    
    // Helper for Color
    var color: Color {
        switch colorString {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "brown": return .brown
        case "yellow": return .yellow
        case "cyan": return .cyan
        default: return .cyan
        }
    }
    
    // Init for Creating Items
    init(title: String, description: String, distance: String, category: String, ownerName: String, systemImage: String, color: Color, uiImage: UIImage? = nil) {
        self.title = title
        self.description = description
        self.distance = distance
        self.category = category
        self.ownerName = ownerName
        self.systemImage = systemImage
        
        // Save Color
        switch color {
        case .blue: self.colorString = "blue"
        case .green: self.colorString = "green"
        case .orange: self.colorString = "orange"
        case .brown: self.colorString = "brown"
        case .yellow: self.colorString = "yellow"
        default: self.colorString = "cyan"
        }
        
        // Save Image to Disk immediately
        if let image = uiImage {
            // Use ID as filename to ensure uniqueness
            self.imageFilename = DiskManager.shared.saveImage(image, id: self.id.uuidString)
        }
    }
}

// Mock Data
extension TradeItem {
    static let mockData: [TradeItem] = [
        TradeItem(title: "Vintage Film Camera", description: "Canon AE-1", distance: "1.2km", category: "Electronics", ownerName: "Sarah J.", systemImage: "camera.fill", color: .orange),
        TradeItem(title: "Monstera Plant", description: "Healthy plant", distance: "500m", category: "Plants", ownerName: "Mike R.", systemImage: "leaf.fill", color: .green),
        TradeItem(title: "Leather Jacket", description: "Size M", distance: "3.5km", category: "Fashion", ownerName: "Alex T.", systemImage: "tshirt", color: .brown),
        TradeItem(title: "Gaming Headset", description: "Noise cancelling", distance: "8km", category: "Tech", ownerName: "Davide V.", systemImage: "headphones", color: .blue),
        TradeItem(title: "Mid-Century Lamp", description: "Needs bulb", distance: "2.1km", category: "Decor", ownerName: "Emily W.", systemImage: "lamp.table.fill", color: .yellow)
    ]
}
