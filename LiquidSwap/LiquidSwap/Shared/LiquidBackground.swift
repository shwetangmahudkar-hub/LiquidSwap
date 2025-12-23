import SwiftUI

struct LiquidBackground: View {
    // Independent Animation States for "Chaos"
    @State private var animate1 = false
    @State private var animate2 = false
    @State private var animate3 = false
    
    var body: some View {
        ZStack {
            // Base: Deep Void Black
            Color.black.ignoresSafeArea()
            
            // Blob 1: The Cyan Core (Moves slowly)
            Circle()
                .fill(Color.cyan.opacity(0.5))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: animate1 ? -100 : 100, y: animate1 ? -50 : 100)
                .scaleEffect(animate1 ? 1.1 : 0.9)
                .onAppear {
                    withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                        animate1.toggle()
                    }
                }
            
            // Blob 2: The Purple Depth (Moves moderately)
            Circle()
                .fill(Color.purple.opacity(0.5))
                .frame(width: 350, height: 350)
                .blur(radius: 70)
                .offset(x: animate2 ? 100 : -100, y: animate2 ? 100 : -100)
                .scaleEffect(animate2 ? 0.8 : 1.2)
                .onAppear {
                    withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                        animate2.toggle()
                    }
                }
            
            // Blob 3: The Blue Foundation (Moves quickly)
            Circle()
                .fill(Color.blue.opacity(0.4))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: animate3 ? -50 : 50, y: animate3 ? 200 : -200)
                .onAppear {
                    withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                        animate3.toggle()
                    }
                }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    LiquidBackground()
}
