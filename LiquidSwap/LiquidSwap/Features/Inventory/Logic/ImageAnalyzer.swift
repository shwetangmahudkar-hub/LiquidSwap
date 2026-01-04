import Vision
import UIKit

struct ImageAnalyzer {
    
    enum AnalysisError: Error {
        case invalidImage
        case processingFailed
    }
    
    // MARK: - Configuration
    
    /// Keywords mapped to App Categories for intelligent scoring
    private static let categoryRules: [String: [String]] = [
        "Video Games": ["console", "game", "xbox", "playstation", "nintendo", "controller", "joystick", "gamepad", "arcade", "esports"],
        "Electronics": ["computer", "laptop", "phone", "mobile", "screen", "monitor", "keyboard", "camera", "lens", "headphone", "audio", "speaker", "tablet", "electronic"],
        "Shoes": ["shoe", "sneaker", "boot", "footwear", "sandal", "heel", "loafer", "cleat", "canvas"],
        "Fashion": ["clothing", "shirt", "t-shirt", "dress", "pants", "jeans", "jacket", "coat", "apparel", "jersey", "hoodie", "sweater", "accessory", "bag", "purse", "wallet", "watch"],
        "Books": ["book", "novel", "textbook", "paperback", "hardcover", "fiction", "magazine", "comic", "literature", "library"],
        "Sports": ["sport", "ball", "racket", "helmet", "bicycle", "bike", "skate", "surf", "gym", "fitness", "exercise", "jersey", "stadium", "roller"],
        "Home & Garden": ["furniture", "chair", "table", "sofa", "couch", "plant", "flower", "vase", "pot", "lamp", "light", "decor", "kitchen", "appliance", "tool", "garden", "cutlery"],
        "Collectibles": ["toy", "doll", "figurine", "action figure", "lego", "antique", "vintage", "coin", "card", "memorabilia", "plush"]
    ]
    
    /// Terms that flag an image as potentially unsafe
    private static let unsafeKeywords: [String] = [
        "weapon", "gun", "firearm", "pistol", "rifle", "knife", "dagger", "sword", "blade",
        "blood", "gore", "wound", "injury",
        "nudity", "erotic", "sexual", "lingerie", "panties", "thong"
    ]
    
    /// ✨ NEW: Contexts where "unsafe" words are actually safe
    private static let safeExceptions: [String: [String]] = [
        "knife": ["kitchen", "chef", "butter", "steak", "palette", "plastic", "cutlery", "utensil", "paring"],
        "gun": ["glue", "massage", "tape", "nerf", "water", "toy", "spray", "caulking"],
        "blade": ["roller", "fan", "razor", "skate", "wiper", "propeller"],
        "sword": ["toy", "plastic", "foam", "lego"],
        "blood": ["orange"], // "Blood Orange"
        "thong": ["sandal"] // "Thong Sandals"
    ]
    
    // MARK: - Public Actions
    
    /// Analyzes an image and returns the most confident labels
    static func analyze(image: UIImage) async throws -> [String] {
        guard let ciImage = CIImage(image: image) else {
            throw AnalysisError.invalidImage
        }
        
        // ⚡️ PERFORMANCE: Run on background thread
        return try await Task.detached(priority: .userInitiated) {
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
                    
                    // Filter: High confidence only
                    let labels = observations
                        .filter { $0.confidence > 0.3 }
                        .prefix(15) // Increased to 15 to catch contextual words (e.g., "Kitchen" + "Knife")
                        .map { $0.identifier }
                    
                    continuation.resume(returning: Array(labels))
                }
                
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }.value
    }
    
    /// Determines the best category match
    static func suggestCategory(from labels: [String]) -> String {
        var scores: [String: Int] = [:]
        
        for label in labels {
            let lowerLabel = label.lowercased()
            
            for (category, keywords) in categoryRules {
                if keywords.contains(where: { lowerLabel.contains($0) }) {
                    scores[category, default: 0] += 1
                }
            }
        }
        
        if let bestMatch = scores.max(by: { $0.value < $1.value }), bestMatch.value > 0 {
            return bestMatch.key
        }
        
        return "Other"
    }
    
    /// ✨ UPDATED: Checks safety with context exceptions
    static func isSafeContent(labels: [String]) -> Bool {
        // Create a single string for easier context checking
        let combinedLabels = labels.joined(separator: " ").lowercased()
        
        for label in labels {
            let lowerLabel = label.lowercased()
            
            for blockedTerm in unsafeKeywords {
                // If we find a blocked term...
                if lowerLabel.contains(blockedTerm) {
                    
                    // ...Check if it's in our Safe Exceptions list
                    if let exceptions = safeExceptions[blockedTerm] {
                        // If the combined context contains a "saving word" (e.g. "kitchen"), it's safe.
                        let isSavedByException = exceptions.contains { exception in
                            return combinedLabels.contains(exception)
                        }
                        
                        if isSavedByException {
                            print("✅ SAFETY PASS: '\(blockedTerm)' allowed due to context in: \(labels)")
                            continue // Skip blocking this specific term
                        }
                    }
                    
                    print("⚠️ SAFETY BLOCK: Image flagged for term '\(blockedTerm)' in label '\(label)'")
                    return false
                }
            }
        }
        return true
    }
}
