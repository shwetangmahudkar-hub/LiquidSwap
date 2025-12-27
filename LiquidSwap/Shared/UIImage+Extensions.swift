import UIKit

extension UIImage {
    /// Resizes the image to a max dimension (e.g., 1080px) and fixes orientation.
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
        return resizedImage.jpegData(compressionQuality: 0.7)
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