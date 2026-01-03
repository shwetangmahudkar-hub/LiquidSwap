import SwiftUI

struct InventoryView: View {
    @ObservedObject var userManager = UserManager.shared
    
    @State private var showAddItemSheet = false
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showActivityHub = false
    
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
                
                // 2. Main Content
                if userManager.isLoading && userManager.userItems.isEmpty {
                    // Only show full screen loader if we have NO data
                    ProgressView()
                        .tint(.cyan)
                        .scaleEffect(1.5)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) { // ✨ Reduced spacing from 20 to 16
                            
                            // --- TOP BAR ---
                            HStack {
                                Text("Profile")
                                    .appFont(34, weight: .bold)
                                    .foregroundStyle(.white)
                                    .shadow(color: .cyan.opacity(0.5), radius: 10)
                                
                                Spacer()
                                
                                // Settings Button (Glass)
                                Button(action: { showSettings = true }) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.white.opacity(0.8))
                                        .frame(width: 44, height: 44)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            
                            // --- HERO BENTO CARD (Compact) ---
                            HStack(spacing: 16) {
                                // Avatar with Level Ring
                                ZStack {
                                    Circle()
                                        .stroke(Color.white.opacity(0.1), lineWidth: 3)
                                        .frame(width: 76, height: 76) // ✨ Reduced from 88
                                    
                                    Circle()
                                        .trim(from: 0, to: userManager.levelProgress)
                                        .stroke(
                                            AngularGradient(colors: [.cyan, .purple, .cyan], center: .center),
                                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                        )
                                        .rotationEffect(.degrees(-90))
                                        .frame(width: 76, height: 76)
                                        .shadow(color: .cyan.opacity(0.5), radius: 8)
                                    
                                    if let avatarUrl = userManager.currentUser?.avatarUrl {
                                        AsyncImageView(filename: avatarUrl)
                                            .scaledToFill()
                                            .frame(width: 68, height: 68)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .foregroundStyle(.gray)
                                            .frame(width: 68, height: 68)
                                    }
                                }
                                
                                // User Info & Rank
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(userManager.currentUser?.username ?? "Loading...")
                                        .appFont(20, weight: .bold) // ✨ Reduced from 22
                                        .foregroundStyle(.white)
                                    
                                    Text(userManager.currentLevelTitle.uppercased())
                                        .appFont(10, weight: .black)
                                        .foregroundStyle(.cyan)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.cyan.opacity(0.1))
                                        .clipShape(Capsule())
                                    
                                    Button(action: { showEditProfile = true }) {
                                        HStack(spacing: 4) {
                                            Text("Edit Profile")
                                            Image(systemName: "pencil")
                                                .font(.caption)
                                        }
                                        .appFont(12, weight: .semibold)
                                        .foregroundStyle(.white.opacity(0.6))
                                        .padding(.top, 2)
                                    }
                                }
                                Spacer()
                            }
                            .padding(20) // ✨ Reduced padding
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.15), lineWidth: 1))
                            .padding(.horizontal, 16)
                            
                            // --- STATS ROW ---
                            HStack(spacing: 12) {
                                GlassStat(icon: "leaf.fill", value: userManager.carbonSaved, label: "Impact", color: .green)
                                GlassStat(icon: "star.fill", value: userManager.userRating == 0 ? "-" : String(format: "%.1f", userManager.userRating), label: "Rating", color: .yellow)
                                GlassStat(icon: "arrow.triangle.2.circlepath", value: "\(userManager.completedTradeCount)", label: "Trades", color: .cyan)
                            }
                            .padding(.horizontal, 16)
                            
                            // --- ACTIVITY HUB BANNER (Compact) ---
                            Button(action: { showActivityHub = true }) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 36, height: 36) // ✨ Reduced from 44
                                        
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Activity Hub")
                                            .appFont(14, weight: .bold)
                                            .foregroundColor(.white)
                                        
                                        Text("See who liked your items")
                                            .appFont(12)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    Spacer()
                                    
                                    // Notification Badge (Mock logic, can be connected to NotificationManager)
                                    // Circle().fill(.red).frame(width: 8, height: 8)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption.bold())
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .padding(12) // ✨ Compact padding
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }
                            .padding(.horizontal, 16)
                            
                            // --- INVENTORY GRID ---
                            HStack(alignment: .bottom) {
                                Text("Inventory")
                                    .appFont(18, weight: .bold)
                                    .foregroundStyle(.white)
                                
                                Text("(\(userManager.userItems.count)/20)")
                                    .appFont(14)
                                    .foregroundStyle(.white.opacity(0.5))
                                    .padding(.bottom, 2)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                            
                            if userManager.userItems.isEmpty {
                                EmptyInventoryState { showAddItemSheet = true }
                                    .padding(.top, 20)
                            } else {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                    // Add Item Card
                                    if userManager.canAddItem {
                                        Button(action: { showAddItemSheet = true }) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 24)
                                                    .fill(Color.white.opacity(0.03))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 24)
                                                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [8]))
                                                            .foregroundStyle(.cyan.opacity(0.4))
                                                    )
                                                
                                                VStack(spacing: 8) {
                                                    Image(systemName: "plus")
                                                        .font(.system(size: 24, weight: .light))
                                                        .foregroundStyle(.cyan)
                                                    Text("Add Item")
                                                        .appFont(12, weight: .bold)
                                                        .foregroundStyle(.cyan)
                                                }
                                            }
                                            .frame(height: 200)
                                        }
                                    }
                                    
                                    // Items
                                    ForEach(userManager.userItems) { item in
                                        NavigationLink(destination: EditItemView(item: item)) {
                                            InventoryItemCard(item: item)
                                                .frame(height: 200)
                                        }
                                        .buttonStyle(.plain) // Prevent blue flash on tap
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 120)
                            }
                        }
                    }
                    .refreshable {
                        // ✨ Native Pull-to-Refresh
                        await userManager.loadUserData()
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) { appearAnimation = true }
                // Optional: Check if we need to reload logic here
            }
            .fullScreenCover(isPresented: $showAddItemSheet) { AddItemView(isPresented: $showAddItemSheet) }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showEditProfile) { EditProfileView() }
            .navigationDestination(isPresented: $showActivityHub) { ActivityHubView() }
        }
    }
}

struct GlassStat: View {
    let icon: String
    let value: String
    let label: String
    var color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color.gradient)
                .padding(.bottom, 2)
            
            Text(value)
                .appFont(16, weight: .bold)
                .foregroundStyle(.white)
            
            Text(label.uppercased())
                .appFont(9, weight: .bold)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

struct EmptyInventoryState: View {
    var onAdd: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.white.opacity(0.05)).frame(width: 100, height: 100)
                Image(systemName: "cube.transparent")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.top, 10)
            
            Text("Your inventory is empty.")
                .appFont(16, weight: .medium)
                .foregroundStyle(.white.opacity(0.6))
            
            Button("List Your First Item", action: onAdd)
                .buttonStyle(PrimaryButtonStyle())
                .frame(width: 220)
        }
        .frame(minHeight: 250)
    }
}
