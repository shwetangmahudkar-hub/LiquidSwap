//
//  GlassCard.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-22.
//


import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content
    
    // We use a closure so we can pass any child view into this card
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .padding(24) // Internal spacing
                // The "Frosted Effect" using native UltraThinMaterial [cite: 76]
                .background(.ultraThinMaterial) 
                .environment(\.colorScheme, .dark) // Forces text white for contrast
                .cornerRadius(24)
                .overlay(
                    // The "Edge Light" Border [cite: 88-91]
                    // A subtle gradient border mimics light hitting glass edges
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.5), // Top-left light source
                                    .white.opacity(0.1)  // Bottom-right shadow
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                // Shadow provides depth hierarchy [cite: 71]
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 10)
        }
    }
}

#Preview {
    ZStack {
        LiquidBackground()
        GlassCard {
            Text("Glass Preview")
                .font(.largeTitle)
                .bold()
        }
    }
}