import Foundation
import SwiftUI

struct DiskManager {
    
    // MARK: - File Paths
    private static func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private static func getFileURL(filename: String) -> URL {
        getDocumentsDirectory().appendingPathComponent(filename)
    }
    
    // MARK: - Generic JSON Saving
    static func save<T: Encodable>(_ data: T, to filename: String) {
        do {
            let url = getFileURL(filename: filename)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let encodedData = try encoder.encode(data)
            try encodedData.write(to: url)
            print("💾 Saved \(filename) to disk.")
        } catch {
            print("❌ Error saving \(filename): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Generic JSON Loading
    static func load<T: Decodable>(_ filename: String, as type: T.Type) -> T? {
        let url = getFileURL(filename: filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: url)
            let decodedData = try JSONDecoder().decode(type, from: data)
            print("📂 Loaded \(filename) from disk.")
            return decodedData
        } catch {
            print("❌ Error loading \(filename): \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Image Saving
    static func saveImage(image: UIImage, name: String) -> String? {
        // We save images as "name.jpg"
        let filename = "\(name).jpg"
        let url = getFileURL(filename: filename)
        
        // Compress to 0.7 quality to save space
        if let data = image.jpegData(compressionQuality: 0.7) {
            do {
                try data.write(to: url)
                return filename // Return the filename to store in the Item object
            } catch {
                print("❌ Error saving image: \(error.localizedDescription)")
            }
        }
        return nil
    }
    
    static func loadImage(named filename: String) -> UIImage? {
        let url = getFileURL(filename: filename)
        if FileManager.default.fileExists(atPath: url.path) {
            return UIImage(contentsOfFile: url.path)
        }
        return nil
    }
    
    // MARK: - NUKE DATA (The Missing Function)
    static func clearAllData() {
        let fileManager = FileManager.default
        let folderURL = getDocumentsDirectory()
        
        do {
            // Get all files in the documents directory
            let fileURLs = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [])
            
            // Loop through and delete them all
            for fileURL in fileURLs {
                try fileManager.removeItem(at: fileURL)
            }
            print("💥 DiskManager: All local data nuked successfully.")
            
        } catch {
            print("❌ Error clearing data: \(error.localizedDescription)")
        }
    }
}
