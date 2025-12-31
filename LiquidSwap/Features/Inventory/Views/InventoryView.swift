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
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // --- TOP BAR ---
                        HStack {
                            Text("Profile")
                                .appFont(34, weight: .bold)
                                .foregroundStyle(.white)
                                .shadow(color: .cyan.opacity(0.5), radius: 10)
                            
                            Spacer()
                            
                            // Settings Button
                            Button(action: { showSettings = true }) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                                    .frame(width: 50, height: 50)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        
                        // --- HERO BENTO CARD ---
                        VStack(spacing: 20) {
                            HStack(spacing: 20) {
                                // Avatar with Level Ring
                                ZStack {
                                    Circle()
                                        .stroke(Color.white.opacity(0.1), lineWidth: 4)
                                        .frame(width: 88, height: 88)
                                    
                                    Circle()
                                        .trim(from: 0, to: userManager.levelProgress)
                                        .stroke(
                                            AngularGradient(colors: [.cyan, .purple, .cyan], center: .center),
                                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                        )
                                        .rotationEffect(.degrees(-90))
                                        .frame(width: 88, height: 88)
                                        .shadow(color: .cyan.opacity(0.5), radius: 10)
                                    
                                    if let avatarUrl = userManager.currentUser?.avatarUrl {
                                        AsyncImageView(filename: avatarUrl)
                                            .clipShape(Circle())
                                            .frame(width: 80, height: 80)
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .foregroundStyle(.gray)
                                            .frame(width: 80, height: 80)
                                    }
                                }
                                
                                // User Info & Rank
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(userManager.currentUser?.username ?? "Loading...")
                                        .appFont(22, weight: .bold)
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
                                            Image(systemName: "chevron.right")
                                        }
                                        .appFont(12, weight: .bold)
                                        .foregroundStyle(.white.opacity(0.6))
                                    }
                                    .padding(.top, 4)
                                }
                                Spacer()
                            }
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 32).stroke(Color.white.opacity(0.15), lineWidth: 1))
                        .padding(.horizontal, 16)
                        
                        // --- STATS ROW ---
                        HStack(spacing: 12) {
                            GlassStat(icon: "leaf.fill", value: userManager.carbonSaved, label: "Impact", color: .green)
                            GlassStat(icon: "star.fill", value: userManager.userRating == 0 ? "-" : String(format: "%.1f", userManager.userRating), label: "Rating", color: .yellow)
                            GlassStat(icon: "arrow.triangle.2.circlepath", value: "\(userManager.completedTradeCount)", label: "Trades", color: .cyan)
                        }
                        .padding(.horizontal, 16)
                        
                        // --- ACTIVITY HUB BANNER ---
                        Button(action: { showActivityHub = true }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("Activity Hub")
                                            .appFont(16, weight: .bold)
                                            .foregroundColor(.white)
                                        
                                        Text("PREVIEW")
                                            .appFont(8, weight: .black)
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.yellow)
                                            .clipShape(Capsule())
                                    }
                                    
                                    Text("See who liked your items")
                                        .appFont(12)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.3))
                            }
                            .padding(16)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                        .padding(.horizontal, 16)
                        
                        // --- INVENTORY GRID ---
                        HStack(alignment: .bottom) {
                            Text("Inventory")
                                .appFont(20, weight: .bold)
                                .foregroundStyle(.white)
                            
                            Text("(\(userManager.userItems.count)/20)")
                                .appFont(14)
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.bottom, 2)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        
                        if userManager.isLoading {
                            ProgressView().tint(.cyan).padding(50)
                        } else if userManager.userItems.isEmpty {
                            EmptyInventoryState { showAddItemSheet = true }
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                if userManager.canAddItem {
                                    Button(action: { showAddItemSheet = true }) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 24)
                                                .fill(Color.white.opacity(0.05))
                                                .overlay(RoundedRectangle(cornerRadius: 24).stroke(style: StrokeStyle(lineWidth: 2, dash: [10])).foregroundStyle(.cyan.opacity(0.5)))
                                            
                                            VStack(spacing: 8) {
                                                Image(systemName: "plus").appFont(30, weight: .light).foregroundStyle(.cyan)
                                                Text("Add Item").appFont(12, weight: .bold).foregroundStyle(.cyan)
                                            }
                                        }
                                        .frame(height: 200)
                                    }
                                }
                                
                                ForEach(userManager.userItems) { item in
                                    NavigationLink(destination: EditItemView(item: item)) {
                                        InventoryItemCard(item: item)
                                            .frame(height: 200)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 120)
                        }
                    }
                }
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : 20)
            }
            .navigationBarHidden(true)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) { appearAnimation = true }
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
            Image(systemName: icon).appFont(20).foregroundStyle(color.gradient).padding(.bottom, 4)
            Text(value).appFont(18, weight: .bold).foregroundStyle(.white)
            Text(label.uppercased()).appFont(10, weight: .bold).foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

struct EmptyInventoryState: View {
    var onAdd: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(Color.white.opacity(0.05)).frame(width: 120, height: 120)
                Image(systemName: "cube.transparent").font(.system(size: 50)).foregroundStyle(.white.opacity(0.3))
            }
            Text("Your inventory is empty.").appFont(18, weight: .medium).foregroundStyle(.white.opacity(0.6))
            
            Button("List Your First Item", action: onAdd)
                .buttonStyle(PrimaryButtonStyle())
                .frame(width: 240)
            Spacer()
        }
        .padding(.top, 40)
    }
}
