//
//  ImageAnalyzer.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-22.
//


import Vision
import UIKit

struct ImageAnalyzer {
    
    // Errors that can occur during analysis
    enum AnalysisError: Error {
        case invalidImage
        case processingFailed
    }
    
    /// Analyzes an image and returns a list of detected labels (e.g., "Computer", "Plant")
    static func analyze(image: UIImage) async throws -> [String] {
        // 1. Convert UIImage to CIImage (required for Vision)
        guard let ciImage = CIImage(image: image) else {
            throw AnalysisError.invalidImage
        }
        
        // 2. Create the Request handler
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        // 3. Create the Request (We use Apple's built-in taxonomy)
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                // 4. Extract Observations
                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                // 5. Filter for high confidence (> 50%)
                let labels = observations
                    .filter { $0.confidence > 0.5 }
                    .map { $0.identifier } // e.g., "electronics", "plant"
                
                continuation.resume(returning: labels)
            }
            
            // 6. Run the request
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Checks if the image contains prohibited content based on keywords
    static func validateSafety(labels: [String]) -> Bool {
        let prohibitedTerms = ["weapon", "firearm", "gun", "knife", "drug", "nudity", "gore"]
        
        for label in labels {
            // Check if any label contains a prohibited term (case insensitive)
            for term in prohibitedTerms {
                if label.lowercased().contains(term) {
                    print("⚠️ SAFETY ALERT: Detected potential \(term)")
                    return false // UNSAFE
                }
            }
        }
        return true // SAFE
    }
    
    /// Suggests a category based on labels
    static func suggestCategory(from labels: [String]) -> String? {
        // Map Vision labels to our App Categories
        // Our Categories: ["Electronics", "Fashion", "Home", "Plants", "Books", "Services"]
        
        for label in labels {
            let lower = label.lowercased()
            if lower.contains("computer") || lower.contains("phone") || lower.contains("monitor") { return "Electronics" }
            if lower.contains("clothing") || lower.contains("apparel") || lower.contains("shirt") { return "Fashion" }
            if lower.contains("flower") || lower.contains("plant") || lower.contains("tree") { return "Plants" }
            if lower.contains("furniture") || lower.contains("chair") || lower.contains("table") { return "Home" }
            if lower.contains("book") || lower.contains("paper") { return "Books" }
        }
        return nil
    }
}