import UIKit

extension UIImage {
    
    /// Resizes the image to a max dimension (e.g., 1080px), fixes orientation, and compresses it.
    /// Returns: Optimized JPEG Data ready for upload.
    func prepareForUpload() -> Data? {
        // 1. Fix Orientation (Redraw image to bake orientation into pixels)
        let fixedImage = self.fixedOrientation()
        
        // 2. Resize if too large (Max 1080px width/height)
        let maxDimension: CGFloat = 1080
        let currentSize = fixedImage.size
        
        var newSize = currentSize
        if currentSize.width > maxDimension || currentSize.height > maxDimension {
            let ratio = currentSize.width / currentSize.height
            if currentSize.width > currentSize.height {
                newSize = CGSize(width: maxDimension, height: maxDimension / ratio)
            } else {
                newSize = CGSize(width: maxDimension * ratio, height: maxDimension)
            }
        }
        
        // 3. Render resized image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            fixedImage.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        // 4. Compress to JPEG
        // Quality 0.7 is the "Golden Ratio" for mobile apps (visual clarity vs. file size)
        guard let data = resizedImage.jpegData(compressionQuality: 0.7) else { return nil }
        
        // 📉 COST OPTIMIZATION LOGGING
        // This will print to the console so you can verify your $0 cost strategy.
        let originalSize = self.jpegData(compressionQuality: 1.0)?.count ?? 0
        let newSizeInBytes = data.count
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        
        let originalString = formatter.string(fromByteCount: Int64(originalSize))
        let newString = formatter.string(fromByteCount: Int64(newSizeInBytes))
        
        print("---------------------------------------------")
        print("📉 IMAGE OPTIMIZATION REPORT")
        print("   Original:   \(originalString) (\(Int(currentSize.width))x\(Int(currentSize.height)))")
        print("   Optimized:  \(newString) (\(Int(newSize.width))x\(Int(newSize.height)))")
        print("   Savings:    Saved bandwidth & storage costs!")
        print("---------------------------------------------")
        
        return data
    }
    
    /// Internal helper to ensure "Up" is actually "Up"
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? self
    }
}
