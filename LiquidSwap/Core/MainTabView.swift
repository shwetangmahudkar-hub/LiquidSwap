import SwiftUI

struct MainTabView: View {
    // 2 is the center "Swap" tab
    @State private var selectedTab = 2
    
    @StateObject var tabManager = TabBarManager.shared
    
    // ✨ Timer for Auto-Hide
    @State private var inactivityTimer: Timer?
    
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
            // ✨ Detects ANY touch/drag to keep the bar alive
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        resetInactivityTimer()
                    }
            )
            
            // 2. The Floating Glass Pill (Visible State)
            if tabManager.isVisible {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 0) {
                        // 1. Discover
                        TabButton(icon: "map.fill", label: "Map", isSelected: selectedTab == 0) {
                            selectedTab = 0
                            resetInactivityTimer()
                        }
                        Spacer()
                        
                        // 2. Trades
                        TabButton(icon: "arrow.triangle.2.circlepath", label: "Trades", isSelected: selectedTab == 1) {
                            selectedTab = 1
                            resetInactivityTimer()
                        }
                        Spacer()
                        
                        // 3. Swap (Center)
                        TabButton(icon: "flame.fill", label: "Swap", isSelected: selectedTab == 2) {
                            selectedTab = 2
                            resetInactivityTimer()
                        }
                        Spacer()
                        
                        // 4. Chat
                        TabButton(icon: "bubble.left.and.bubble.right.fill", label: "Chat", isSelected: selectedTab == 3) {
                            selectedTab = 3
                            resetInactivityTimer()
                        }
                        Spacer()
                        
                        // 5. Profile
                        TabButton(icon: "person.fill", label: "Profile", isSelected: selectedTab == 4) {
                            selectedTab = 4
                            resetInactivityTimer()
                        }
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
                    .padding(.bottom, 15) // Raised for iPhone SE visibility
                }
                .zIndex(10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                // ✨ Detect taps on the bar itself
                .onTapGesture {
                    resetInactivityTimer()
                }
            } else {
                // ✨ NEW: Invisible "Corner Touch Zones" to bring the bar back
                VStack {
                    Spacer()
                    
                    HStack {
                        // 👈 LEFT CORNER ZONE
                        Color.clear
                            .contentShape(Rectangle()) // Makes transparent color clickable
                            .frame(width: 80, height: 80) // Square touch area
                            .onTapGesture {
                                Haptics.shared.playLight()
                                tabManager.show()
                                resetInactivityTimer()
                            }
                        
                        Spacer() // 👐 Open Center (Pass-through for map/feed)
                        
                        // 👉 RIGHT CORNER ZONE
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(width: 80, height: 80)
                            .onTapGesture {
                                Haptics.shared.playLight()
                                tabManager.show()
                                resetInactivityTimer()
                            }
                    }
                }
                .zIndex(9) // Sits above content but below where tab bar would be
            }
        }
        .onAppear {
            resetInactivityTimer()
        }
    }
    
    // MARK: - Timer Logic
    
    func resetInactivityTimer() {
        // Cancel existing timer
        inactivityTimer?.invalidate()
        
        // Start new 5-second timer
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            Task { @MainActor in
                if tabManager.isVisible {
                    tabManager.hide()
                }
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
