import SwiftUI

struct PremiumUpgradeSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userManager = UserManager.shared
    
    @State private var isProcessing = false
    @State private var animateIcon = false // Replacement for symbolEffect
    
    var body: some View {
        ZStack {
            // 1. Global Background
            LiquidBackground()
            
            VStack(spacing: 0) {
                // 2. Header / Close Button
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(20)
                
                ScrollView {
                    VStack(spacing: 32) {
                        
                        // 3. Hero Section
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(colors: [.yellow.opacity(0.2), .orange.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Circle().stroke(
                                            LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom),
                                            lineWidth: 2
                                        )
                                    )
                                    .shadow(color: .orange.opacity(0.5), radius: 20)
                                
                                Image(systemName: "sparkles")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.yellow)
                                    // ✨ FIX: Standard animation for iOS 16
                                    .scaleEffect(animateIcon ? 1.1 : 1.0)
                                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: animateIcon)
                            }
                            
                            VStack(spacing: 8) {
                                Text("EARLY ACCESS")
                                    .font(.caption.bold())
                                    .foregroundStyle(.yellow)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.yellow.opacity(0.1))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.yellow.opacity(0.3), lineWidth: 1))
                                
                                Text("Unlock the Future")
                                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                
                                Text("Support the development of LiquidSwap and get exclusive access to powerful tools.")
                                    .font(.body)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                        }
                        
                        // 4. Feature List
                        VStack(spacing: 16) {
                            FeatureRow(
                                icon: "wand.and.stars",
                                color: .purple,
                                title: "AI Listing Assistant",
                                description: "Auto-fill titles, descriptions, and categories from just a photo."
                            )
                            
                            FeatureRow(
                                icon: "infinity",
                                color: .cyan,
                                title: "Unlimited Inventory",
                                description: "Remove the 20-item limit and list as much as you want."
                            )
                            
                            FeatureRow(
                                icon: "crown.fill",
                                color: .yellow,
                                title: "Supporter Badge",
                                description: "Stand out in the feed with a special profile badge."
                            )
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .cornerRadius(24)
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
                
                // 5. Bottom Action Button
                VStack {
                    Button(action: performUpgrade) {
                        ZStack {
                            if isProcessing {
                                ProgressView().tint(.black)
                            } else {
                                HStack {
                                    Text("Join Early Access")
                                        .font(.headline.bold())
                                    Image(systemName: "arrow.right")
                                        .font(.headline.bold())
                                }
                            }
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(Capsule())
                        .shadow(color: .orange.opacity(0.5), radius: 15, y: 5)
                    }
                    .disabled(isProcessing)
                    
                    Text("Cancel anytime. No commitment.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.top, 12)
                }
                .padding(24)
                .background(
                    LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 120)
                )
            }
        }
        .onAppear {
            animateIcon = true
        }
    }
    
    // MARK: - Actions
    
    func performUpgrade() {
        isProcessing = true
        Haptics.shared.playMedium()
        
        Task {
            // Simulate Network Call / Payment Processing
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            await userManager.upgradeToPremium()
            
            await MainActor.run {
                isProcessing = false
                Haptics.shared.playSuccess()
                dismiss()
            }
        }
    }
}

// MARK: - Subviews

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
