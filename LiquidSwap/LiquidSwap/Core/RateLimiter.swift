//
//  RateLimiter.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2026-01-05.
//


import Foundation

/// A reusable rate limiter that tracks action timestamps and enforces limits.
/// Used to prevent spam/abuse of various app features.
actor RateLimiter {
    
    // MARK: - Configuration
    
    struct Config {
        let maxAttempts: Int
        let windowSeconds: TimeInterval
        let cooldownSeconds: TimeInterval
        
        /// Default: 5 attempts per 60 seconds, 30 second cooldown when exceeded
        static let `default` = Config(maxAttempts: 5, windowSeconds: 60, cooldownSeconds: 30)
        
        /// Strict: 3 attempts per 60 seconds, 60 second cooldown
        static let strict = Config(maxAttempts: 3, windowSeconds: 60, cooldownSeconds: 60)
        
        /// Relaxed: 10 attempts per 60 seconds, 15 second cooldown
        static let relaxed = Config(maxAttempts: 10, windowSeconds: 60, cooldownSeconds: 15)
        
        /// For offers: 5 per minute, 20 per hour hard cap
        static let offers = Config(maxAttempts: 5, windowSeconds: 60, cooldownSeconds: 30)
        
        /// For messages: 20 per minute
        static let messages = Config(maxAttempts: 20, windowSeconds: 60, cooldownSeconds: 10)
        
        /// For likes: 30 per minute
        static let likes = Config(maxAttempts: 30, windowSeconds: 60, cooldownSeconds: 5)
    }
    
    // MARK: - Result Type
    
    enum Result {
        case allowed
        case rateLimited(retryAfter: TimeInterval)
        case cooldown(remainingSeconds: TimeInterval)
    }
    
    // MARK: - Storage
    
    /// Tracks timestamps of actions per key (e.g., "offers", "messages", "likes:{itemId}")
    private var timestamps: [String: [Date]] = [:]
    
    /// Tracks when a cooldown started for a key
    private var cooldowns: [String: Date] = [:]
    
    /// Hourly limits (separate tracking for longer-term limits)
    private var hourlyTimestamps: [String: [Date]] = [:]
    
    // MARK: - Singleton Instances for Common Use Cases
    
    static let offers = RateLimiter()
    static let messages = RateLimiter()
    static let likes = RateLimiter()
    static let reports = RateLimiter()
    
    // MARK: - Public API
    
    /// Check if an action is allowed and record it if so.
    /// - Parameters:
    ///   - key: Unique identifier for this action type/target
    ///   - config: Rate limiting configuration to use
    /// - Returns: Result indicating if action is allowed or when to retry
    func checkAndRecord(key: String, config: Config = .default) -> Result {
        let now = Date()
        
        // 1. Check if in cooldown
        if let cooldownStart = cooldowns[key] {
            let elapsed = now.timeIntervalSince(cooldownStart)
            if elapsed < config.cooldownSeconds {
                let remaining = config.cooldownSeconds - elapsed
                return .cooldown(remainingSeconds: remaining)
            } else {
                // Cooldown expired, remove it
                cooldowns.removeValue(forKey: key)
            }
        }
        
        // 2. Clean old timestamps outside the window
        let windowStart = now.addingTimeInterval(-config.windowSeconds)
        timestamps[key] = (timestamps[key] ?? []).filter { $0 > windowStart }
        
        // 3. Check count in window
        let currentCount = timestamps[key]?.count ?? 0
        
        if currentCount >= config.maxAttempts {
            // Start cooldown
            cooldowns[key] = now
            return .rateLimited(retryAfter: config.cooldownSeconds)
        }
        
        // 4. Record this attempt
        if timestamps[key] == nil {
            timestamps[key] = []
        }
        timestamps[key]?.append(now)
        
        return .allowed
    }
    
    /// Check hourly limit (separate from per-minute limits)
    /// - Parameters:
    ///   - key: Unique identifier
    ///   - maxPerHour: Maximum allowed per hour
    /// - Returns: True if within hourly limit
    func checkHourlyLimit(key: String, maxPerHour: Int) -> Bool {
        let now = Date()
        let hourAgo = now.addingTimeInterval(-3600)
        
        // Clean old timestamps
        hourlyTimestamps[key] = (hourlyTimestamps[key] ?? []).filter { $0 > hourAgo }
        
        let currentCount = hourlyTimestamps[key]?.count ?? 0
        
        if currentCount >= maxPerHour {
            return false
        }
        
        // Record
        if hourlyTimestamps[key] == nil {
            hourlyTimestamps[key] = []
        }
        hourlyTimestamps[key]?.append(now)
        
        return true
    }
    
    /// Get remaining attempts in current window
    func remainingAttempts(key: String, config: Config = .default) -> Int {
        let now = Date()
        let windowStart = now.addingTimeInterval(-config.windowSeconds)
        let currentCount = (timestamps[key] ?? []).filter { $0 > windowStart }.count
        return max(0, config.maxAttempts - currentCount)
    }
    
    /// Reset rate limit for a key (use sparingly, e.g., after successful trade)
    func reset(key: String) {
        timestamps.removeValue(forKey: key)
        cooldowns.removeValue(forKey: key)
        hourlyTimestamps.removeValue(forKey: key)
    }
    
    /// Clear all rate limits (use for testing or logout)
    func clearAll() {
        timestamps.removeAll()
        cooldowns.removeAll()
        hourlyTimestamps.removeAll()
    }
}

