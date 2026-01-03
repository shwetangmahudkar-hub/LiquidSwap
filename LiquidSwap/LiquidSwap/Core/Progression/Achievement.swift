//
//  AchievementType.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2026-01-02.
//


import Foundation
import SwiftUI

// MARK: - Achievement Type

enum AchievementType: String, CaseIterable, Codable {
    case firstSwap = "first_swap"
    case fiveStar = "five_star"
    case hotStreak = "hot_streak"
    case categoryKing = "category_king"
    case ecoWarrior = "eco_warrior"
    case collector = "collector"
    case communityStar = "community_star"
    case topRated = "top_rated"
    case streakMaster = "streak_master"
    case tradeVeteran = "trade_veteran"
    
    // MARK: - Display Properties
    
    var title: String {
        switch self {
        case .firstSwap: return "First Swap"
        case .fiveStar: return "Five Star"
        case .hotStreak: return "Hot Streak"
        case .categoryKing: return "Category King"
        case .ecoWarrior: return "Eco Warrior"
        case .collector: return "Collector"
        case .communityStar: return "Community Star"
        case .topRated: return "Top Rated"
        case .streakMaster: return "Streak Master"
        case .tradeVeteran: return "Trade Veteran"
        }
    }
    
    var description: String {
        switch self {
        case .firstSwap: return "Complete your first trade"
        case .fiveStar: return "Receive a 5-star review"
        case .hotStreak: return "Complete 3 trades in 7 days"
        case .categoryKing: return "Complete 10 trades in one category"
        case .ecoWarrior: return "Save 25 kg of CO₂"
        case .collector: return "List 10 or more items"
        case .communityStar: return "Write 10 reviews for others"
        case .topRated: return "Maintain 4.5+ rating with 5+ reviews"
        case .streakMaster: return "Reach a 7-day login streak"
        case .tradeVeteran: return "Complete 25 trades"
        }
    }
    
    var icon: String {
        switch self {
        case .firstSwap: return "arrow.triangle.2.circlepath"
        case .fiveStar: return "star.fill"
        case .hotStreak: return "flame.fill"
        case .categoryKing: return "crown.fill"
        case .ecoWarrior: return "leaf.fill"
        case .collector: return "square.grid.3x3.fill"
        case .communityStar: return "heart.text.square.fill"
        case .topRated: return "trophy.fill"
        case .streakMaster: return "bolt.fill"
        case .tradeVeteran: return "medal.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .firstSwap: return .green
        case .fiveStar: return .yellow
        case .hotStreak: return .orange
        case .categoryKing: return .purple
        case .ecoWarrior: return .mint
        case .collector: return .blue
        case .communityStar: return .pink
        case .topRated: return .yellow
        case .streakMaster: return .cyan
        case .tradeVeteran: return .indigo
        }
    }
    
    var gradient: LinearGradient {
        switch self {
        case .firstSwap:
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .fiveStar:
            return LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .hotStreak:
            return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .categoryKing:
            return LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .ecoWarrior:
            return LinearGradient(colors: [.mint, .green], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .collector:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .communityStar:
            return LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .topRated:
            return LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .streakMaster:
            return LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .tradeVeteran:
            return LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    /// Rarity affects visual presentation
    var rarity: AchievementRarity {
        switch self {
        case .firstSwap, .collector:
            return .common
        case .fiveStar, .ecoWarrior, .communityStar:
            return .uncommon
        case .hotStreak, .streakMaster, .topRated:
            return .rare
        case .categoryKing, .tradeVeteran:
            return .epic
        }
    }
    
    /// Sort order for display
    var sortOrder: Int {
        switch self {
        case .firstSwap: return 0
        case .collector: return 1
        case .fiveStar: return 2
        case .ecoWarrior: return 3
        case .communityStar: return 4
        case .hotStreak: return 5
        case .streakMaster: return 6
        case .topRated: return 7
        case .categoryKing: return 8
        case .tradeVeteran: return 9
        }
    }
}

// MARK: - Achievement Rarity

enum AchievementRarity: String, Codable {
    case common
    case uncommon
    case rare
    case epic
    
    var label: String {
        switch self {
        case .common: return "Common"
        case .uncommon: return "Uncommon"
        case .rare: return "Rare"
        case .epic: return "Epic"
        }
    }
    
    var color: Color {
        switch self {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        }
    }
    
    var glowOpacity: Double {
        switch self {
        case .common: return 0.0
        case .uncommon: return 0.2
        case .rare: return 0.4
        case .epic: return 0.6
        }
    }
}

// MARK: - Achievement Model (For Database Storage)

struct Achievement: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let type: AchievementType
    let unlockedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case unlockedAt = "unlocked_at"
    }
    
    init(id: UUID = UUID(), userId: UUID, type: AchievementType, unlockedAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.type = type
        self.unlockedAt = unlockedAt
    }
    
    static func == (lhs: Achievement, rhs: Achievement) -> Bool {
        return lhs.type == rhs.type && lhs.userId == rhs.userId
    }
}

// MARK: - Achievement Progress

struct AchievementProgress {
    let type: AchievementType
    let currentValue: Int
    let targetValue: Int
    let isUnlocked: Bool
    
