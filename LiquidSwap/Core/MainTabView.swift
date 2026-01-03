import SwiftUI
import Combine

struct MainTabView: View {
    // 2 is the center "Swappr" tab
    @State private var selectedTab = 2
    
    @StateObject var tabManager = TabBarManager.shared
    
    // Auto-Hide Timer
    @State private var inactivityTimer: Timer?
    
    // Keyboard State
    @State private var isKeyboardVisible = false
    
    var body: some View {
        ZStack {
            // 1. The Content Layer
            Group {
                switch selectedTab {
                case 0: DiscoverView()      // 🔍 Map
                case 1: TradesView()        // 📦 Offers
                case 2: FeedView()          // 🔥 Swappr (Center)
                case 3: ChatsListView()     // 💬 Chat
                case 4: InventoryView()     // 👤 Profile
                default: FeedView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 2. Corner Triggers (Only active when bar is HIDDEN)
            if !tabManager.isVisible && !isKeyboardVisible {
                VStack {
                    Spacer()
                    HStack {
                        // Left Corner Trigger
                        Color.black.opacity(0.001)
                            .frame(width: 80, height: 80)
                            .contentShape(Rectangle())
                            .onTapGesture { showTabBar() }
                        
                        Spacer()
                        
                        // Right Corner Trigger
                        Color.black.opacity(0.001)
                            .frame(width: 80, height: 80)
                            .contentShape(Rectangle())
                            .onTapGesture { showTabBar() }
                    }
                }
                .ignoresSafeArea()
            }
            
            // 3. The Floating Glass Pill (Visible State)
            if tabManager.isVisible && !isKeyboardVisible {
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
                        TabButton(icon: "box.truck.fill", label: "Offers", isSelected: selectedTab == 1) {
                            selectedTab = 1
                            resetInactivityTimer()
                        }
                        
                        Spacer()
                        
                        // 3. SWAPPR (Center - Standardized Alignment)
                        Button(action: {
                            Haptics.shared.playMedium()
                            selectedTab = 2
                            resetInactivityTimer()
                        }) {
                            VStack(spacing: 4) {
                                // Icon Container (Matches TabButton height)
                                ZStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 22)) // Standard size
                                        // Special Gradient for the main app feature
                                        .foregroundStyle(
                                            selectedTab == 2
                                            ? AnyShapeStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            : AnyShapeStyle(Color.gray)
                                        )
                                        .scaleEffect(selectedTab == 2 ? 1.25 : 1.0)
                                        .animation(.spring(response: 0.3), value: selectedTab == 2)
                                }
                                .frame(height: 26) // Standard height
                                
                                Text("Swappr")
                                    .font(.caption2)
                                    .fontWeight(selectedTab == 2 ? .bold : .regular)
                                    .foregroundStyle(selectedTab == 2 ? .white : .gray.opacity(0.8))
                                    .fixedSize()
                            }
                            .frame(width: 50) // Standard width
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        // 4. Chat
                        TabButton(icon: "message.fill", label: "Chat", isSelected: selectedTab == 3) {
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
                    .padding(.horizontal, 20)
                    .frame(height: 70)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
        // Keyboard Observers
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.spring()) {
                isKeyboardVisible = true
                tabManager.hide()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.spring()) {
                isKeyboardVisible = false
            }
        }
        .onAppear {
            resetInactivityTimer()
        }
    }
    
    // MARK: - Logic
    
    func showTabBar() {
        Haptics.shared.playLight()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            tabManager.show()
        }
        resetInactivityTimer()
    }
    
    func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            Task { @MainActor in
                if tabManager.isVisible {
                    withAnimation { tabManager.hide() }
                }
            }
        }
    }
}

// MARK: - Component (Standardized)

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
                // Icon Container
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
