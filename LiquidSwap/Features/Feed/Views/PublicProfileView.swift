import SwiftUI

struct PublicProfileView: View {
    let userId: UUID
    @Environment(\.dismiss) var dismiss
    
    // ✨ NEW: Access UserManager for blocking logic
    @ObservedObject var userManager = UserManager.shared
    
    @State private var profile: UserProfile?
    @State private var items: [TradeItem] = []
    @State private var rating: Double = 0.0
    @State private var reviewCount: Int = 0
    @State private var isLoading = true
    
    // ✨ NEW: Alert State
    @State private var showBlockAlert = false
    @State private var showReportAlert = false
    
    // Grid Layout
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LiquidBackground()
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let profile = profile {
                    ScrollView {
                        VStack(spacing: 24) {
                            
                            // --- HEADER ---
                            VStack(spacing: 12) {
                                // Avatar
                                ZStack {
                                    Circle()
                                        .stroke(LinearGradient(colors: [.cyan, .purple], startPoint: .top, endPoint: .bottom), lineWidth: 3)
                                        .frame(width: 100, height: 100)
                                    
                                    AsyncImageView(filename: profile.avatarUrl)
                                        .frame(width: 92, height: 92)
                                        .clipShape(Circle())
                                }
                                
                                // Name & Stats
                                VStack(spacing: 4) {
                                    HStack(spacing: 4) {
                                        Text(profile.username)
                                            .font(.title2).bold()
                                            .foregroundStyle(.white)
                                        
                                        // Verification Checkmark
                                        if profile.isVerified {
                                            Image(systemName: "checkmark.seal.fill")
                                                .foregroundStyle(.cyan)
                                                .font(.headline)
                                        }
                                    }
                                    
                                    HStack(spacing: 6) {
                                        Image(systemName: "star.fill")
                                            .foregroundStyle(.yellow)
                                            .font(.caption)
                                        
                                        Text(String(format: "%.1f", rating))
                                            .font(.subheadline).bold()
                                            .foregroundStyle(.white)
                                        
                                        Text("(\(reviewCount) reviews)")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.6))
                                    }
                                    
                                    Text(profile.location)
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                        .padding(.top, 2)
                                }
                                
                                // Bio
                                Text(profile.bio.isEmpty ? "No bio provided." : profile.bio)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .padding(.top, 20)
                            
                            Divider()
                                .background(Color.white.opacity(0.2))
                            
                            // --- ACTIVE LISTINGS ---
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Active Listings (\(items.count))")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal)
                                
                                if items.isEmpty {
                                    Text("No other items listed.")
                                        .foregroundStyle(.gray)
                                        .font(.caption)
                                        .padding(.horizontal)
                                } else {
                                    LazyVGrid(columns: columns, spacing: 16) {
                                        ForEach(items) { item in
                                            NavigationLink(destination: ProductDetailView(item: item)) {
                                                InventoryItemCard(item: item)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            Spacer(minLength: 50)
                        }
                    }
                } else {
                    Text("User not found")
                        .foregroundStyle(.gray)
                }
            }
            .navigationTitle("Trader Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                
                // ✨ NEW: Safety Menu
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(role: .destructive, action: { showBlockAlert = true }) {
                            Label("Block User", systemImage: "hand.raised.fill")
                        }
                        
                        Button(action: { showReportAlert = true }) {
                            Label("Report User", systemImage: "exclamationmark.bubble")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                }
            }
            // ✨ NEW: Block Confirmation
            .alert("Block User?", isPresented: $showBlockAlert) {
                Button("Block", role: .destructive) {
                    Task {
                        await userManager.blockUser(userId: userId)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("They will no longer see your items, and you will not see theirs. Chats will be hidden.")
            }
            // ✨ NEW: Report Confirmation
            .alert("Report User?", isPresented: $showReportAlert) {
                Button("Spam", role: .destructive) { submitReport(reason: "Spam") }
                Button("Abusive", role: .destructive) { submitReport(reason: "Abusive") }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Why are you reporting this user?")
            }
            .onAppear {
                loadPublicProfile()
            }
        }
    }
    
    func loadPublicProfile() {
        isLoading = true
        Task {
            do {
                // Fetch Profile
                let p = try await DatabaseService.shared.fetchProfile(userId: userId)
                
                // Fetch Listings
                let allItems = try await DatabaseService.shared.fetchUserItems(userId: userId)
                
                // Fetch Stats
                let r = try await DatabaseService.shared.fetchUserRating(userId: userId)
                let c = try await DatabaseService.shared.fetchReviewCount(userId: userId)
                
                await MainActor.run {
                    self.profile = p
                    self.items = allItems
                    self.rating = r
                    self.reviewCount = c
                    self.isLoading = false
                }
            } catch {
                print("Error loading profile: \(error)")
                await MainActor.run { isLoading = false }
            }
        }
    }
    
    // ✨ NEW: Report Logic
    func submitReport(reason: String) {
        guard let myId = userManager.currentUser?.id else { return }
        Task {
            try? await DatabaseService.shared.reportUser(reporterId: myId, reportedId: userId, reason: reason)
            // Just dismiss for now, thanking the user
            dismiss()
        }
    }
}
