import SwiftUI

struct ContentView: View {
    @StateObject var authVM = AuthViewModel()
    @State private var showSplash = true // Control splash state
    
    var body: some View {
        ZStack {
            // 1. Main App Content (Hidden until splash is done)
            if !showSplash {
                Group {
                    if authVM.isAuthenticated {
                        // ✨ FIXED: Check onboarding state from AuthViewModel source of truth
                        if authVM.isOnboarding {
                            OnboardingView(authVM: authVM)
                                // ✨ UX: Slide-up function for modern iOS feel
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .zIndex(2)
                        } else {
                            MainTabView()
                                .environmentObject(authVM)
                                .transition(.opacity)
                        }
                    } else {
                        AuthView()
                            .environmentObject(authVM)
                    }
                }
                // Global animations for state changes
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: authVM.isAuthenticated)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: authVM.isOnboarding)
            }
            
            // 2. Splash Screen Overlay
            if showSplash {
                SplashScreen(showSplash: $showSplash)
                    .zIndex(3) // Highest priority
            }
        }
        .onAppear {
            // iOS 16.6 compatible initializations
        }
    }
}

#Preview {
    ContentView()
}
