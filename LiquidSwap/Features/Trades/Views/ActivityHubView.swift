//
//  ActivityHubView.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-27.
//


import SwiftUI

struct ActivityHubView: View {
    @Environment(\.dismiss) var dismiss
    @State private var events: [ActivityEvent] = []
    @State private var isLoading = true
    
    // Navigation State
    @State private var selectedUserId: UUID?
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackground()
                
                VStack(spacing: 0) {
                    // Custom Header
                    HStack {
                        Text("Activity Hub")
                            .font(.largeTitle).bold()
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "sparkles")
                            .foregroundStyle(.yellow)
                            .font(.title)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    
                    if isLoading {
                        Spacer()
                        ProgressView().tint(.white)
                        Spacer()
                    } else if events.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "bell.slash.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.3))
                            Text("No new activity")
                                .font(.title3).bold()
                                .foregroundStyle(.white)
                            Text("When users swipe right on your items,\nthey will appear here.")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white.opacity(0.7))
                            Spacer()
                        }
                        .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(events) { event in
                                    ActivityRow(event: event)
                                        .onTapGesture {
                                            selectedUserId = event.actor.id
                                        }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedUserId) { userId in
                // Re-use the Public Profile we built earlier
                // This wraps UUID to be Identifiable for the sheet
                PublicProfileView(userId: userId)
                    .presentationDetents([.fraction(0.85)])
            }
            .onAppear {
                loadActivity()
            }
        }
    }
    
    func loadActivity() {
        guard let userId = UserManager.shared.currentUser?.id else { return }
        isLoading = true
        
        Task {
            do {
                let fetchedEvents = try await DatabaseService.shared.fetchActivityEvents(for: userId)
                await MainActor.run {
                    self.events = fetchedEvents
                    self.isLoading = false
                }
            } catch {
                print("Error loading activity: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }
}

// Wrapper for Sheet
extension UUID: @retroactive Identifiable {
    public var id: String { self.uuidString }
}

// MARK: - Subview: The Row
struct ActivityRow: View {
    let event: ActivityEvent
    
    var body: some View {
        HStack(spacing: 12) {
            // 1. Actor Avatar
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                AsyncImageView(filename: event.actor.avatarUrl)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                
                // Heart Badge
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Circle().fill(.red))
                    }
                }
            }
            .frame(width: 50, height: 50)
            
            // 2. Text Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.actor.username)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    if event.actor.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(.cyan)
                    }
                    
                    Spacer()
                    
                    Text(timeAgo(event.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Text("Liked your **\(event.item.title)**")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
            
            // 3. Your Item Thumbnail
            AsyncImageView(filename: event.item.imageUrl)
                .frame(width: 40, height: 40)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.3), lineWidth: 1))
        }
        .padding()
        .background(Color.black.opacity(0.4))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
