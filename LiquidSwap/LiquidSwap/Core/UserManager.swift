import SwiftUI
import Combine

class UserManager: ObservableObject {
    static let shared = UserManager()
    
    // --- PROFILE & STATS ---
    @Published var userName: String = ""
    @Published var userBio: String = ""
    @Published var userLocation: String = ""
    @Published var userProfileFilename: String? = nil
    @Published var isFirstLaunch: Bool = true
    
    // NEW: Trust Stats
    @Published var tradeCount: Int = 0
    @Published var reputationScore: Double = 5.0 // Start with perfect score
    
    var userProfileImage: UIImage? {
        if let filename = userProfileFilename {
            return DiskManager.shared.loadImage(filename: filename)
        }
        return nil
    }
    
    // --- INVENTORY ---
    @Published var myItems: [TradeItem] = [] {
        didSet { saveItems() }
    }
    
    @Published var isoCategories: Set<String> = [] {
        didSet { saveISO() }
    }
    
    let allCategories = ["Electronics", "Fashion", "Home", "Plants", "Books", "Services", "Decor", "Tech"]
    
    private init() {
        print("UserManager: Initializing...")
        loadProfile()
        loadISO()
        loadItems()
    }
    
    // --- ACTIONS ---
    
    func completeOnboarding(name: String, image: UIImage?) {
        self.userName = name
        if let img = image {
            self.userProfileFilename = DiskManager.shared.saveImage(img, id: "user_avatar")
        }
        self.isFirstLaunch = false
        saveProfile()
    }
    
    func updateProfile(name: String, bio: String, location: String, image: UIImage?) {
        self.userName = name
        self.userBio = bio
        self.userLocation = location
        
        if let img = image {
            if let oldFilename = userProfileFilename {
                DiskManager.shared.deleteImage(filename: oldFilename)
            }
            self.userProfileFilename = DiskManager.shared.saveImage(img, id: "user_avatar_\(Date().timeIntervalSince1970)")
        }
        
        saveProfile()
        objectWillChange.send()
    }
    
    // NEW: Mark a trade as complete
    func completeTrade(for item: TradeItem) {
        // 1. Increment Count
        tradeCount += 1
        
        // 2. Simulate a Rating (Randomized slightly for realism, but mostly positive)
        // In a real app, the other user would rate you.
        let newRating = Double.random(in: 4.5...5.0)
        
        // Weighted Average Calculation
        let totalScore = (reputationScore * Double(tradeCount - 1)) + newRating
        reputationScore = totalScore / Double(tradeCount)
        
        // 3. Remove the item (It's gone!)
        deleteItem(item)
        
        // 4. Save
        saveProfile()
        print("UserManager: Trade Complete! New Score: \(String(format: "%.1f", reputationScore))")
    }
    
    func addItem(_ item: TradeItem) {
        myItems.insert(item, at: 0)
    }
    
    func deleteItem(_ item: TradeItem) {
        objectWillChange.send()
        if let index = myItems.firstIndex(where: { $0.id == item.id }) {
            if let filename = item.imageFilename {
                DiskManager.shared.deleteImage(filename: filename)
            }
            myItems.remove(at: index)
        }
    }
    
    func updateItem(_ updatedItem: TradeItem) {
        if let index = myItems.firstIndex(where: { $0.id == updatedItem.id }) {
            myItems[index] = updatedItem
        }
    }
    
    func toggleISO(_ category: String) {
        objectWillChange.send()
        if isoCategories.contains(category) {
            isoCategories.remove(category)
        } else {
            isoCategories.insert(category)
        }
    }
    
    func resetAllData() {
            // 1. Wipe UserDefaults (Settings)
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
            
            // 2. Wipe Disk Images
            // (For a real app, we'd loop through all files. For MVP, we'll just clear the current references)
            // Ideally, DiskManager would have a clearAll() function, but removing references is enough to "hide" them.
            
            // 3. Reset State in Memory
            self.userName = ""
            self.userBio = ""
            self.userLocation = ""
            self.tradeCount = 0
            self.reputationScore = 5.0
            self.myItems = []
            self.isoCategories = ["Electronics", "Plants", "Fashion"]
            self.userProfileFilename = nil
            self.isFirstLaunch = true // Trigger Onboarding again
            
            print("UserManager: ⚠️ SYSTEM RESET COMPLETE ⚠️")
        }
    
    // --- PERSISTENCE ---
    
    private func saveISO() {
        if let encoded = try? JSONEncoder().encode(isoCategories) {
            UserDefaults.standard.set(encoded, forKey: "userISO")
        }
    }
    
    private func saveItems() {
        if let encoded = try? JSONEncoder().encode(myItems) {
            UserDefaults.standard.set(encoded, forKey: "userItems")
        }
    }
    
    private func saveProfile() {
        UserDefaults.standard.set(userName, forKey: "userName")
        UserDefaults.standard.set(userBio, forKey: "userBio")
        UserDefaults.standard.set(userLocation, forKey: "userLocation")
        UserDefaults.standard.set(isFirstLaunch, forKey: "isFirstLaunch")
        
        // NEW: Save Stats
        UserDefaults.standard.set(tradeCount, forKey: "tradeCount")
        UserDefaults.standard.set(reputationScore, forKey: "reputationScore")
        
        if let filename = userProfileFilename {
            UserDefaults.standard.set(filename, forKey: "userProfileFilename")
        }
    }
    
    private func loadProfile() {
        self.userName = UserDefaults.standard.string(forKey: "userName") ?? ""
        self.userBio = UserDefaults.standard.string(forKey: "userBio") ?? ""
        self.userLocation = UserDefaults.standard.string(forKey: "userLocation") ?? ""
        
        if UserDefaults.standard.object(forKey: "isFirstLaunch") != nil {
            self.isFirstLaunch = UserDefaults.standard.bool(forKey: "isFirstLaunch")
        } else {
            self.isFirstLaunch = true
        }
        
        // NEW: Load Stats
        self.tradeCount = UserDefaults.standard.integer(forKey: "tradeCount")
        // Default to 5.0 if not set, or if tradeCount is 0
        let loadedScore = UserDefaults.standard.double(forKey: "reputationScore")
        self.reputationScore = loadedScore > 0 ? loadedScore : 5.0
        
        self.userProfileFilename = UserDefaults.standard.string(forKey: "userProfileFilename")
    }
    
    private func loadISO() {
        if let data = UserDefaults.standard.data(forKey: "userISO"),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            self.isoCategories = decoded
        } else {
            self.isoCategories = ["Electronics", "Plants", "Fashion"]
        }
    }
    
    private func loadItems() {
        if let data = UserDefaults.standard.data(forKey: "userItems"),
           let decoded = try? JSONDecoder().decode([TradeItem].self, from: data) {
            self.myItems = decoded
        } else {
            self.myItems = []
        }
    }
}
