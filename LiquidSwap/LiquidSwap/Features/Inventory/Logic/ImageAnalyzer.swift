import Vision
import UIKit

struct ImageAnalyzer {
    
    enum AnalysisError: Error {
        case invalidImage
        case processingFailed
    }
    
    /// Analyzes an image and returns the most confident label (e.g., "Laptop")
    static func analyze(image: UIImage) async throws -> [String] {
        guard let ciImage = CIImage(image: image) else {
            throw AnalysisError.invalidImage
        }
        
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                // Get top 5 confident labels
                let labels = observations
                    .filter { $0.confidence > 0.3 }
                    .prefix(5)
                    .map { $0.identifier }
                
                continuation.resume(returning: Array(labels))
            }
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Maps Vision labels to our specific App Categories
    static func suggestCategory(from labels: [String]) -> String {
        // ✨ NEW: Updated Mapping for Granular Categories
        for label in labels {
            let lower = label.lowercased()
            
            // 🎮 Video Games
            if lower.contains("console") || lower.contains("gamepad") || lower.contains("joystick") || lower.contains("controller") || lower.contains("xbox") || lower.contains("playstation") || lower.contains("nintendo") { return "Video Games" }
            
            // 💻 Electronics (General)
            if lower.contains("computer") || lower.contains("phone") || lower.contains("monitor") || lower.contains("screen") || lower.contains("camera") || lower.contains("laptop") { return "Electronics" }
            
            // 👟 Shoes
            if lower.contains("shoe") || lower.contains("sneaker") || lower.contains("boot") || lower.contains("footwear") || lower.contains("sandal") { return "Shoes" }
            
            // 👕 Fashion (General)
            if lower.contains("clothing") || lower.contains("jersey") || lower.contains("shirt") || lower.contains("dress") || lower.contains("coat") || lower.contains("jeans") { return "Fashion" }
            
            // 📚 Books
            if lower.contains("book") || lower.contains("novel") || lower.contains("paperback") || lower.contains("textbook") { return "Books" }
            
            // ⚽ Sports
            if lower.contains("ball") || lower.contains("racket") || lower.contains("sport") || lower.contains("bicycle") || lower.contains("helmet") || lower.contains("skate") { return "Sports" }
            
            // 🏠 Home
            if lower.contains("plant") || lower.contains("flower") || lower.contains("vase") || lower.contains("pot") || lower.contains("furniture") || lower.contains("chair") || lower.contains("sofa") || lower.contains("table") { return "Home & Garden" }
            
            // 🧸 Collectibles
            if lower.contains("toy") || lower.contains("doll") || lower.contains("action figure") || lower.contains("figurine") || lower.contains("lego") { return "Collectibles" }
        }
        
        return "Other" // Default fallback
    }
    
    /// Blocks unsafe content
    static func isSafeContent(labels: [String]) -> Bool {
        let prohibitedTerms = ["weapon", "firearm", "gun", "knife", "blood", "gore", "nudity", "sexual"]
        
        for label in labels {
            for term in prohibitedTerms {
                if label.lowercased().contains(term) {
                    print("⚠️ SAFETY BLOCK: \(label)")
                    return false
                }
            }
        }
        return true
    }
}
