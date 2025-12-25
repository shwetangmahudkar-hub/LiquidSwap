import SwiftUI

struct LiquidBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Deep Space / Ocean Base
            Color.black.ignoresSafeArea()
            
            // Orb 1 (Cyan)
            Circle()
                .fill(Color.cyan.opacity(0.4))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: animate ? -100 : 100, y: animate ? -100 : 100)
                .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: animate)
            
            // Orb 2 (Purple)
            Circle()
                .fill(Color.purple.opacity(0.4))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: animate ? 100 : -100, y: animate ? 100 : -100)
                .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: animate)
        }
        .ignoresSafeArea()
        .onAppear { animate.toggle() }
    }
}
