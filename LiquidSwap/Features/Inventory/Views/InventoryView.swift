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
                            ZStack {
                                Circle()
                                    .strokeBorder(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
                                    .frame(width: 100, height: 100)
                                
                                if let avatarUrl = userManager.currentUser?.avatarUrl {
                                    AsyncImageView(filename: avatarUrl).clipShape(Circle()).frame(width: 94, height: 94)
                                } else {
                                    Image(systemName: "person.circle.fill").resizable().foregroundStyle(.gray).frame(width: 94, height: 94)
                                }
                            }
                            
                            VStack(spacing: 4) {
                                Text(userManager.currentUser?.username ?? "Loading...")
                                    .font(.title2).bold().foregroundStyle(.white)
                                
                                Text(userManager.currentUser?.location ?? "Unknown")
                                    .font(.subheadline).foregroundStyle(.gray)
                            }
                            
                            // NEW: ISO BADGES
                            if let isos = userManager.currentUser?.isoCategories, !isos.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        Text("ISO:")
                                            .font(.caption).bold().foregroundStyle(.cyan)
                                        ForEach(isos, id: \.self) { iso in
                                            Text(iso)
                                                .font(.caption2).bold()
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.white.opacity(0.1))
                                                .cornerRadius(8)
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                Button(action: { showEditProfile = true }) {
                                    Text("Edit Profile").font(.caption).bold().padding(.vertical, 8).padding(.horizontal, 16).background(.ultraThinMaterial).cornerRadius(20).foregroundStyle(.white)
                                }
                                Button(action: { showSettings = true }) {
                                    Image(systemName: "gearshape.fill").font(.caption).padding(8).background(.ultraThinMaterial).clipShape(Circle()).foregroundStyle(.white)
                                }
                            }
                        }
                        .padding(.top, 20)
                        
                        // --- STATS & INVENTORY GRID ---
                        // (Same as before)
                        HStack(spacing: 40) {
                            StatView(number: "\(userManager.userItems.count)", label: "Items")
                            StatView(number: "4.9", label: "Rating")
                            StatView(number: "12", label: "Trades")
                        }
                        .padding(.vertical, 10)
                        
                        Divider().background(Color.white.opacity(0.2))
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Your Inventory (\(userManager.userItems.count)/5)").font(.headline).foregroundStyle(.white)
                                Spacer()
                                if userManager.canAddItem {
                                    Button(action: { showAddItemSheet = true }) {
                                        Image(systemName: "plus.circle.fill").foregroundStyle(.cyan).font(.title)
                                    }
                                } else {
                                    Text("Limit Reached").font(.caption).foregroundStyle(.red)
                                }
                            }
                            .padding(.horizontal)
                            
                            if userManager.isLoading {
                                ProgressView().tint(.cyan).padding(.top, 40)
                            } else if userManager.userItems.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "archivebox").font(.largeTitle).foregroundStyle(.gray)
                                    Text("No items yet").foregroundStyle(.gray)
                                    Button("Add your first item") { showAddItemSheet = true }.font(.caption).foregroundStyle(.cyan)
                                }
                                .frame(maxWidth: .infinity).padding(.top, 40)
                            } else {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                    ForEach(userManager.userItems) { item in
                                        NavigationLink(destination: EditItemView(item: item)) {
                                            InventoryItemCard(item: item)
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
// Include StatView and InventoryItemCard here
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
struct InventoryItemCard: View {
    let item: TradeItem
    var body: some View {
        VStack(alignment: .leading) {
            AsyncImageView(filename: item.imageUrl).frame(height: 120).frame(maxWidth: .infinity).background(Color.gray.opacity(0.2)).cornerRadius(12).clipped()
            Text(item.title).font(.caption).bold().foregroundStyle(.white).lineLimit(1).padding(.top, 4)
            Text(item.condition).font(.caption2).foregroundStyle(.gray)
        }
        .padding(8).background(.ultraThinMaterial).cornerRadius(16)
    }
}
