import SwiftUI

struct MainTabView: View {
    // 2 is the center "Swap" tab
    @State private var selectedTab = 2
    
    @StateObject var tabManager = TabBarManager.shared
    
    var body: some View {
        ZStack {
            // 1. The Content Layer
            Group {
                switch selectedTab {
                case 0: DiscoverView()      // 🔍 Discover (Map)
                case 1: TradesView()        // 📦 Trades (Offers)
                case 2: FeedView()          // 🔥 Swap (Center)
                case 3: ChatsListView()     // 💬 Chat (Active)
                case 4: InventoryView()     // 👤 Profile
                default: FeedView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 2. The Floating Glass Pill
            if tabManager.isVisible {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 0) {
                        // 1. Discover
                        TabButton(icon: "map.fill", label: "Map", isSelected: selectedTab == 0) { selectedTab = 0 }
                        Spacer()
                        
                        // 2. Trades
                        TabButton(icon: "arrow.triangle.2.circlepath", label: "Trades", isSelected: selectedTab == 1) { selectedTab = 1 }
                        Spacer()
                        
                        // 3. Swap (Center)
                        TabButton(icon: "flame.fill", label: "Swap", isSelected: selectedTab == 2) { selectedTab = 2 }
                        Spacer()
                        
                        // 4. Chat
                        TabButton(icon: "bubble.left.and.bubble.right.fill", label: "Chat", isSelected: selectedTab == 3) { selectedTab = 3 }
                        Spacer()
                        
                        // 5. Profile
                        TabButton(icon: "person.fill", label: "Profile", isSelected: selectedTab == 4) { selectedTab = 4 }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    // 🍬 THE PILL SHAPE
                    .clipShape(Capsule(style: .continuous))
                    // Glass Edge Light
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.6), // Bright top-left reflection
                                        .white.opacity(0.1),
                                        .white.opacity(0.05) // Dark bottom-right
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    // Soft Depth Shadow
                    .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
                    
                    // 🛠️ FLOAT LAYOUT
                    .padding(.horizontal, 20)
                    .padding(.bottom, 0)
                    
                    // ✨ NEW: Moved 15 points lower (10 + 10)
                    .offset(y: 20)
                }
                .zIndex(10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            Haptics.shared.playLight()
            action()
        }) {
            VStack(spacing: 4) {
                // Icon Container (Fixed Height)
                ZStack {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? .cyan : .gray)
                        .scaleEffect(isSelected ? 1.25 : 1.0)
                        .animation(.spring(response: 0.3), value: isSelected)
                }
                .frame(height: 26)
                
                Text(label)
                    .font(.caption2)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundStyle(isSelected ? .white : .gray.opacity(0.8))
                    .fixedSize()
            }
            .frame(width: 50)
        }
    }
}
