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
                        MainTabView()
                            .environmentObject(authVM)
                    } else {
                        AuthView()
                            .environmentObject(authVM)
                    }
                }
                // Fade in the app content
                .transition(.opacity)
            }
            
            // 2. Splash Screen Overlay
            if showSplash {
                SplashScreen(showSplash: $showSplash)
                    .zIndex(1) // Ensure it sits on top
            }
        }
        .onAppear {
            // Optional: You can trigger silent sign-in checks here
        }
    }
}

#Preview {
    ContentView()
}
