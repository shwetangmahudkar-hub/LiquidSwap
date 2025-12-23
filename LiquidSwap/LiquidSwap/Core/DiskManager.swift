//
//  DiskManager.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-22.
//


import UIKit

struct DiskManager {
    static let shared = DiskManager()
    
    private let fileManager = FileManager.default
    
    // Get the path to our app's documents directory
    private var documentsDirectory: URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    // Save an image and return its filename
    func saveImage(_ image: UIImage, id: String) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.5), // Compress to 50%
              let dir = documentsDirectory else { return nil }
        
        let filename = "\(id).jpg"
        let fileURL = dir.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            print("DiskManager: Saved image to \(filename)")
            return filename
        } catch {
            print("DiskManager: Error saving image: \(error)")
            return nil
        }
    }
    
    // Load an image by filename
    func loadImage(filename: String) -> UIImage? {
        guard let dir = documentsDirectory else { return nil }
        let fileURL = dir.appendingPathComponent(filename)
        
        if fileManager.fileExists(atPath: fileURL.path) {
            return UIImage(contentsOfFile: fileURL.path)
        }
        return nil
    }
    
    // Delete an image
    func deleteImage(filename: String) {
        guard let dir = documentsDirectory else { return }
        let fileURL = dir.appendingPathComponent(filename)
        
        try? fileManager.removeItem(at: fileURL)
        print("DiskManager: Deleted image \(filename)")
    }
}