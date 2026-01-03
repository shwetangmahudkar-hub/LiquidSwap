//
//  ProgressionManager.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2026-01-02.
//


import Foundation
import SwiftUI
import Combine
internal import PostgREST
import Supabase

// MARK: - Progression Manager

@MainActor
class ProgressionManager: ObservableObject {
    static let shared = ProgressionManager()
    
    // MARK: - Published State
    
    /// All unlocked achievements for current user
    @Published var unlockedAchievements: [Achievement] = []
    
    /// Progress for all achievement types
    @Published var achievementProgress: [AchievementType: AchievementProgress] = [:]
    
    /// Recently unlocked achievement (for celebration animation)
    @Published var newlyUnlockedAchievement: AchievementType?
    
    /// Loading state
    @Published var isLoading = false
    
    // MARK: - Dependencies
    
    private let db = DatabaseService.shared
    private let client = SupabaseConfig.client
    private var userManager: UserManager { UserManager.shared }
    
    // MARK: - Computed Properties
    
    /// Count of unlocked achievements
    var unlockedCount: Int {
        return unlockedAchievements.count
    }
    
    /// Total achievements available
    var totalCount: Int {
        return AchievementType.allCases.count
    }
    
    /// Completion percentage
    var completionPercentage: Double {
        guard totalCount > 0 else { return 0 }
        return Double(unlockedCount) / Double(totalCount)
    }
    
    /// Formatted completion text
    var completionText: String {
        return "\(unlockedCount)/\(totalCount)"
    }
    
    /// Sorted unlocked achievements (most recent first)
    var sortedUnlockedAchievements: [Achievement] {
        return unlockedAchievements.sorted { $0.unlockedAt > $1.unlockedAt }
    }
    
