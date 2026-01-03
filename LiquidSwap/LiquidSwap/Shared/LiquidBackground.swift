import SwiftUI

struct LiquidBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Orb 1
            Circle()
                .fill(Color.cyan.opacity(0.4))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: animate ? -100 : 100, y: animate ? -100 : 50)
            
            // Orb 2
            Circle()
                .fill(Color.blue.opacity(0.4))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: animate ? 100 : -100, y: animate ? 100 : -50)
            
            // Orb 3
            Circle()
                .fill(Color.purple.opacity(0.3))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(y: animate ? 150 : -150)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
        .ignoresSafeArea()
    }
}
