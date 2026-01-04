//
//  GlassCard.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-22.
//

import SwiftUI

struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content
    
    // We use a closure so we can pass any child view into this card
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    // MARK: - Adaptive Colors
    private var borderHighlight: Color {
        colorScheme == .dark
            ? .white.opacity(0.5)
            : .white.opacity(0.8)
    }
    
    private var borderShadow: Color {
        colorScheme == .dark
            ? .white.opacity(0.1)
            : .black.opacity(0.1)
    }
    
    private var cardShadow: Color {
        colorScheme == .dark
            ? .black.opacity(0.2)
            : .black.opacity(0.1)
    }

    var body: some View {
        ZStack {
            content
                .padding(24) // Internal spacing
                // The "Frosted Effect" using native UltraThinMaterial
                .background(.ultraThinMaterial)
                // ✅ REMOVED: .environment(\.colorScheme, .dark) — now respects system setting
                .cornerRadius(24)
                .overlay(
                    // The "Edge Light" Border
                    // A subtle gradient border mimics light hitting glass edges
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    borderHighlight, // Top-left light source
                                    borderShadow     // Bottom-right shadow
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                // Shadow provides depth hierarchy
                .shadow(color: cardShadow, radius: 10, x: 0, y: 10)
        }
    }
}

#Preview("Dark Mode") {
    ZStack {
        LiquidBackground()
        GlassCard {
            Text("Glass Preview")
                .font(.largeTitle)
                .bold()
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    ZStack {
        LiquidBackground()
        GlassCard {
            Text("Glass Preview")
                .font(.largeTitle)
                .bold()
        }
    }
    .preferredColorScheme(.light)
}
