import SwiftUI

// MARK: - DESIGN SYSTEM CONSTANTS

/// Centralized design tokens for consistent UI across the app
struct DS {
    // MARK: - Spacing
    struct Spacing {
        /// Edge padding for screen content (12pt)
        static let edge: CGFloat = 12
        /// Top padding from safe area - minimal to maximize screen real estate (8pt)
        static let topInset: CGFloat = 8
        /// Space between sections (12pt)
        static let section: CGFloat = 12
        /// Space between cards/rows (10pt)
        static let card: CGFloat = 10
        /// Internal card padding (12pt)
        static let cardPadding: CGFloat = 12
        /// Bottom padding to clear tab bar (85pt)
        static let bottomTab: CGFloat = 85
    }
    
    // MARK: - Typography (consistent across app)
    struct Font {
        /// Large screen titles - "Trades", "Chats", etc. (24pt heavy)
        static let screenTitle: CGFloat = 24
        /// Section headers (14pt bold)
        static let sectionHeader: CGFloat = 14
        /// Card titles (15pt bold)
        static let cardTitle: CGFloat = 15
        /// Body text (14pt regular)
        static let body: CGFloat = 14
        /// Secondary/caption text (12pt)
        static let caption: CGFloat = 12
        /// Small labels (10pt)
        static let small: CGFloat = 10
        /// Tiny text (9pt)
        static let tiny: CGFloat = 9
    }
    
    // MARK: - Corner Radii
    struct Radius {
        /// Large cards and sheets (20pt)
        static let large: CGFloat = 20
        /// Medium cards (16pt)
        static let medium: CGFloat = 16
        /// Small elements like buttons (12pt)
        static let small: CGFloat = 12
        /// Tiny elements like pills (8pt)
        static let tiny: CGFloat = 8
    }
    
    // MARK: - Element Sizes
    struct Size {
        /// Standard icon button (36pt)
        static let iconButton: CGFloat = 36
        /// Avatar small (40pt)
        static let avatarSmall: CGFloat = 40
        /// Avatar medium (52pt)
        static let avatarMedium: CGFloat = 52
        /// Avatar large (72pt)
        static let avatarLarge: CGFloat = 72
        /// Action button height (48pt)
        static let buttonHeight: CGFloat = 48
    }
}

// MARK: - VIEW EXTENSIONS

extension View {
    
    // MARK: - Standard App Font
    /// Usage: .appFont(DS.Font.cardTitle, weight: .bold)
    func appFont(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.font(.system(size: size, weight: weight, design: .default))
    }
    
    // MARK: - Screen Title Style
    /// Consistent header styling across all main tabs
    func screenTitleStyle() -> some View {
        self
            .font(.system(size: DS.Font.screenTitle, weight: .bold, design: .default))
    }
    
    // MARK: - Full Screen Sheet Modifier
    /// Makes sheets slide up fully and blend with Dynamic Island
    /// Usage: .fullScreenSheet(isPresented: $showSheet) { MyView() }
    func fullScreenSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            content()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(38) // Matches Dynamic Island curve
        }
    }
    
    // MARK: - Full Screen Sheet with Item
    /// Makes sheets slide up fully for item-based presentation
    func fullScreenSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        self.sheet(item: item) { item in
            content(item)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(38)
        }
    }
    
    // MARK: - Custom Placeholder
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
    
    // MARK: - Glass Card Style
    /// Quick glass card background
    func glassCard(radius: CGFloat = DS.Radius.large) -> some View {
        self
            .padding(DS.Spacing.cardPadding)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - BUTTON STYLES

/// Primary CTA button (cyan background)
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .cyan
    var textColor: Color = .black
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(DS.Font.body, weight: .bold)
            .foregroundStyle(textColor)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(color)
            .clipShape(Capsule())
            .shadow(color: color.opacity(0.4), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Glass/secondary button
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(DS.Font.body, weight: .bold)
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(LinearGradient(
                        colors: [.white.opacity(0.4), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 4, y: 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Destructive/danger button
struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(DS.Font.body, weight: .bold)
            .foregroundStyle(.red)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.1))
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - ADAPTIVE COLORS HELPER

/// Helper for views that need adaptive colors
struct AdaptiveColors {
    let colorScheme: ColorScheme
    
    var primaryText: Color {
        colorScheme == .dark ? .white : .black
    }
    
    var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.55)
    }
    
    var tertiaryText: Color {
        colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.4)
    }
    
    var cardBackground: Color {
        colorScheme == .dark ? .white.opacity(0.05) : .black.opacity(0.03)
    }
    
    var buttonBackground: Color {
        colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.05)
    }
    
    var border: Color {
        colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.08)
    }
}
