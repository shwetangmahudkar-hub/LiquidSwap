import SwiftUI

struct SplashScreen: View {
    // Binding to tell the parent "I am done"
    @Binding var showSplash: Bool
    
    @State private var size = 0.8
    @State private var opacity = 0.5
    
    var body: some View {
        ZStack {
            LiquidBackground()
            
            VStack(spacing: 20) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.cyan)
                    .shadow(color: .cyan.opacity(0.5), radius: 20, x: 0, y: 0)
                
                Text("Swappr")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                    .opacity(0.8)
            }
            .scaleEffect(size)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: 1.2)) {
                    self.size = 1.0
                    self.opacity = 1.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        self.showSplash = false
                    }
                }
            }
        }
    }
}
