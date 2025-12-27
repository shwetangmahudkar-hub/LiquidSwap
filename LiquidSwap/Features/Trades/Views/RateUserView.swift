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
    let targetUsername: String // Pass this in for UI
    
    @State private var rating = 5
    @State private var comment = ""
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.yellow)
                    
                    Text("Rate \(targetUsername)")
                        .font(.title2).bold()
                }
                .padding(.top, 40)
                
                // Star Picker
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { index in
                        Image(systemName: index <= rating ? "star.fill" : "star")
                            .font(.largeTitle)
                            .foregroundStyle(.yellow)
                            .onTapGesture {
                                withAnimation { rating = index }
                                Haptics.shared.playLight()
                            }
                    }
                }
                
                // Comment
                TextField("Write a review (optional)...", text: $comment)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                
                Spacer()
                
                // Submit Button
                Button(action: submitRating) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Submit Review")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.cyan)
                            .foregroundStyle(.black)
                            .cornerRadius(12)
                    }
                }
                .disabled(isSubmitting)
                .padding()
            }
            .navigationTitle("Leave a Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    func submitRating() {
        guard let myId = UserManager.shared.currentUser?.id else { return }
        isSubmitting = true
        
        Task {
            do {
                try await DatabaseService.shared.submitReview(
                    reviewerId: myId,
                    reviewedId: targetUserId,
                    rating: rating,
                    comment: comment
                )
                Haptics.shared.playSuccess()
                dismiss()
            } catch {
                print("❌ Failed to submit review: \(error)")
                Haptics.shared.playError()
                isSubmitting = false
            }
        }
    }
}