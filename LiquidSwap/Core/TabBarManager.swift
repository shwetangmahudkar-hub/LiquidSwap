import SwiftUI
import Combine

class TabBarManager: ObservableObject {
    static let shared = TabBarManager()
    
    @Published var isVisible: Bool
    
    private init() {
        // ✅ Initialize property explicitly here
        self.isVisible = true
    }
    
    func show() {
        // ✨ SLOWER ANIMATION: Increased response to 0.8 (was default ~0.55)
        // This makes the slide up feels heavier and slower.
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            isVisible = true
        }
    }
    
    func hide() {
        // ✨ MATCHING SLOWER ANIMATION
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            isVisible = false
        }
    }
}

