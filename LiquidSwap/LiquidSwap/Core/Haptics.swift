//
//  Haptics.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-22.
//


import UIKit

class Haptics {
    static let shared = Haptics()
    
    private init() {}
    
    // Light vibration (e.g., when snapping a card)
    func playLight() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    // Medium vibration (e.g., tapping a button)
    func playMedium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    // Success vibration (e.g., It's a Match!)
    func playSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // Error vibration (e.g., AI detects weapon)
    func playError() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}