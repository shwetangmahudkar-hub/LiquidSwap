//
//  ProgressionView.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2026-01-02.
//


import SwiftUI

struct ProgressionView: View {
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var progressionManager = ProgressionManager.shared
    
    @State private var selectedSection: ProgressionSection = .overview
    @State private var showAchievementDetail: AchievementType?
    @State private var appearAnimation = false
    
    enum ProgressionSection: String, CaseIterable {
        case overview = "Overview"
        case achievements = "Badges"
        case impact = "Impact"
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            LiquidBackground()
                .opacity(0.5)
                .blur(radius: 30)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Section Picker
                    sectionPicker
                    
                    // Content based on selection
                    switch selectedSection {
                    case .overview:
                        overviewSection
                    case .achievements:
                        achievementsSection
                    case .impact:
                        impactSection
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.top, 20)
            }
            
            // Achievement Celebration Overlay
            if let newAchievement = progressionManager.newlyUnlockedAchievement {
                AchievementCelebrationOverlay(type: newAchievement) {
                    progressionManager.dismissCelebration()
                }
            }
        }
        .navigationTitle("Progression")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appearAnimation = true
            }
            Task {
                await progressionManager.loadAchievements()
            }
        }
        .sheet(item: $showAchievementDetail) { type in
            AchievementDetailSheet(type: type, isUnlocked: progressionManager.isUnlocked(type), progress: progressionManager.progress(for: type))
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Level Ring with Avatar
            ZStack {
                // Outer glow
                Circle()
                    .fill(userManager.currentLevel.color.opacity(0.2))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)
                
                // Progress ring background
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 6)
                    .frame(width: 120, height: 120)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: appearAnimation ? userManager.levelProgress : 0)
                    .stroke(
                        AngularGradient(
                            colors: [userManager.currentLevel.color, userManager.currentLevel.color.opacity(0.5), userManager.currentLevel.color],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 120, height: 120)
                    .animation(.easeOut(duration: 1.0), value: appearAnimation)
                
                // Avatar
                if let avatarUrl = userManager.currentUser?.avatarUrl {
                    AsyncImageView(filename: avatarUrl)
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.5))
                        )
                }
                
                // Level badge
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(userManager.currentLevel.color)
                                .frame(width: 36, height: 36)
                                .shadow(color: userManager.currentLevel.color.opacity(0.5), radius: 8)
                            
                            Image(systemName: userManager.currentLevel.icon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .offset(x: -5, y: -5)
                    }
                }
                .frame(width: 120, height: 120)
            }
            
            // Level Info
            VStack(spacing: 6) {
                Text(userManager.currentLevelTitle)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("Level \(userManager.currentLevel.tier)")
                    .font(.subheadline)
                    .foregroundStyle(userManager.currentLevel.color)
                
                // Next level progress
                if let nextLevel = userManager.nextLevel {
                    HStack(spacing: 4) {
                        Text("\(userManager.tradesToNextLevel) trades to")
                            .foregroundStyle(.white.opacity(0.5))
                        Text(nextLevel.title)
                            .foregroundStyle(nextLevel.color)
                    }
                    .font(.caption)
                } else {
                    Text("Max Level Reached! 🏆")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }
            
            // Quick Stats Row
            HStack(spacing: 20) {
                QuickStatBubble(value: "\(userManager.completedTradeCount)", label: "Trades", color: .cyan)
                QuickStatBubble(value: "\(progressionManager.unlockedCount)", label: "Badges", color: .purple)
                QuickStatBubble(value: userManager.streakStatus, label: "Streak", color: .orange, isSmallText: true)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Section Picker
    
    private var sectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(ProgressionSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedSection = section
                    }
                } label: {
                    Text(section.rawValue)
                        .font(.subheadline.bold())
                        .foregroundStyle(selectedSection == section ? .white : .white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedSection == section ?
                            Color.white.opacity(0.1) : Color.clear
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.05))
        .clipShape(Capsule())
        .padding(.horizontal, 24)
    }
    
    // MARK: - Overview Section
    
    private var overviewSection: some View {
        VStack(spacing: 20) {
            // Trust Score Card
            trustScoreCard
            
            // Level Perks
            levelPerksCard
            
            // Recent Achievements
            if !progressionManager.unlockedAchievements.isEmpty {
                recentAchievementsCard
            }
            
            // Next Achievement
            if let next = progressionManager.nextAchievementToUnlock {
                nextAchievementCard(type: next)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var trustScoreCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TRUST SCORE")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.5))
                    
                    HStack(alignment: .bottom, spacing: 8) {
                        Text("\(userManager.trustScore)")
                            .font(.system(size: 48, weight: .heavy))
                            .foregroundStyle(.white)
                        
                        Text("pts")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.bottom, 8)
                    }
                }
                
                Spacer()
                
                // Trust Tier Badge
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(userManager.trustTier.color.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: userManager.trustTier.icon)
                            .font(.title)
                            .foregroundStyle(userManager.trustTier.color)
                    }
                    
                    Text(userManager.trustTier.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(userManager.trustTier.color)
                }
            }
            
            // Score Breakdown
            VStack(spacing: 8) {
                ScoreBreakdownRow(label: "Trades", value: userManager.completedTradeCount * 2, icon: "arrow.triangle.2.circlepath")
                ScoreBreakdownRow(label: "Rating", value: Int(userManager.userRating * 10), icon: "star.fill")
                ScoreBreakdownRow(label: "Reviews", value: userManager.userReviewCount, icon: "text.bubble.fill")
                if userManager.currentUser?.isVerified == true {
                    ScoreBreakdownRow(label: "Verified", value: 20, icon: "checkmark.seal.fill")
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(userManager.trustTier.color.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var levelPerksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LEVEL PERKS")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.5))
            
            ForEach(userManager.currentLevel.perks, id: \.self) { perk in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    
                    Text(perk)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                    
                    Spacer()
                }
            }
            
            // Show next level perks preview
            if let nextLevel = userManager.nextLevel {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                Text("UNLOCK AT \(nextLevel.title.uppercased())")
                    .font(.caption.bold())
                    .foregroundStyle(nextLevel.color.opacity(0.7))
                
                ForEach(nextLevel.perks.prefix(2), id: \.self) { perk in
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.white.opacity(0.3))
                        
                        Text(perk)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.4))
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var recentAchievementsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RECENT BADGES")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.5))
                
                Spacer()
                
                Text("\(progressionManager.completionText)")
                    .font(.caption.bold())
                    .foregroundStyle(.cyan)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(progressionManager.sortedUnlockedAchievements.prefix(5)) { achievement in
                        Button {
                            showAchievementDetail = achievement.type
                        } label: {
                            AchievementBadgeView(type: achievement.type, isUnlocked: true)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func nextAchievementCard(type: AchievementType) -> some View {
        let progress = progressionManager.progress(for: type)
        
        return Button {
            showAchievementDetail = type
        } label: {
            HStack(spacing: 16) {
                // Badge Icon
                ZStack {
                    Circle()
                        .fill(type.color.opacity(0.2))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: type.icon)
                        .font(.title2)
                        .foregroundStyle(type.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEXT BADGE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Text(type.title)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                    
                    // Progress Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 6)
                            
                            Capsule()
                                .fill(type.gradient)
                                .frame(width: geo.size.width * (progress?.progress ?? 0), height: 6)
                        }
                    }
                    .frame(height: 6)
                    
                    Text(progress?.progressText ?? "")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(type.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Achievements Section
    
    private var achievementsSection: some View {
        VStack(spacing: 16) {
            // Progress Summary
            HStack {
                VStack(alignment: .leading) {
                    Text("\(progressionManager.unlockedCount)/\(progressionManager.totalCount)")
                        .font(.system(size: 32, weight: .heavy))
                        .foregroundStyle(.white)
                    
                    Text("Achievements Unlocked")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Spacer()
                
                // Circular Progress
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 8)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: progressionManager.completionPercentage)
                        .stroke(
                            LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 60, height: 60)
                    
                    Text("\(Int(progressionManager.completionPercentage * 100))%")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 20)
            
            // Achievement Grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 16) {
                ForEach(AchievementType.allCases.sorted { $0.sortOrder < $1.sortOrder }, id: \.self) { type in
                    Button {
                        showAchievementDetail = type
                    } label: {
                        AchievementGridCell(
                            type: type,
                            isUnlocked: progressionManager.isUnlocked(type),
                            progress: progressionManager.progress(for: type)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Impact Section
    
    private var impactSection: some View {
        VStack(spacing: 20) {
            // Hero Impact Card
            VStack(spacing: 20) {
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                    .shadow(color: .green.opacity(0.5), radius: 20)
                
                VStack(spacing: 4) {
                    Text(userManager.carbonSavedFormatted)
                        .font(.system(size: 48, weight: .heavy))
                        .foregroundStyle(.white)
                    
                    Text("CO₂ Prevented")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Text("By trading instead of buying new, you're helping reduce waste and carbon emissions!")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            
            // Impact Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ImpactStatCard(
                    icon: "arrow.3.trianglepath",
                    value: "\(userManager.itemsSavedFromLandfill)",
                    label: "Items Saved from Landfill",
                    color: .cyan
                )
                
                ImpactStatCard(
                    icon: "dollarsign.circle.fill",
                    value: userManager.moneySavedFormatted,
                    label: "Estimated Savings",
                    color: .yellow
                )
                
                ImpactStatCard(
                    icon: "person.2.fill",
                    value: "\(userManager.completedTradeCount)",
                    label: "Community Trades",
                    color: .purple
                )
                
                ImpactStatCard(
                    icon: "heart.fill",
                    value: "\(userManager.reviewsGivenCount)",
                    label: "Reviews Given",
                    color: .pink
                )
            }
            .padding(.horizontal, 20)
            
            // Streak Card
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Streak")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        
                        Text("\(userManager.currentStreak) days")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Best Streak")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        
                        Text("\(userManager.longestStreak) days")
                            .font(.title3.bold())
                            .foregroundStyle(.orange)
                    }
                }
                
                // Streak visualization (last 7 days placeholder)
                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { day in
                        Circle()
                            .fill(day < userManager.currentStreak ? Color.orange : Color.white.opacity(0.1))
                            .frame(width: 32, height: 32)
                            .overlay(
                                day < userManager.currentStreak ?
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white) : nil
                            )
                    }
                }
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Supporting Views

struct QuickStatBubble: View {
    let value: String
    let label: String
    let color: Color
    var isSmallText: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(isSmallText ? .caption.bold() : .title3.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(width: 80)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ScoreBreakdownRow: View {
    let label: String
    let value: Int
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 20)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            
            Spacer()
            
            Text("+\(value)")
                .font(.caption.bold())
                .foregroundStyle(.cyan)
        }
    }
}

struct AchievementGridCell: View {
    let type: AchievementType
    let isUnlocked: Bool
    let progress: AchievementProgress?
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if isUnlocked {
                    Circle()
                        .fill(type.gradient)
                        .frame(width: 50, height: 50)
                        .shadow(color: type.color.opacity(type.rarity.glowOpacity), radius: 10)
                    
                    Image(systemName: type.icon)
                        .font(.title2)
                        .foregroundStyle(.white)
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .trim(from: 0, to: progress?.progress ?? 0)
                                .stroke(type.color.opacity(0.5), lineWidth: 3)
                                .rotationEffect(.degrees(-90))
                        )
                    
                    Image(systemName: type.icon)
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            
            Text(type.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isUnlocked ? .white : .white.opacity(0.4))
                .lineLimit(1)
            
            if !isUnlocked, let prog = progress {
                Text(prog.progressText)
                    .font(.system(size: 9))
                    .foregroundStyle(type.color.opacity(0.7))
            }
        }
        .frame(width: 80)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isUnlocked ? type.color.opacity(0.1) : Color.white.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isUnlocked ? type.color.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

struct ImpactStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Achievement Detail Sheet

struct AchievementDetailSheet: View {
    let type: AchievementType
    let isUnlocked: Bool
    let progress: AchievementProgress?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Badge
                ZStack {
                    if isUnlocked {
                        Circle()
                            .fill(type.gradient)
                            .frame(width: 100, height: 100)
                            .shadow(color: type.color.opacity(0.5), radius: 20)
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Circle()
                                    .stroke(type.color.opacity(0.3), lineWidth: 2)
                            )
                    }
                    
                    Image(systemName: type.icon)
                        .font(.system(size: 44))
                        .foregroundStyle(isUnlocked ? .white : .white.opacity(0.3))
                }
                
                // Info
                VStack(spacing: 8) {
                    Text(type.title)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    
                    Text(type.rarity.label)
                        .font(.caption.bold())
                        .foregroundStyle(type.rarity.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(type.rarity.color.opacity(0.2))
                        .clipShape(Capsule())
                    
                    Text(type.description)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                }
                
                // Progress
                if !isUnlocked, let prog = progress {
                    VStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 12)
                                
                                Capsule()
                                    .fill(type.gradient)
                                    .frame(width: geo.size.width * prog.progress, height: 12)
                            }
                        }
                        .frame(height: 12)
                        .padding(.horizontal, 40)
                        
                        Text(prog.progressText)
                            .font(.headline)
                            .foregroundStyle(type.color)
                    }
                } else if isUnlocked {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Unlocked!")
                            .foregroundStyle(.green)
                    }
                    .font(.headline)
                }
                
                Spacer()
            }
            .padding(.top, 40)
        }
    }
}

// MARK: - Achievement Celebration Overlay

struct AchievementCelebrationOverlay: View {
    let type: AchievementType
    let onDismiss: () -> Void
    
    @State private var showContent = false
    @State private var showConfetti = false
    
    var body: some View {
        ZStack {
            // Dimmed Background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            // Content
            VStack(spacing: 24) {
                Spacer()
                
                // Badge with glow
                ZStack {
                    Circle()
                        .fill(type.gradient)
                        .frame(width: 120, height: 120)
                        .blur(radius: showContent ? 30 : 0)
                        .opacity(showContent ? 0.5 : 0)
                    
                    Circle()
                        .fill(type.gradient)
                        .frame(width: 100, height: 100)
                        .scaleEffect(showContent ? 1 : 0.5)
                        .opacity(showContent ? 1 : 0)
                    
                    Image(systemName: type.icon)
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                        .scaleEffect(showContent ? 1 : 0)
                }
                
                VStack(spacing: 8) {
                    Text("🎉 Achievement Unlocked!")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Text(type.title)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    
                    Text(type.description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Text("Awesome!")
                        .font(.headline.bold())
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(type.gradient)
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

// MARK: - AchievementType Extension for Sheet

extension AchievementType: Identifiable {
    public var id: String { rawValue }
}