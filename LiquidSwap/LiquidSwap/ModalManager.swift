import SwiftUI
import Combine

// 1. Define the screens that can appear as glass overlays
enum AppModal: Identifiable, Equatable {
    case settings
    case editProfile
    case activityHub
    case addItem
    // Add other global screens here as needed

    var id: Self { self }
}

// 2. The manager class controls the state of presentation
// ✅ FIX: Added ': ObservableObject' protocol conformance
class ModalManager: ObservableObject {
    @Published var activeModal: AppModal? = nil
    // isPresenting is separate to allow for smoother exit animations
    @Published var isPresenting: Bool = false

    // Call this to slide a new glass screen up
    func show(_ modal: AppModal) {
        // Ensure any previous modal is cleared first
        activeModal = modal
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isPresenting = true
        }
    }

    // Call this to slide it down
    func dismiss() {
        withAnimation(.spring(response: 0.4, dampingFraction: 1.0)) {
            isPresenting = false
        }
        
        // Delay clearing the view type until the slide-down animation finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.activeModal = nil
        }
    }
}
