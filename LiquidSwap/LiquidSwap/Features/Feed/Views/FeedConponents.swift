//
//  XPToast.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2026-01-02.
//


import SwiftUI

// MARK: - ✨ Gamification Models & Views

struct XPToast: Identifiable {
    let id = UUID()
    let amount: Int
    let reason: String
    let position: CGPoint = CGPoint(
        x: CGFloat.random(in: 100...300),
        y: CGFloat.random(in: 300...500)
    )
}

struct XPToastView: View {
    let toast: XPToast
    @State private var offset: CGFloat = 20
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.8
    
    var body: some View {
        HStack(spacing: 8) {
            Text("+\(toast.amount)")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, .white],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .cyan.opacity(0.5), radius: 5)
            
            Text(toast.reason.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .cornerRadius(4)
        }
        .position(toast.position)
        .offset(y: offset)
        .opacity(opacity)
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                offset = -60
                opacity = 1
                scale = 1.2
            }
            
            withAnimation(.easeIn(duration: 0.3).delay(0.8)) {
                opacity = 0
                scale = 0.5
                offset = -100
            }
        }
    }
}

// MARK: - Confetti System

struct ConfettiCannon: View {
    let count: Int
    @State private var particles: [ConfettiParticle] = []
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                }
            }
            .onAppear {
                createParticles(in: geo.size)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    func createParticles(in size: CGSize) {
        for _ in 0..<count {
            let particle = ConfettiParticle(
                position: CGPoint(x: size.width / 2, y: size.height + 50), // Start from bottom center
                color: [.cyan, .pink, .yellow, .purple, .white].randomElement()!,
                size: CGFloat.random(in: 5...12)
            )
            particles.append(particle)
        }
        
        // Animate
        for i in particles.indices {
            withAnimation(.spring(response: 2.0, dampingFraction: 0.7).delay(Double.random(in: 0...0.2))) {
                particles[i].position = CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height/2)
                )
                particles[i].opacity = 0
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    let color: Color
    let size: CGFloat
    var opacity: Double = 1.0
}

struct ComboIndicator: View {
    let count: Int
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(.yellow)
            
            Text("\(count)x")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            
            Text("COMBO")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.yellow)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
                .overlay(
                    Capsule()
                        .stroke(Color.yellow.opacity(0.5), lineWidth: 2)
                )
        )
        .shadow(color: .yellow.opacity(0.3), radius: 10)
    }
}

// MARK: - Feed UI Components

struct AchievementHintBanner: View {
    let type: AchievementType
    let progress: AchievementProgress?
    
    var body: some View {
        HStack(spacing: 12) {
            // Badge Icon
            ZStack {
                Circle()
                    .fill(type.color.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Image(systemName: type.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(type.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(type.title)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                
                if let prog = progress {
                    Text("\(prog.progressText) to unlock!")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            // Mini progress bar
            if let prog = progress {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 50, height: 4)
                    
                    Capsule()
                        .fill(type.color)
                        .frame(width: 50 * prog.progress, height: 4)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(type.color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct LevelUpCelebration: View {
    let level: UserLevel
    let onDismiss: () -> Void
    
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            VStack(spacing: 24) {
                Spacer()
                
                // Level badge with glow
                ZStack {
                    Circle()
                        .fill(level.color)
                        .frame(width: 140, height: 140)
                        .blur(radius: showContent ? 40 : 0)
                        .opacity(showContent ? 0.6 : 0)
                    
                    Circle()
                        .fill(level.color)
                        .frame(width: 100, height: 100)
                        .scaleEffect(showContent ? 1 : 0.5)
                        .opacity(showContent ? 1 : 0)
                    
                    Image(systemName: level.icon)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(showContent ? 1 : 0)
                }
                
                VStack(spacing: 8) {
                    Text("🎉 LEVEL UP!")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Text(level.title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    
                    Text("Level \(level.tier)")
                        .font(.title3)
                        .foregroundStyle(level.color)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                
                // New perks
                VStack(alignment: .leading, spacing: 8) {
                    Text("NEW PERKS UNLOCKED")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.5))
                    
                    ForEach(level.perks, id: \.self) { perk in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(perk)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
                .padding(20)
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
                .opacity(showContent ? 1 : 0)
                .padding(.horizontal, 40)
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Text("Continue")
                        .font(.headline.bold())
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(level.color)
                        .clipShape(Capsule())
                        .padding(.horizontal, 40)
                }
                .opacity(showContent ? 1 : 0)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showContent = true
            }
        }
    }
}

struct FeedBottomBar: View {
    let item: TradeItem
    let onQuickOffer: () -> Void
    
    // Gamification Logic
    var rankTitle: String {
        guard let count = item.ownerTradeCount else { return "Newcomer" }
        return UserLevel.forTradeCount(count).title
    }
    
    var rankColor: Color {
        guard let count = item.ownerTradeCount else { return .gray }
        return UserLevel.forTradeCount(count).color
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Top Row: Title + Quick Offer Button
            HStack(alignment: .center, spacing: 12) {
                // Item Info
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(item.title)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    // Category + Rank Row
                    HStack(spacing: 8) {
                        // Category Pill
                        Text(item.category.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(4)
                        
                        // Rank Pill
                        HStack(spacing: 3) {
                            Image(systemName: UserLevel.forTradeCount(item.ownerTradeCount ?? 0).icon)
                                .font(.system(size: 8))
                            Text(rankTitle.uppercased())
                                .font(.system(size: 9, weight: .black))
                        }
                        .foregroundStyle(rankColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(rankColor.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                // Quick Offer Button
                Button(action: onQuickOffer) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .bold))
                        Text("Offer")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.cyan)
                    .clipShape(Capsule())
                }
            }
            
            // Bottom Row: User + Distance
            HStack(spacing: 8) {
                // User Info
                HStack(spacing: 4) {
                    Text(item.ownerUsername ?? "User")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                    
                    if item.ownerIsVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(.cyan)
                    }
                }
                
                Text("•")
                    .foregroundStyle(.white.opacity(0.4))
                
                // Distance
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(.cyan)
                    Text("\(String(format: "%.1f", item.distance)) km")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 15, y: 8)
    }
}

struct FullScreenItemCard: View {
    let item: TradeItem
    
    var isPremium: Bool {
        return item.ownerIsPremium ?? false
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. Full Screen Image
                AsyncImageView(filename: item.imageUrl)
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.1), .black.opacity(0.6)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
                
                // 2. PREMIUM BORDER (Visible only for Premium Users)
                if isPremium {
                    RoundedRectangle(cornerRadius: 0)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.yellow.opacity(0.8), .orange.opacity(0.5), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 4
                        )
                        .ignoresSafeArea()
                }
            }
        }
        .ignoresSafeArea()
        .background(Color.black)
    }
}