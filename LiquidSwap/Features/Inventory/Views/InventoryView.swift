import SwiftUI

struct InventoryView: View {
    @ObservedObject var userManager = UserManager.shared
    
    @State private var showAddItemSheet = false
    @State private var showSettings = false
    @State private var showEditProfile = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // --- HEADER ---
                        VStack(spacing: 16) {
                            // Avatar Ring
                            ZStack {
                                Circle()
                                    .strokeBorder(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
                                    .frame(width: 100, height: 100)
                                
                                if let avatarUrl = userManager.currentUser?.avatarUrl {
                                    AsyncImageView(filename: avatarUrl)
                                        .clipShape(Circle())
                                        .frame(width: 94, height: 94)
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .foregroundStyle(.gray)
                                        .frame(width: 94, height: 94)
                                }
                            }
                            
                            // Name & Location
                            VStack(spacing: 4) {
                                Text(userManager.currentUser?.username ?? "Loading...")
                                    .font(.title2).bold()
                                    .foregroundStyle(.white)
                                
                                Text(userManager.currentUser?.location ?? "Unknown")
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
                            }
                            
                            // ISO SECTION
                            VStack(spacing: 8) {
                                Text("In Search Of (ISO)")
                                    .font(.caption)
                                    .bold()
                                    .foregroundStyle(.cyan)
                                    .textCase(.uppercase)
                                
                                Button(action: { showEditProfile = true }) {
                                    if let isos = userManager.currentUser?.isoCategories, !isos.isEmpty {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack {
                                                ForEach(isos, id: \.self) { iso in
                                                    Text(iso)
                                                        .font(.caption2).bold()
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 6)
                                                        .background(Color.white.opacity(0.1))
                                                        .cornerRadius(12)
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                        }
                                        .frame(height: 30)
                                    } else {
                                        HStack {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Add Interests (Electronics, Fashion...)")
                                        }
                                        .font(.caption)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                                .foregroundStyle(.white.opacity(0.3))
                                        )
                                        .foregroundStyle(.white.opacity(0.7))
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // Action Buttons
                            HStack(spacing: 12) {
                                Button(action: { showEditProfile = true }) {
                                    Text("Edit Profile")
                                        .font(.caption).bold()
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 16)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(20)
                                        .foregroundStyle(.white)
                                }
                                Button(action: { showSettings = true }) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.caption)
                                        .padding(8)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .padding(.top, 20)
                        
                        // --- STATS ---
                        HStack(spacing: 40) {
                            StatView(number: "\(userManager.userItems.count)", label: "Items")
                            StatView(
                                number: userManager.userRating == 0 ? "-" : String(format: "%.1f", userManager.userRating),
                                label: "Rating (\(userManager.userReviewCount))"
                            )
                            StatView(number: "12", label: "Trades")
                        }
                        .padding(.vertical, 10)
                        
                        Divider().background(Color.white.opacity(0.2))
                        
                        // --- INVENTORY ---
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Your Inventory (\(userManager.userItems.count)/5)")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Spacer()
                                if userManager.canAddItem {
                                    Button(action: { showAddItemSheet = true }) {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(.cyan)
                                            .font(.title)
                                    }
                                } else {
                                    Text("Limit Reached")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                            .padding(.horizontal)
                            
                            if userManager.isLoading {
                                ProgressView().tint(.cyan)
                                    .padding(.top, 40)
                                    .frame(maxWidth: .infinity)
                            } else if userManager.userItems.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "archivebox")
                                        .font(.largeTitle)
                                        .foregroundStyle(.gray)
                                    Text("No items yet")
                                        .foregroundStyle(.gray)
                                    Button("Add your first item") { showAddItemSheet = true }
                                        .font(.caption)
                                        .foregroundStyle(.cyan)
                                }
                                .frame(maxWidth: .infinity).padding(.top, 40)
                            } else {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                    ForEach(userManager.userItems) { item in
                                        // 🛠️ RESTORED: Navigation to Edit Screen
                                        NavigationLink(destination: EditItemView(item: item)) {
                                            InventoryItemCard(item: item)
                                                // ✨ CONTEXT MENU: Long Press to Delete
                                                .contextMenu {
                                                    Button(role: .destructive) {
                                                        Task {
                                                            do {
                                                                try await userManager.deleteItem(item: item)
                                                                Haptics.shared.playSuccess()
                                                            } catch {
                                                                Haptics.shared.playError()
                                                            }
                                                        }
                                                    } label: {
                                                        Label("Delete Item", systemImage: "trash")
                                                    }
                                                }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddItemSheet) { AddItemView(isPresented: $showAddItemSheet) }
            .sheet(isPresented: $showSettings) { ProfileSettingsView(showSettings: $showSettings) }
            .sheet(isPresented: $showEditProfile) { EditProfileView() }
        }
    }
}

// SUBVIEWS

struct StatView: View {
    let number: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(number).font(.title3).bold().foregroundStyle(.white)
            Text(label).font(.caption).foregroundStyle(.gray)
        }
    }
}


