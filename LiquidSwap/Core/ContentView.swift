import SwiftUI

struct ContentView: View {
    @StateObject var authVM = AuthViewModel()
    @State private var showSplash = true // Control splash state
    
    // ✨ NEW: Track onboarding state locally on device
    @AppStorage("isOnboarding") var isOnboarding: Bool = true
    
    var body: some View {
        ZStack {
            // 1. Main App Content (Hidden until splash is done)
            if !showSplash {
                Group {
                    if authVM.isAuthenticated {
                        // ✨ NEW: Check if user needs to finish onboarding profile
                        if isOnboarding {
                            OnboardingView()
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
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
                // Fade in the app content
                .animation(.default, value: authVM.isAuthenticated)
                .animation(.default, value: isOnboarding)
            }
            
            // 2. Splash Screen Overlay
            if showSplash {
                SplashScreen(showSplash: $showSplash)
                    .zIndex(1) // Ensure it sits on top
            }
        }
        .onAppear {
            // Optional: Trigger silent sign-in checks or data pre-loading here
        }
    }
}

#Preview {
    ContentView()
}