// MARK: - Convenience Extensions

extension RateLimiter {
    
    /// Check offer creation rate limit
    /// - Returns: Tuple of (isAllowed, errorMessage)
    static func canCreateOffer() async -> (allowed: Bool, message: String?) {
        // Check per-minute limit
        let minuteResult = await offers.checkAndRecord(key: "create_offer", config: .offers)
        
        switch minuteResult {
        case .allowed:
            // Also check hourly limit (20 per hour)
            let hourlyAllowed = await offers.checkHourlyLimit(key: "create_offer_hourly", maxPerHour: 20)
            if !hourlyAllowed {
                return (false, "You've reached the hourly limit for offers. Please try again later.")
            }
            return (true, nil)
            
        case .rateLimited(let retryAfter):
            let seconds = Int(retryAfter)
            return (false, "Too many offers. Please wait \(seconds) seconds before trying again.")
            
        case .cooldown(let remaining):
            let seconds = Int(remaining)
            return (false, "Please wait \(seconds) seconds before sending another offer.")
        }
    }
    
    /// Check message sending rate limit
    static func canSendMessage() async -> (allowed: Bool, message: String?) {
        let result = await messages.checkAndRecord(key: "send_message", config: .messages)
        
        switch result {
        case .allowed:
            return (true, nil)
        case .rateLimited(let retryAfter):
            return (false, "Slow down! Wait \(Int(retryAfter)) seconds.")
        case .cooldown(let remaining):
            return (false, "Please wait \(Int(remaining)) seconds.")
        }
    }
    
    /// Check like/interest rate limit
    static func canLikeItem() async -> (allowed: Bool, message: String?) {
        let result = await likes.checkAndRecord(key: "like_item", config: .likes)
        
        switch result {
        case .allowed:
            return (true, nil)
        case .rateLimited, .cooldown:
            return (false, "Too fast! Please slow down.")
        }
    }
    
    /// Check report rate limit (very strict)
    static func canSubmitReport() async -> (allowed: Bool, message: String?) {
        let result = await reports.checkAndRecord(key: "submit_report", config: .strict)
        
        switch result {
        case .allowed:
            return (true, nil)
        case .rateLimited(let retryAfter):
            return (false, "Please wait \(Int(retryAfter)) seconds before submitting another report.")
        case .cooldown(let remaining):
            return (false, "Report cooldown: \(Int(remaining)) seconds remaining.")
        }
    }
}