import SwiftUI

struct ContentView: View {
    @State private var showSplash = true
    
    var body: some View {
        if showSplash {
            SplashScreen(showSplash: $showSplash)
        } else {
            FeedView()
        }
    }
}

#Preview {
    ContentView()
}
