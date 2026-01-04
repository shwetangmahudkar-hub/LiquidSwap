import SwiftUI

struct InventoryView: View {
    @ObservedObject var userManager = UserManager.shared
    
    // Sheet States
    @State private var showAddItemSheet = false
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showActivityHub = false
    @State private var selectedItem: TradeItem?
    
    // Animation State
    @State private var appearAnimation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. Deep Space Background
                Color.black.ignoresSafeArea()
                LiquidBackground()
                    .opacity(0.6)
                    .blur(radius: 20)
                    .ignoresSafeArea()
                
                // 2. Main Content
                if userManager.isLoading && userManager.userItems.isEmpty {
                    ProgressView()
                        .tint(.cyan)
                        .scaleEffect(1.5)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            
                            // --- PROFILE HEADER ---
                            ProfileHeader(user: userManager.currentUser)
                                .padding(.top, 10)
                            
                            // --- LEVEL & XP CARD ---
                            LevelProgressCard(
                                level: userManager.currentLevel,
                                xp: userManager.currentUser?.xp ?? 0,
                                progress: userManager.levelProgress
                            )
                            
                            // --- STATS ROW ---
                            StatsRow(
                                trustScore: userManager.trustScore,
                                tradeCount: userManager.completedTradeCount,
                                streak: userManager.currentStreak
                            )
                            
                            // --- ACTION BUTTONS ---
                            ActionButtonsRow(
                                onEdit: { showEditProfile = true },
                                onActivity: { showActivityHub = true },
                                onSettings: { showSettings = true }
                            )
                            
                            // --- INVENTORY GRID ---
                            HStack {
                                Text("My Listings")
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                                
                                Spacer()
                                
                                Text("\(userManager.userItems.count) items")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 4)
                            
                            if userManager.userItems.isEmpty {
                                EmptyInventoryState {
                                    showAddItemSheet = true
                                }
                            } else {
                                InventoryGrid(items: userManager.userItems) { item in
                                    selectedItem = item
                                }
                            }
                            
                            // Bottom padding for TabBar and FAB
                            Color.clear.frame(height: 100)
                        }
                        .padding(.horizontal, 20)
                    }
                    .refreshable {
                        await userManager.loadUserData()
                    }
                }
                
                // 3. Floating Action Button (Accessible One-Handed)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            Haptics.shared.playMedium()
                            showAddItemSheet = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(width: 60, height: 60)
                                .background(Color.cyan.gradient)
                                .clipShape(Circle())
                                .shadow(color: .cyan.opacity(0.5), radius: 10, y: 5)
                                .overlay(
                                    Circle()
                                        .stroke(.white.opacity(0.5), lineWidth: 1)
                                )
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 110) // Clear TabBar
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddItemSheet) {
                // ✅ FIX: Passed the required binding to AddItemView
                AddItemView(isPresented: $showAddItemSheet)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showActivityHub) {
                ActivityHubView()
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $selectedItem) { item in
                EditItemView(item: item)
                    .presentationDetents([.large])
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.8)) {
                appearAnimation = true
            }
            // Ensure fresh data on appear
            Task { await userManager.loadUserData() }
        }
    }
}

// MARK: - Subcomponents

struct ProfileHeader: View {
    let user: UserProfile?
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar with Border
            ZStack {
                Circle()
                    .strokeBorder(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
                    .frame(width: 88, height: 88)
                
                AsyncImageView(filename: user?.avatarUrl)
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(user?.username ?? "Trader")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    if user?.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.cyan)
                            .font(.subheadline)
                    }
                }
                
                Text(user?.bio.isEmpty == false ? user!.bio : "Ready to trade on Swappr!")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
                
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                    Text(user?.location ?? "Unknown Location")
                }
                .font(.caption)
                .foregroundStyle(.gray)
            }
            
            Spacer()
        }
    }
}

struct LevelProgressCard: View {
    let level: UserLevel
    let xp: Int
    let progress: Double // 0.0 to 1.0
    
    var body: some View {
        HStack(spacing: 16) {
            // Level Icon
            ZStack {
                Circle()
                    .fill(level.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: level.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(level.color)
            }
            
            // Progress Info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(level.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Text("\(xp) XP")
                        .font(.caption.bold())
                        .foregroundStyle(level.color)
                }
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                        
                        Capsule()
                            .fill(LinearGradient(colors: [level.color, level.color.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, geo.size.width * progress))
                            .animation(.spring(response: 0.6), value: progress)
                    }
                }
                .frame(height: 8)
                
                Text("Level \(level.tier)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct StatsRow: View {
    let trustScore: Int
    let tradeCount: Int
    let streak: Int
    
    var body: some View {
        HStack(spacing: 12) {
            StatCard(label: "Trust Score", value: "\(trustScore)", icon: "shield.fill", color: .green)
            StatCard(label: "Trades", value: "\(tradeCount)", icon: "arrow.triangle.2.circlepath", color: .cyan)
            StatCard(label: "Day Streak", value: "\(streak)", icon: "flame.fill", color: .orange)
        }
    }
}

struct StatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color.gradient)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct ActionButtonsRow: View {
    var onEdit: () -> Void
    var onActivity: () -> Void
    var onSettings: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            GlassButton(icon: "pencil", label: "Edit Profile", action: onEdit)
            GlassButton(icon: "bell.badge", label: "Activity", action: onActivity)
            GlassButton(icon: "gearshape", label: "Settings", action: onSettings)
        }
    }
}

struct GlassButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            Haptics.shared.playLight()
            action()
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct InventoryGrid: View {
    let items: [TradeItem]
    let onSelect: (TradeItem) -> Void
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(items) { item in
                InventoryItemCard(item: item)
                    .onTapGesture {
                        Haptics.shared.playLight()
                        onSelect(item)
                    }
            }
        }
        .padding(.bottom, 20)
    }
}

struct EmptyInventoryState: View {
    var onAdd: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.white.opacity(0.05))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "cube.transparent")
                    .font(.system(size: 50))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.top, 40)
            
            Text("Your inventory is empty")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
            
            Text("Add items to start trading and earning XP!")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: onAdd) {
                Text("List Your First Item")
                    .fontWeight(.bold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.cyan)
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
