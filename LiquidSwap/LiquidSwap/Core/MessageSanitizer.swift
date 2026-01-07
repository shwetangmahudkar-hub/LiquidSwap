//
//  MessageSanitizer.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2026-01-05.
//


import Foundation

/// Sanitizes and validates message content before sending.
/// Protects against XSS, injection, spam, and malformed content.
struct MessageSanitizer {
    
    // MARK: - Configuration
    
    struct Config {
        let maxLength: Int
        let minLength: Int
        let allowLinks: Bool
        let allowMarkdown: Bool
        let stripInvisibleChars: Bool
        let blockSpamPatterns: Bool
        
        static let `default` = Config(
            maxLength: 2000,
            minLength: 1,
            allowLinks: true,
            allowMarkdown: true,
            stripInvisibleChars: true,
            blockSpamPatterns: true
        )
        
        static let strict = Config(
            maxLength: 500,
            minLength: 1,
            allowLinks: false,
            allowMarkdown: false,
            stripInvisibleChars: true,
            blockSpamPatterns: true
        )
    }
    
    // MARK: - Result Type
    
    enum Result {
        case valid(sanitized: String)
        case tooLong(maxAllowed: Int)
        case tooShort
        case empty
        case blocked(reason: String)
        case invalid(reason: String)
    }
    
    // MARK: - Spam/Dangerous Patterns
    
    /// Patterns that indicate potential spam or malicious content
    private static let spamPatterns: [String] = [
        // Repeated characters (more than 10 of the same)
        "(.)\\1{10,}",
        // Excessive caps (more than 20 consecutive)
        "[A-Z]{20,}",
        // Common spam phrases
        "(?i)click here to win",
        "(?i)congratulations you('ve)? won",
        "(?i)free money",
        "(?i)act now",
        "(?i)limited time offer",
        "(?i)bitcoin doubler",
        "(?i)crypto giveaway"
    ]
    
    /// Dangerous URL patterns (phishing, malware)
    private static let dangerousUrlPatterns: [String] = [
        // IP address URLs (often phishing)
        "https?://\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}",
        // URL shorteners commonly used for malicious links
        "(?i)(bit\\.ly|tinyurl|t\\.co|goo\\.gl|ow\\.ly|is\\.gd|buff\\.ly)/",
        // Data URLs (can contain scripts)
        "(?i)data:",
        // JavaScript URLs
        "(?i)javascript:",
        // Common phishing patterns
        "(?i)(paypal|apple|google|amazon|bank).*\\.(tk|ml|ga|cf|gq|xyz)/",
    ]
    
    /// Invisible/control characters to strip
    private static let invisibleCharacterPattern = "[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F\\u200B-\\u200D\\uFEFF\\u2060]"
    
    // MARK: - Public API
    
    /// Sanitizes message content
    /// - Parameters:
    ///   - content: The raw message content
    ///   - config: Sanitization configuration
    /// - Returns: Result indicating validity and sanitized content
    static func sanitize(_ content: String, config: Config = .default) -> Result {
        var sanitized = content
        
        // 1. Trim whitespace
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 2. Check for empty
        if sanitized.isEmpty {
            return .empty
        }
        
        // 3. Strip invisible characters if configured
        if config.stripInvisibleChars {
            sanitized = stripInvisibleCharacters(sanitized)
        }
        
        // 4. Check length after stripping
        if sanitized.count < config.minLength {
            return .tooShort
        }
        
        if sanitized.count > config.maxLength {
            return .tooLong(maxAllowed: config.maxLength)
        }
        
        // 5. Check for spam patterns
        if config.blockSpamPatterns {
            if let spamReason = detectSpam(sanitized) {
                return .blocked(reason: spamReason)
            }
        }
        
        // 6. Check for dangerous URLs
        if let dangerousUrlReason = detectDangerousUrls(sanitized) {
            return .blocked(reason: dangerousUrlReason)
        }
        
        // 7. Sanitize URLs if not allowed
        if !config.allowLinks {
            sanitized = removeUrls(sanitized)
        }
        
        // 8. Normalize whitespace (collapse multiple spaces/newlines)
        sanitized = normalizeWhitespace(sanitized)
        
        // 9. Final empty check after all sanitization
        if sanitized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .empty
        }
        
        return .valid(sanitized: sanitized)
    }
    
    /// Quick validation check without full sanitization
    static func isValid(_ content: String, config: Config = .default) -> Bool {
        switch sanitize(content, config: config) {
        case .valid:
            return true
        default:
            return false
        }
    }
    
    /// Sanitizes content for display (less strict, for rendering)
    static func sanitizeForDisplay(_ content: String) -> String {
        var sanitized = content
        
        // Strip invisible characters
        sanitized = stripInvisibleCharacters(sanitized)
        
        // Normalize whitespace
        sanitized = normalizeWhitespace(sanitized)
        
        return sanitized
    }
    
    // MARK: - Private Helpers
    
    private static func stripInvisibleCharacters(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: invisibleCharacterPattern, options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }
    
    private static func detectSpam(_ text: String) -> String? {
        for pattern in spamPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(text.startIndex..., in: text)
                if regex.firstMatch(in: text, options: [], range: range) != nil {
                    return "Message contains spam-like content"
                }
            }
        }
        return nil
    }
    
    private static func detectDangerousUrls(_ text: String) -> String? {
        for pattern in dangerousUrlPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(text.startIndex..., in: text)
                if regex.firstMatch(in: text, options: [], range: range) != nil {
                    return "Message contains a potentially unsafe link"
                }
            }
        }
        return nil
    }
    
    private static func removeUrls(_ text: String) -> String {
        let urlPattern = "https?://[^\\s]+"
        guard let regex = try? NSRegularExpression(pattern: urlPattern, options: .caseInsensitive) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "[link removed]")
    }
    
    private static func normalizeWhitespace(_ text: String) -> String {
        // Collapse multiple spaces into one
        var result = text.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        
        // Collapse more than 2 consecutive newlines into 2
        result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        
        return result
    }
}

// MARK: - String Extension for Convenience

extension String {
    /// Returns sanitized version of this string for messaging
    var sanitizedForMessage: String {
        switch MessageSanitizer.sanitize(self) {
        case .valid(let sanitized):
            return sanitized
        default:
            return self.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    /// Checks if this string is valid for messaging
    var isValidMessage: Bool {
        return MessageSanitizer.isValid(self)
    }
}