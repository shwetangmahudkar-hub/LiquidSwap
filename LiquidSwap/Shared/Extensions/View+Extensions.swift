import SwiftUI

// MARK: - DESIGN SYSTEM

extension View {
    
    // 1. Standard App Font (Rounded Design)
    // Usage: .appFont(20, weight: .bold)
    func appFont(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.font(.system(size: size, weight: weight, design: .rounded))
    }
    
    // 2. Custom Placeholder Logic (Preserved)
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - BUTTON STYLES

// Usage: .buttonStyle(PrimaryButtonStyle())
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .cyan
    var textColor: Color = .black
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(16, weight: .bold)
            .foregroundStyle(textColor)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(color)
            .clipShape(Capsule())
            .shadow(color: color.opacity(0.4), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Usage: .buttonStyle(GlassButtonStyle())
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(16, weight: .bold)
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 5, y: 5)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Usage: .buttonStyle(DangerButtonStyle())
struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(16, weight: .bold)
            .foregroundStyle(.red)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.1))
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
