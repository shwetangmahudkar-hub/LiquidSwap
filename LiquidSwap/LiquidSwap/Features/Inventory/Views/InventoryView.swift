import SwiftUI

struct InventoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var userManager = UserManager.shared
    
    // Sheet States
    @State private var showAddItemSheet = false
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showActivityHub = false
    @State private var selectedItem: TradeItem?
    
    // Animation State
    @State private var appearAnimation = false
    
    // Adaptive colors
    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. Background
                LiquidBackground()
                    .ignoresSafeArea()
                
                // 2. Main Content
                if userManager.isLoading && userManager.userItems.isEmpty {
                    ProgressView()
                        .tint(.cyan)
                        .scaleEffect(1.5)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: DS.Spacing.section) {
                            
                            // --- PROFILE HEADER ---
                            ProfileHeader(user: userManager.currentUser)
                                .padding(.top, DS.Spacing.topInset)
                            
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
                                    .appFont(DS.Font.sectionHeader, weight: .bold)
                                    .foregroundStyle(colors.primaryText)
                                
                                Spacer()
                                
                                Text("\(userManager.userItems.count) items")
                                    .appFont(DS.Font.caption)
                                    .foregroundStyle(colors.tertiaryText)
                            }
                            
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
                            Color.clear.frame(height: DS.Spacing.bottomTab + 30)
                        }
                        .padding(.horizontal, DS.Spacing.edge)
                    }
                    .refreshable {
                        await userManager.loadUserData()
                    }
                }
                
                // 3. Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            Haptics.shared.playMedium()
                            showAddItemSheet = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(width: 54, height: 54)
                                .background(Color.cyan.gradient)
                                .clipShape(Circle())
                                .shadow(color: .cyan.opacity(0.5), radius: 8, y: 4)
                                .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))
                        }
                        .padding(.trailing, DS.Spacing.edge)
                        .padding(.bottom, DS.Spacing.bottomTab + 20)
                    }
                }
            }
            .navigationBarHidden(true)
            // Full screen sheets that blend with Dynamic Island
            .sheet(isPresented: $showAddItemSheet) {
                AddItemView(isPresented: $showAddItemSheet)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(38)
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(38)
            }
            .sheet(isPresented: $showActivityHub) {
                ActivityHubView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(38)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(38)
            }
            .sheet(item: $selectedItem) { item in
                EditItemView(item: item)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(38)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.8)) {
                appearAnimation = true
            }
            Task { await userManager.loadUserData() }
        }
    }
}

// MARK: - Subcomponents

struct ProfileHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let user: UserProfile?
    
    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar with Border
            ZStack {
                Circle()
                    .strokeBorder(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2.5)
                    .frame(width: DS.Size.avatarLarge + 6, height: DS.Size.avatarLarge + 6)
                
                AsyncImageView(filename: user?.avatarUrl)
                    .scaledToFill()
                    .frame(width: DS.Size.avatarLarge, height: DS.Size.avatarLarge)
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(user?.username ?? "Trader")
                        .appFont(DS.Font.screenTitle - 4, weight: .bold)
                        .foregroundStyle(colors.primaryText)
                    
                    if user?.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.cyan)
                            .font(.caption)
                    }
                }
                
                Text(user?.bio.isEmpty == false ? user!.bio : "Ready to trade on Swappr!")
                    .appFont(DS.Font.caption)
                    .foregroundStyle(colors.secondaryText)
                    .lineLimit(2)
                
                HStack(spacing: 3) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 9))
                    Text(user?.location ?? "Unknown Location")
                        .appFont(DS.Font.small)
                }
                .foregroundStyle(colors.tertiaryText)
            }
            
            Spacer()
        }
    }
}

