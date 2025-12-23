import SwiftUI

struct InventoryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userManager = UserManager.shared
    
    @State private var showAddItemSheet = false
    @State private var showEditProfile = false
    @State private var showSettings = false // NEW
    @State private var itemToEdit: TradeItem? = nil
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ZStack {
            LiquidBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // 1. Profile Header
                    VStack(spacing: 16) {
                        ZStack {
                            if let profilePic = userManager.userProfileImage {
                                Image(uiImage: profilePic)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(.cyan.opacity(0.5), lineWidth: 2))
                            } else {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 100, height: 100)
                                    .overlay(Circle().stroke(.cyan.opacity(0.5), lineWidth: 2))
                                
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white)
                            }
                        }
                        
                        VStack(spacing: 6) {
                            HStack(alignment: .center, spacing: 8) {
                                Text(userManager.userName)
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(.white)
                                
                                Button(action: { showEditProfile = true }) {
                                    Image(systemName: "pencil.circle.fill")
                                        .foregroundStyle(.cyan)
                                        .font(.title3)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                            }
                            
                            if !userManager.userLocation.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.caption2)
                                    Text(userManager.userLocation)
                                        .font(.caption)
                                }
                                .foregroundStyle(.white.opacity(0.8))
                            }
                            
                            if !userManager.userBio.isEmpty {
                                Text(userManager.userBio)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                    .lineLimit(2)
                            }
                            
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                Text("\(String(format: "%.1f", userManager.reputationScore)) (\(userManager.tradeCount) Trades)")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.top, 20)
                    
                    Divider().background(.white.opacity(0.3))
                    
                    // 2. My Items
                    VStack(alignment: .leading) {
                        HStack {
                            Text("My Inventory (\(userManager.myItems.count))")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            
                            Button(action: { showAddItemSheet = true }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.cyan)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                        }
                        .padding(.horizontal)
                        
                        if userManager.myItems.isEmpty {
                            Text("You haven't listed any items yet.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                                .padding()
                        } else {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(userManager.myItems) { item in
                                    InventoryCard(item: item)
                                        .contextMenu {
                                            Button {
                                                withAnimation {
                                                    Haptics.shared.playSuccess()
                                                    userManager.completeTrade(for: item)
                                                }
                                            } label: {
                                                Label("Mark as Traded", systemImage: "hand.thumbsup.fill")
                                            }
                                            
                                            Button(role: .destructive) {
                                                withAnimation {
                                                    userManager.deleteItem(item)
                                                }
                                            } label: {
                                                Label("Delete Item", systemImage: "trash")
                                            }
                                            
                                            Button {
                                                itemToEdit = item
                                            } label: {
                                                Label("Edit Details", systemImage: "pencil")
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .bold()
                        .foregroundStyle(.white)
                }
            }
            
            // NEW: Settings Button
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .sheet(isPresented: $showAddItemSheet) {
            AddItemView()
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
        }
        .sheet(item: $itemToEdit) { item in
            EditItemView(item: item)
        }
        // NEW: Settings Sheet
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

// Subview remains same...
struct InventoryCard: View {
    let item: TradeItem
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                if let photo = item.uiImage {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 100)
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.1))
                        .frame(height: 100)
                        .overlay(
                            Image(systemName: item.systemImage)
                                .foregroundStyle(.white.opacity(0.5))
                                .font(.largeTitle)
                        )
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(item.category)
                        .font(.caption)
                        .foregroundStyle(.cyan)
                }
            }
        }
    }
}
