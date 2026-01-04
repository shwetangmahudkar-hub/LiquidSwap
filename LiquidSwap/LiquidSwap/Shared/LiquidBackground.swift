import SwiftUI

struct LiquidBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var animate = false
    
    // MARK: - Adaptive Colors
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    private var orb1Color: Color {
        colorScheme == .dark
            ? Color.cyan.opacity(0.4)
            : Color.cyan.opacity(0.15)
    }
    
    private var orb2Color: Color {
        colorScheme == .dark
            ? Color.blue.opacity(0.4)
            : Color.blue.opacity(0.12)
    }
    
    private var orb3Color: Color {
        colorScheme == .dark
            ? Color.purple.opacity(0.3)
            : Color.purple.opacity(0.1)
    }
    
    private var orbBlur: CGFloat {
        colorScheme == .dark ? 60 : 80
    }
    
    var body: some View {
        ZStack {
            // Adaptive base background
            backgroundColor.ignoresSafeArea()
            
            // Orb 1
            Circle()
                .fill(orb1Color)
                .frame(width: 300, height: 300)
                .blur(radius: orbBlur)
                .offset(x: animate ? -100 : 100, y: animate ? -100 : 50)
            
            // Orb 2
            Circle()
                .fill(orb2Color)
                .frame(width: 300, height: 300)
                .blur(radius: orbBlur)
                .offset(x: animate ? 100 : -100, y: animate ? 100 : -50)
            
            // Orb 3
            Circle()
                .fill(orb3Color)
                .frame(width: 250, height: 250)
                .blur(radius: orbBlur - 10)
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

#Preview("Dark Mode") {
    LiquidBackground()
        .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    LiquidBackground()
        .preferredColorScheme(.light)
}