    /// All achievement types sorted by sort order
    var allAchievementsSorted: [AchievementType] {
        return AchievementType.allCases.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    /// Locked achievement types
    var lockedAchievements: [AchievementType] {
        let unlockedTypes = Set(unlockedAchievements.map { $0.type })
        return allAchievementsSorted.filter { !unlockedTypes.contains($0) }
    }
    
    /// Next closest achievement to unlock (highest progress that isn't complete)
    var nextAchievementToUnlock: AchievementType? {
        let unlockedTypes = Set(unlockedAchievements.map { $0.type })
        
        return lockedAchievements
            .compactMap { type -> (AchievementType, Double)? in
                guard let progress = achievementProgress[type] else { return nil }
                return (type, progress.progress)
            }
            .sorted { $0.1 > $1.1 }  // Sort by progress descending
            .first?.0
    }
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Data Loading
    
    /// Loads all achievement data for current user
    func loadAchievements() async {
        guard let userId = userManager.currentUser?.id else {
            print("❌ ProgressionManager: No user logged in")
            return
        }
        
        isLoading = true
        
        do {
            // 1. Fetch unlocked achievements from database
            let unlocked = try await fetchUnlockedAchievements(userId: userId)
            self.unlockedAchievements = unlocked
            
            // 2. Fetch additional data needed for progress calculation
            let additionalData = try await fetchAdditionalData(userId: userId)
            
            // 3. Build context and calculate progress
            let context = AchievementCheckContext.fromUserManager(userManager, additionalData: additionalData)
            let unlockedTypes = Set(unlocked.map { $0.type })
            
            var progress: [AchievementType: AchievementProgress] = [:]
            for type in AchievementType.allCases {
                progress[type] = context.progress(for: type, isUnlocked: unlockedTypes.contains(type))
            }
            self.achievementProgress = progress
            
            print("✅ ProgressionManager: Loaded \(unlocked.count) achievements")
            
        } catch {
            print("❌ ProgressionManager: Failed to load achievements: \(error)")
        }
        
        isLoading = false
    }
    
    /// Checks for new achievements and unlocks them
    func checkAndUnlockAchievements() async {
        guard let userId = userManager.currentUser?.id else { return }
        
        do {
            // 1. Get current unlocked types
            let unlockedTypes = Set(unlockedAchievements.map { $0.type })
            
            // 2. Fetch additional data
            let additionalData = try await fetchAdditionalData(userId: userId)
            
            // 3. Build context
            let context = AchievementCheckContext.fromUserManager(userManager, additionalData: additionalData)
            
            // 4. Check each locked achievement
            for type in AchievementType.allCases {
                if !unlockedTypes.contains(type) && context.shouldUnlock(type) {
                    // Unlock this achievement!
                    await unlockAchievement(type, userId: userId)
                }
            }
            
            // 5. Refresh progress
            var progress: [AchievementType: AchievementProgress] = [:]
            let newUnlockedTypes = Set(unlockedAchievements.map { $0.type })
            for type in AchievementType.allCases {
                progress[type] = context.progress(for: type, isUnlocked: newUnlockedTypes.contains(type))
            }
            self.achievementProgress = progress
            
        } catch {
            print("❌ ProgressionManager: Error checking achievements: \(error)")
        }
    }
    
    // MARK: - Achievement Unlocking
    
    /// Unlocks a specific achievement
    private func unlockAchievement(_ type: AchievementType, userId: UUID) async {
        let achievement = Achievement(userId: userId, type: type)
        
        do {
            // Save to database
            try await saveAchievement(achievement)
            
            // Update local state
            unlockedAchievements.append(achievement)
            
            // Trigger celebration
            self.newlyUnlockedAchievement = type
            
            // Haptic feedback
            Haptics.shared.playSuccess()
            
            print("🏆 Achievement Unlocked: \(type.title)")
            
            // Clear celebration after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if self.newlyUnlockedAchievement == type {
                    self.newlyUnlockedAchievement = nil
                }
            }
            
        } catch {
            print("❌ Failed to unlock achievement \(type.title): \(error)")
        }
    }
    
    /// Manually dismisses the celebration overlay
    func dismissCelebration() {
        newlyUnlockedAchievement = nil
    }
    
    // MARK: - Database Operations
    
    private func fetchUnlockedAchievements(userId: UUID) async throws -> [Achievement] {
        struct AchievementRow: Decodable {
            let id: UUID
            let user_id: UUID
            let type: String
            let unlocked_at: Date
        }
        
        let rows: [AchievementRow] = try await client
            .from("user_achievements")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        return rows.compactMap { row in
            guard let type = AchievementType(rawValue: row.type) else { return nil }
            return Achievement(
                id: row.id,
                userId: row.user_id,
                type: type,
                unlockedAt: row.unlocked_at
            )
        }
    }
    
    private func saveAchievement(_ achievement: Achievement) async throws {
        struct AchievementInsert: Encodable {
            let id: UUID
            let user_id: UUID
            let type: String
            let unlocked_at: Date
        }
        
        let data = AchievementInsert(
            id: achievement.id,
            user_id: achievement.userId,
            type: achievement.type.rawValue,
            unlocked_at: achievement.unlockedAt
        )
        
        try await client
            .from("user_achievements")
            .insert(data)
            .execute()
    }
    
    private func fetchAdditionalData(userId: UUID) async throws -> AdditionalAchievementData {
        // Fetch all additional data concurrently
        async let fiveStarCheck = db.hasReceivedFiveStarReview(userId: userId)
        async let recentTrades = fetchTradesInLast7Days(userId: userId)
        async let categoryBreakdown = db.fetchTradeCategoryBreakdown(userId: userId)
        
        let (hasFiveStar, tradesLast7, categories) = try await (fiveStarCheck, recentTrades, categoryBreakdown)
        
        // Get the highest category count
        let topCategoryCount = categories.values.max() ?? 0
        
        return AdditionalAchievementData(
            hasFiveStarReview: hasFiveStar,
            tradesInLast7Days: tradesLast7,
            topCategoryCount: topCategoryCount
        )
    }
    
    private func fetchTradesInLast7Days(userId: UUID) async throws -> Int {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else {
            return 0
        }
        
        return try await db.fetchTradesInDateRange(userId: userId, from: startDate, to: endDate)
    }
    
    // MARK: - Public Helpers
    
    /// Checks if a specific achievement type is unlocked
    func isUnlocked(_ type: AchievementType) -> Bool {
        return unlockedAchievements.contains { $0.type == type }
    }
    
    /// Gets progress for a specific achievement type
    func progress(for type: AchievementType) -> AchievementProgress? {
        return achievementProgress[type]
    }
    
    /// Gets the unlock date for an achievement (if unlocked)
    func unlockDate(for type: AchievementType) -> Date? {
        return unlockedAchievements.first { $0.type == type }?.unlockedAt
    }
    
    /// Fetches achievements for another user (public profile)
    func fetchAchievements(for userId: UUID) async -> [Achievement] {
        do {
            return try await fetchUnlockedAchievements(userId: userId)
        } catch {
            print("❌ Failed to fetch achievements for user: \(error)")
            return []
        }
    }
    
    /// Clears all data (on logout)
    func clearData() {
        unlockedAchievements = []
        achievementProgress = [:]
        newlyUnlockedAchievement = nil
    }
}

// MARK: - Achievement Trigger Points

extension ProgressionManager {
    
    /// Call after a trade is completed
    func onTradeCompleted() async {
        await checkAndUnlockAchievements()
    }
    
    /// Call after a review is submitted
    func onReviewSubmitted() async {
        await checkAndUnlockAchievements()
    }
    
    /// Call after a new item is listed
    func onItemListed() async {
        await checkAndUnlockAchievements()
    }
    
    /// Call when user logs in (streak check happens in UserManager)
    func onUserLogin() async {
        await loadAchievements()
        await checkAndUnlockAchievements()
    }
}
