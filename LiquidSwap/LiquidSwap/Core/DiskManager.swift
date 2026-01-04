import SwiftUI

struct DiskManager {
    
    // MARK: - Configuration
    /// The name of the folder inside the Caches directory where images will be stored.
    private static let cacheFolderName = "ImageCache"
    
    // MARK: - Public Methods
    
    /// Saves a UIImage to the disk cache.
    /// - Parameters:
    ///   - image: The UIImage to save.
    ///   - name: The filename (including extension) to use.
    /// - Returns: The file path String if successful, otherwise nil.
    static func saveImage(image: UIImage, name: String) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8),
              let url = getImageURL(for: name) else {
            return nil
        }
        
        do {
            try data.write(to: url)
            return url.path
        } catch {
            print("❌ DiskManager: Error saving image \(name): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Loads a UIImage from the disk cache.
    /// - Parameter name: The filename to look for.
    /// - Returns: The UIImage if found, otherwise nil.
    static func loadImage(named name: String) -> UIImage? {
        guard let url = getImageURL(for: name),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            return UIImage(data: data)
        } catch {
            print("❌ DiskManager: Error loading image \(name): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Deletes a specific image from the cache (useful for profile updates).
    static func deleteImage(named name: String) {
        guard let url = getImageURL(for: name),
              FileManager.default.fileExists(atPath: url.path) else { return }
        
        try? FileManager.default.removeItem(at: url)
    }
    
    /// Clears the entire image cache folder (useful for settings/maintenance).
    static func clearCache() {
        guard let folderURL = getCacheFolderURL() else { return }
        try? FileManager.default.removeItem(at: folderURL)
    }
    
    // MARK: - Private Helpers
    
    /// Gets the full URL for a specific image file, creating the directory if needed.
    private static func getImageURL(for name: String) -> URL? {
        guard let folderURL = getCacheFolderURL() else { return nil }
        return folderURL.appendingPathComponent(name)
    }
    
    /// Gets (and creates if necessary) the URL for the cache folder.
    private static func getCacheFolderURL() -> URL? {
        guard let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let folderURL = cacheDirectory.appendingPathComponent(cacheFolderName)
        
        // Create the directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            } catch {
                print("❌ DiskManager: Could not create cache directory: \(error.localizedDescription)")
                return nil
            }
        }
        
        return folderURL
    }
}
