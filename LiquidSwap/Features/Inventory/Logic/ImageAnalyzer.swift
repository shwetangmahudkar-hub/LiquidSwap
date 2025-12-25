//
//  ImageAnalyzer.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-22.
//

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
                    .filter { $0.confidence > 0.3 } // Lowered threshold slightly to catch more
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
        // App Categories: ["Electronics", "Fashion", "Home & Garden", "Sports", "Books", "Other"]
        
        for label in labels {
            let lower = label.lowercased()
            
            if lower.contains("computer") || lower.contains("phone") || lower.contains("monitor") || lower.contains("screen") || lower.contains("camera") { return "Electronics" }
            if lower.contains("clothing") || lower.contains("jersey") || lower.contains("shirt") || lower.contains("shoe") || lower.contains("dress") || lower.contains("coat") { return "Fashion" }
            if lower.contains("plant") || lower.contains("flower") || lower.contains("tree") || lower.contains("vase") || lower.contains("pot") || lower.contains("furniture") || lower.contains("chair") || lower.contains("sofa") { return "Home & Garden" }
            if lower.contains("ball") || lower.contains("racket") || lower.contains("sport") || lower.contains("bicycle") || lower.contains("helmet") { return "Sports" }
            if lower.contains("book") || lower.contains("paper") || lower.contains("novel") { return "Books" }
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
