//
//  RateUserView.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-25.
//

import SwiftUI

struct RateUserView: View {
    @Environment(\.dismiss) var dismiss
    
    let targetUserId: UUID
    let targetUsername: String
    let tradeId: UUID?  // ✨ Issue #8: Optional trade ID for verification
    
    @State private var rating = 5
    @State private var comment = ""
    @State private var selectedTags: Set<String> = []
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Quick Feedback Tags
    let availableTags = ["Punctual", "Friendly", "Item as Described", "Responsive", "Safe Meetup"]
    
    // ✨ Backwards compatible initializer
    init(targetUserId: UUID, targetUsername: String, tradeId: UUID? = nil) {
        self.targetUserId = targetUserId
        self.targetUsername = targetUsername
        self.tradeId = tradeId
    }
    
    var body: some View {
        ZStack {
            // 1. Background
            Color.black.ignoresSafeArea()
            LiquidBackground()
                .opacity(0.6)
                .blur(radius: 20)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 2. Header (Grabber only - Swipe to dismiss)
                VStack(spacing: 12) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 40, height: 4)
                        .padding(.top, 16)
                    
                    Text("Rate Experience")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .textCase(.uppercase)
                }
                .padding(.bottom, 30)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        
                        // 3. Avatar & Title
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.05))
                                    .frame(width: 88, height: 88)
                                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                                
                                Text(String(targetUsername.prefix(1)).uppercased())
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            
                            VStack(spacing: 4) {
                                Text("How was your trade with")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.6))
                                
                                Text(targetUsername)
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        
                        // 4. Interactive Stars
                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { index in
                                Image(systemName: index <= rating ? "star.fill" : "star")
                                    .font(.system(size: 36))
                                    .foregroundStyle(index <= rating ? .yellow : .white.opacity(0.2))
                                    .scaleEffect(index <= rating ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: rating)
                                    .onTapGesture {
                                        Haptics.shared.playLight()
                                        rating = index
                                    }
                            }
                        }
                        .padding(.vertical, 10)
                        
                        // 5. Quick Tags
                        VStack(spacing: 12) {
                            Text("What went well?")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.5))
                            
                            FlowLayout(spacing: 8) {
                                ForEach(availableTags, id: \.self) { tag in
                                    TagPill(text: tag, isSelected: selectedTags.contains(tag)) {
                                        toggleTag(tag)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // 6. Comment Field
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ADD A COMMENT")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.leading, 8)
                            
                            TextField("Share details about your experience...", text: $comment, axis: .vertical)
                                .lineLimit(3...5)
                                .padding(16)
                                .background(Color.black.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                .foregroundStyle(.white)
                                .tint(.cyan)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 100)
                }
            }
            
            // 7. Submit Button (Floating)
            VStack {
                Spacer()
                Button(action: submitRating) {
                    ZStack {
                        Capsule()
                            .fill(Color.cyan)
                            .frame(height: 56)
                            .shadow(color: .cyan.opacity(0.4), radius: 10, y: 5)
                        
                        if isSubmitting {
                            ProgressView().tint(.black)
                        } else {
                            Text("Submit Review")
                                .font(.headline.bold())
                                .foregroundStyle(.black)
                        }
                    }
                }
                .disabled(isSubmitting)
                .padding(24)
            }
        }
        .alert("Review Sent", isPresented: $showSuccess) {
            Button("Done") { dismiss() }
        } message: {
            Text("Thanks for helping the community!")
        }
        .alert("Cannot Submit Review", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Logic
    
    func toggleTag(_ tag: String) {
        Haptics.shared.playLight()
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    func submitRating() {
        guard let myId = UserManager.shared.currentUser?.id else { return }
        isSubmitting = true
        
        // Combine tags and comment
        let finalComment = selectedTags.isEmpty ? comment : "[\(selectedTags.joined(separator: ", "))] \(comment)"
        
        // ✨ Issue #7: Sanitize the comment
        let sanitizedComment: String
        switch MessageSanitizer.sanitize(finalComment, config: .init(
            maxLength: 500,
            minLength: 0,
            allowLinks: false,
            allowMarkdown: false,
            stripInvisibleChars: true,
            blockSpamPatterns: true
        )) {
        case .valid(let sanitized):
            sanitizedComment = sanitized
        case .empty:
            sanitizedComment = ""
        default:
            sanitizedComment = finalComment.prefix(500).description
        }
        
        Task {
            do {
                // ✨ Issue #8: Use trade-verified submission
                if let tradeId = tradeId {
                    // New secure path - verify trade
                    let result = try await DatabaseService.shared.submitReviewWithVerification(
                        reviewerId: myId,
                        reviewedId: targetUserId,
                        tradeId: tradeId,
                        rating: rating,
                        comment: sanitizedComment
                    )
                    
                    await MainActor.run {
                        switch result {
                        case .success:
                            handleSuccess()
                        case .noCompletedTrade:
                            handleError("No completed trade found with this user.")
                        case .alreadyReviewed:
                            handleError("You've already reviewed this trade.")
                        case .cannotReviewSelf:
                            handleError("You cannot review yourself.")
                        case .invalidRating:
                            handleError("Invalid rating value.")
                        case .error(let msg):
                            handleError(msg)
                        }
                    }
                } else {
                    // Legacy path - try to find a completed trade automatically
                    // This maintains backwards compatibility
                    if let foundTradeId = try await DatabaseService.shared.findCompletedTrade(
                        userId1: myId,
                        userId2: targetUserId
                    ) {
                        let result = try await DatabaseService.shared.submitReviewWithVerification(
                            reviewerId: myId,
                            reviewedId: targetUserId,
                            tradeId: foundTradeId,
                            rating: rating,
                            comment: sanitizedComment
                        )
                        
                        await MainActor.run {
                            switch result {
                            case .success:
                                handleSuccess()
                            case .alreadyReviewed:
                                handleError("You've already reviewed this trade.")
                            default:
                                handleError("Unable to submit review.")
                            }
                        }
                    } else {
                        await MainActor.run {
                            handleError("You can only review users after completing a trade with them.")
                        }
                    }
                }
                
            } catch {
                print("❌ Failed to submit review: \(error)")
                await MainActor.run {
                    handleError("Failed to submit review. Please try again.")
                }
            }
        }
    }
    
    private func handleSuccess() {
        // ✨ PROGRESSION TRIGGER: Check achievements after submitting review
        Task {
            await ProgressionManager.shared.onReviewSubmitted()
            await UserManager.shared.loadUserData()
        }
        
        Haptics.shared.playSuccess()
        showSuccess = true
        isSubmitting = false
    }
    
    private func handleError(_ message: String) {
        Haptics.shared.playError()
        errorMessage = message
        showError = true
        isSubmitting = false
    }
}

// MARK: - Subcomponents

struct TagPill: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .black : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.cyan : Color.white.opacity(0.1))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.cyan : Color.white.opacity(0.2), lineWidth: 1)
                )
                .animation(.spring(response: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// Simple FlowLayout Implementation
struct FlowLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0
        
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width {
                x = 0
                y += maxHeight + spacing
                maxHeight = 0
            }
            maxHeight = max(maxHeight, size.height)
            x += size.width + spacing
        }
        height = y + maxHeight
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var maxHeight: CGFloat = 0
        
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += maxHeight + spacing
                maxHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            maxHeight = max(maxHeight, size.height)
            x += size.width + spacing
        }
    }
}