    var progress: Double {
        if isUnlocked { return 1.0 }
        guard targetValue > 0 else { return 0 }
        return min(Double(currentValue) / Double(targetValue), 1.0)
    }
    
    var progressText: String {
        if isUnlocked {
            return "Unlocked!"
        }
        return "\(currentValue)/\(targetValue)"
    }
    
    /// Target values for each achievement
    static func targetValue(for type: AchievementType) -> Int {
        switch type {
        case .firstSwap: return 1
        case .fiveStar: return 1
        case .hotStreak: return 3
        case .categoryKing: return 10
        case .ecoWarrior: return 10  // 10 trades = 25 kg CO₂
        case .collector: return 10
        case .communityStar: return 10
        case .topRated: return 5     // 5 reviews needed
        case .streakMaster: return 7
        case .tradeVeteran: return 25
        }
    }
}

// MARK: - Achievement Check Context

/// Contains all data needed to check achievement unlock conditions
struct AchievementCheckContext {
    let completedTradeCount: Int
    let itemCount: Int
    let reviewsGivenCount: Int
    let reviewsReceivedCount: Int
    let userRating: Double
    let currentStreak: Int
    let longestStreak: Int
    let hasFiveStarReview: Bool
    let tradesInLast7Days: Int
    let topCategoryCount: Int  // Highest trade count in any single category
    
    /// Creates context from UserManager data
    static func fromUserManager(_ manager: UserManager, additionalData: AdditionalAchievementData? = nil) -> AchievementCheckContext {
        return AchievementCheckContext(
            completedTradeCount: manager.completedTradeCount,
            itemCount: manager.userItems.count,
            reviewsGivenCount: manager.reviewsGivenCount,
            reviewsReceivedCount: manager.userReviewCount,
            userRating: manager.userRating,
            currentStreak: manager.currentStreak,
            longestStreak: manager.longestStreak,
            hasFiveStarReview: additionalData?.hasFiveStarReview ?? false,
            tradesInLast7Days: additionalData?.tradesInLast7Days ?? 0,
            topCategoryCount: additionalData?.topCategoryCount ?? 0
        )
    }
    
    /// Checks if a specific achievement type should be unlocked
    func shouldUnlock(_ type: AchievementType) -> Bool {
        switch type {
        case .firstSwap:
            return completedTradeCount >= 1
        case .fiveStar:
            return hasFiveStarReview
        case .hotStreak:
            return tradesInLast7Days >= 3
        case .categoryKing:
            return topCategoryCount >= 10
        case .ecoWarrior:
            return completedTradeCount >= 10  // 10 trades × 2.5 kg = 25 kg
        case .collector:
            return itemCount >= 10
        case .communityStar:
            return reviewsGivenCount >= 10
        case .topRated:
            return userRating >= 4.5 && reviewsReceivedCount >= 5
        case .streakMaster:
            return longestStreak >= 7
        case .tradeVeteran:
            return completedTradeCount >= 25
        }
    }
    
    /// Gets current progress value for an achievement type
    func currentValue(for type: AchievementType) -> Int {
        switch type {
        case .firstSwap:
            return min(completedTradeCount, 1)
        case .fiveStar:
            return hasFiveStarReview ? 1 : 0
        case .hotStreak:
            return tradesInLast7Days
        case .categoryKing:
            return topCategoryCount
        case .ecoWarrior:
            return completedTradeCount
        case .collector:
            return itemCount
        case .communityStar:
            return reviewsGivenCount
        case .topRated:
            return reviewsReceivedCount
        case .streakMaster:
            return longestStreak
        case .tradeVeteran:
            return completedTradeCount
        }
    }
    
    /// Creates progress object for an achievement type
    func progress(for type: AchievementType, isUnlocked: Bool) -> AchievementProgress {
        return AchievementProgress(
            type: type,
            currentValue: currentValue(for: type),
            targetValue: AchievementProgress.targetValue(for: type),
            isUnlocked: isUnlocked
        )
    }
}

// MARK: - Additional Data (Fetched Async)

/// Data that requires additional database queries
struct AdditionalAchievementData {
    let hasFiveStarReview: Bool
    let tradesInLast7Days: Int
    let topCategoryCount: Int
}