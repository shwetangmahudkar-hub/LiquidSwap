import SwiftUI
import Combine

class TabBarManager: ObservableObject {
    static let shared = TabBarManager()
    
    @Published var isVisible: Bool
    
    private init() {
        // ✅ Initialize property explicitly here to stop the error
        self.isVisible = true
    }
    
    func show() {
        withAnimation(.spring()) {
            isVisible = true
        }
    }
    
    func hide() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
    }
}
