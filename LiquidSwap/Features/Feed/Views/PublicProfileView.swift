import SwiftUI

struct PublicProfileView: View {
    let userId: UUID
    var showActiveListings: Bool = true
    
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userManager = UserManager.shared
    
    // Data State
    @State private var profile: UserProfile?
    @State private var items: [TradeItem] = []
    @State private var rating: Double = 0.0
    @State private var reviewCount: Int = 0
    @State private var tradeCount: Int = 0 // ✨ Gamification: Trade count
    @State private var isLoading = true
    
    // Derived Stats
    @State private var topCategory: String = "General"
    
    // Alert State
    @State private var showBlockAlert = false
    @State private var showReportAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LiquidBackground()
                
                if isLoading {
                    ProgressView().tint(.white)
                } else if let profile = profile {
                    ScrollView {
                        VStack(spacing: 24) {
                            
                            // --- HEADER ---
                            VStack(spacing: 12) {
                                // Avatar with Level Ring
                                ZStack {
                                    // Progress Ring Background
                                    Circle()
                                        .stroke(Color.white.opacity(0.1), lineWidth: 4)
                                        .frame(width: 100, height: 100)
                                    
                                    // Live Level Progress Ring
                                    Circle()
                                        .trim(from: 0, to: calculateLevelProgress(count: tradeCount))
                                        .stroke(
                                            AngularGradient(colors: [.cyan, .purple, .cyan], center: .center),
                                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                        )
                                        .rotationEffect(.degrees(-90))
                                        .frame(width: 100, height: 100)
                                        .shadow(color: .cyan.opacity(0.5), radius: 10)
                                    
                                    AsyncImageView(filename: profile.avatarUrl)
                                        .frame(width: 92, height: 92)
                                        .clipShape(Circle())
                                    
                                    // Premium Crown
                                    if profile.isPremium {
                                        VStack {
                                            Spacer()
                                            Image(systemName: "crown.fill")
                                                .font(.headline)
                                                .foregroundStyle(.yellow)
                                                .padding(6)
                                                .background(Circle().fill(.black))
                                                .offset(y: 10)
                                        }
                                    }
                                }
                                
                                // Name, Rank & Verification
                                VStack(spacing: 6) {
                                    HStack(spacing: 4) {
                                        Text(profile.username)
                                            .font(.title2).bold()
                                            .foregroundStyle(.white)
                                        
                                        if profile.isVerified {
                                            Image(systemName: "checkmark.seal.fill")
                                                .foregroundStyle(.cyan)
                                                .font(.headline)
                                        }
                                    }
                                    
                                    // ✨ Rank Badge
                                    Text(calculateLevelTitle(count: tradeCount).uppercased())
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundStyle(.cyan)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.cyan.opacity(0.1))
                                        .clipShape(Capsule())
                                    
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
                            
                            // --- HIGHLIGHTS SECTION ---
                            highlightsSection
                            
                            // --- ACTIVE LISTINGS SECTION ---
                            if showActiveListings {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Active Listings")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 20)
                                    
                                    if items.isEmpty {
                                        Text("No active listings.")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                            .padding(.horizontal, 20)
                                    } else {
                                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                                            ForEach(items) { item in
                                                InventoryItemCard(item: item)
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                    }
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
                
                // Safety Menu
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
    
    // MARK: - Highlights Section
    
    var highlightsSection: some View {
        VStack(spacing: 24) {
            // 1. Reputation Card
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(String(format: "%.1f", rating))")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(.yellow)
                    HStack(spacing: 2) {
                        ForEach(0..<5) { i in
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(Double(i) < rating ? .yellow : .gray.opacity(0.3))
                        }
                    }
                    Text("\(reviewCount) reviews")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Divider().frame(height: 40).background(Color.white.opacity(0.2))
                
                VStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.largeTitle)
                        .foregroundStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom))
                    
                    Text(rating >= 4.5 ? "Top Rated" : (reviewCount > 5 ? "Reliable" : "New Trader"))
                        .font(.headline).bold()
                        .foregroundStyle(.white)
                    
                    Text("Community Status")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .padding(.horizontal)
            
            // 2. Stats Grid (Gamified)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // ✨ Impact Stat
                    GlassStatPill(
                        icon: "leaf.fill",
                        value: calculateCarbonSaved(count: tradeCount),
                        label: "Impact",
                        color: .green
                    )
                    
                    GlassStatPill(icon: "cube.box.fill", value: "\(items.count)", label: "Items")
                    
                    GlassStatPill(icon: "tag.fill", value: topCategory, label: "Top Category")
                    
                    if profile?.isVerified == true {
                        GlassStatPill(icon: "checkmark.shield.fill", value: "Verified", label: "Identity", color: .cyan)
                    }
                }
                .padding(.horizontal)
            }
            
            // 3. ISO Categories
            VStack(alignment: .leading, spacing: 10) {
                Text("INTERESTED IN")
                    .font(.caption)
                    .fontWeight(.black)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 24)
                
                if let isos = profile?.isoCategories, !isos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(isos, id: \.self) { iso in
                                Text(iso.uppercased())
                                    .font(.caption).bold()
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.cyan.opacity(0.2))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.cyan.opacity(0.5), lineWidth: 1))
                                    .foregroundStyle(.cyan)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                } else {
                    Text("No specific interests listed.")
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 24)
                }
            }
        }
    }
    
    // MARK: - Logic
    
    func loadPublicProfile() {
        isLoading = true
        Task {
            do {
                // Parallel Fetching
                async let pTask = DatabaseService.shared.fetchProfile(userId: userId)
                async let iTask = DatabaseService.shared.fetchUserItems(userId: userId)
                async let rTask = DatabaseService.shared.fetchUserRating(userId: userId)
                async let cTask = DatabaseService.shared.fetchReviewCount(userId: userId)
                async let tTask = DatabaseService.shared.fetchActiveTrades(userId: userId) // ✨ Get Trade Count
                
                let (p, allItems, r, c, activeTrades) = try await (pTask, iTask, rTask, cTask, tTask)
                
                // Calculate Top Category
                let categories = allItems.map { $0.category }
                let counts = categories.reduce(into: [:]) { $0[$1, default: 0] += 1 }
                let top = counts.max(by: { $0.value < $1.value })?.key ?? "None"
                
                await MainActor.run {
                    self.profile = p
                    self.items = allItems
                    self.rating = r
                    self.reviewCount = c
                    self.tradeCount = activeTrades.count
                    self.topCategory = top
                    self.isLoading = false
                }
            } catch {
                print("Error loading profile: \(error)")
                await MainActor.run { isLoading = false }
            }
        }
    }
    
    // ✨ GAMIFICATION HELPERS
    // Copied logic from UserManager to keep consistent visual rules
    
    func calculateLevelTitle(count: Int) -> String {
        switch count {
        case 0...2: return "Novice Swapper"
        case 3...9: return "Eco Trader"
        case 10...24: return "Swap Savant"
        case 25...49: return "Circular Hero"
        default: return "Legendary Trader"
        }
    }
    
    func calculateLevelProgress(count: Int) -> Double {
        let c = Double(count)
        switch count {
        case 0...2: return c / 3.0
        case 3...9: return (c - 3) / 7.0
        case 10...24: return (c - 10) / 15.0
        case 25...49: return (c - 25) / 25.0
        default: return 1.0
        }
    }
    
    func calculateCarbonSaved(count: Int) -> String {
        let kg = Double(count) * 2.5
        return String(format: "%.1f kg", kg)
    }
    
    func submitReport(reason: String) {
        guard let myId = userManager.currentUser?.id else { return }
        Task {
            try? await DatabaseService.shared.reportUser(reporterId: myId, reportedId: userId, reason: reason)
            dismiss()
        }
    }
}

// MARK: - Subviews

struct GlassStatPill: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = .cyan
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.headline).bold()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(width: 100, height: 80)
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