struct LevelProgressCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let level: UserLevel
    let xp: Int
    let progress: Double
    
    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Level Icon
            ZStack {
                Circle()
                    .fill(level.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: level.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(level.color)
            }
            
            // Progress Info
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(level.title)
                        .appFont(DS.Font.cardTitle, weight: .semibold)
                        .foregroundStyle(colors.primaryText)
                    
                    Spacer()
                    
                    Text("\(xp) XP")
                        .appFont(DS.Font.small, weight: .bold)
                        .foregroundStyle(level.color)
                }
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(colors.cardBackground)
                        
                        Capsule()
                            .fill(LinearGradient(colors: [level.color, level.color.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, geo.size.width * progress))
                            .animation(.spring(response: 0.6), value: progress)
                    }
                }
                .frame(height: 6)
                
                Text("Level \(level.tier)")
                    .appFont(DS.Font.tiny)
                    .foregroundStyle(colors.tertiaryText)
            }
        }
        .padding(DS.Spacing.cardPadding)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.medium)
                .stroke(colors.border, lineWidth: 1)
        )
    }
}

struct StatsRow: View {
    let trustScore: Int
    let tradeCount: Int
    let streak: Int
    
    var body: some View {
        HStack(spacing: DS.Spacing.card) {
            StatCard(label: "Trust", value: "\(trustScore)", icon: "shield.fill", color: .green)
            StatCard(label: "Trades", value: "\(tradeCount)", icon: "arrow.triangle.2.circlepath", color: .cyan)
            StatCard(label: "Streak", value: "\(streak)", icon: "flame.fill", color: .orange)
        }
    }
}

struct StatCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color.gradient)
            
            Text(value)
                .appFont(DS.Font.cardTitle, weight: .bold)
                .foregroundStyle(colors.primaryText)
            
            Text(label.uppercased())
                .appFont(DS.Font.tiny, weight: .bold)
                .foregroundStyle(colors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.medium)
                .stroke(colors.border, lineWidth: 1)
        )
    }
}

struct ActionButtonsRow: View {
    var onEdit: () -> Void
    var onActivity: () -> Void
    var onSettings: () -> Void
    
    var body: some View {
        HStack(spacing: DS.Spacing.card) {
            GlassActionButton(icon: "pencil", label: "Edit", action: onEdit)
            GlassActionButton(icon: "bell.badge", label: "Activity", action: onActivity)
            GlassActionButton(icon: "gearshape", label: "Settings", action: onSettings)
        }
    }
}

struct GlassActionButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let icon: String
    let label: String
    let action: () -> Void
    
    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }
    
    var body: some View {
        Button(action: {
            Haptics.shared.playLight()
            action()
        }) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(colors.primaryText)
                
                Text(label)
                    .appFont(DS.Font.small, weight: .medium)
                    .foregroundStyle(colors.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(colors.buttonBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.small)
                    .stroke(colors.border, lineWidth: 1)
            )
        }
    }
}

struct InventoryGrid: View {
    let items: [TradeItem]
    let onSelect: (TradeItem) -> Void
    
    let columns = [
        GridItem(.flexible(), spacing: DS.Spacing.card),
        GridItem(.flexible(), spacing: DS.Spacing.card)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: DS.Spacing.card) {
            ForEach(items) { item in
                InventoryItemCard(item: item)
                    .onTapGesture {
                        Haptics.shared.playLight()
                        onSelect(item)
                    }
            }
        }
    }
}

struct EmptyInventoryState: View {
    @Environment(\.colorScheme) private var colorScheme
    var onAdd: () -> Void
    
    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }
    
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(colors.cardBackground)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "cube.transparent")
                    .font(.system(size: 40))
                    .foregroundStyle(colors.tertiaryText)
            }
            .padding(.top, 24)
            
            Text("Your inventory is empty")
                .appFont(DS.Font.cardTitle, weight: .semibold)
                .foregroundStyle(colors.secondaryText)
            
            Text("Add items to start trading and earning XP!")
                .appFont(DS.Font.caption)
                .foregroundStyle(colors.tertiaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.edge)
            
            Button(action: onAdd) {
                Text("List Your First Item")
                    .appFont(DS.Font.body, weight: .bold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.cyan)
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
            }
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.large)
                .stroke(colors.border, lineWidth: 1)
        )
    }
}
