import SwiftUI

// 1. Navigation Keys
struct ProfileRoute: Hashable {}
struct ChatRoute: Hashable {}
struct ChatRoomRoute: Hashable {
    let partnerName: String
}

struct FeedView: View {
    @State private var viewModel = FeedViewModel()
    @State private var path = NavigationPath()
    
    // NEW: Watch the User Manager for changes immediately
    @ObservedObject var userManager = UserManager.shared
    
    // State for Match Overlay
    @State private var matchedItem: TradeItem? = nil
    @State private var rightSwipeCount = 0
    
    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                // Layer 1: Ambient Background
                LiquidBackground()
                
                VStack {
                    // Top Bar
                    HStack {
                        Button(action: { path.append(ProfileRoute()) }) {
                            Image(systemName: "person.circle")
                                .font(.system(size: 30))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(10)
                                .contentShape(Rectangle())
                        }
                        
                        Spacer()
                        Text("Liquid Swap")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        
                        Button(action: { path.append(ChatRoute()) }) {
                            Image(systemName: "message.circle")
                                .font(.system(size: 30))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(10)
                                .contentShape(Rectangle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 40)
                    
                    Spacer()
                    
                    // Layer 2: The Card Stack
                    ZStack {
                        if viewModel.items.isEmpty {
                            VStack(spacing: 20) {
                                Text("No items match your ISO...")
                                    .foregroundStyle(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button("Show All Items") {
                                    // Reset preferences to show everything
                                    userManager.isoCategories.removeAll()
                                    viewModel.loadInitialData()
                                }
                                .foregroundStyle(.cyan)
                                .padding()
                                .background(.white.opacity(0.1))
                                .cornerRadius(10)
                            }
                        } else {
                            ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                                SwipeableCard(
                                    item: item,
                                    onRemove: { direction in
                                        handleSwipe(item: item, direction: direction)
                                    },
                                    onTap: { path.append(item) }
                                )
                                .stacked(at: index, totalCount: viewModel.items.count)
                            }
                        }
                    }
                    .frame(height: 600)
                    .padding()
                    
                    Spacer()
                    
                    // Bottom Controls
                    HStack(spacing: 50) {
                        CircleButton(icon: "xmark", color: .red) {
                            if let topItem = viewModel.items.first {
                                handleSwipe(item: topItem, direction: .left)
                            }
                        }
                        
                        CircleButton(icon: "heart.fill", color: .cyan) {
                            if let topItem = viewModel.items.first {
                                handleSwipe(item: topItem, direction: .right)
                            }
                        }
                    }
                    .padding(.bottom, 30)
                }
                
                // Match Overlay Layer
                if let match = matchedItem {
                    MatchView(
                        item: match,
                        onChat: {
                            matchedItem = nil
                            path.append(ChatRoute())
                        },
                        onKeepSwiping: {
                            matchedItem = nil
                        }
                    )
                    .zIndex(999)
                }
            }
            // NAVIGATION DESTINATIONS
            .navigationDestination(for: TradeItem.self) { item in
                ProductDetailView(item: item)
            }
            .navigationDestination(for: ProfileRoute.self) { _ in
                InventoryView()
            }
            .navigationDestination(for: ChatRoute.self) { _ in
                ChatListView()
            }
            .navigationDestination(for: ChatRoomRoute.self) { route in
                ChatRoomView(tradePartnerName: route.partnerName)
            }
        }
        .tint(.white)
            .onChange(of: userManager.isoCategories) { oldValue, newValue in
                print("Settings changed! Reloading Feed...")
                viewModel.loadInitialData()
            }
            .onAppear {
                viewModel.loadInitialData()
            }
            // NEW: Onboarding Gatekeeper
            .fullScreenCover(isPresented: $userManager.isFirstLaunch) {
                OnboardingView()
            }
        }
        
    // Swipe Logic
    func handleSwipe(item: TradeItem, direction: SwipeDirection) {
        viewModel.removeCard(item, direction: direction)
        
        if direction == .right {
            rightSwipeCount += 1
            if rightSwipeCount % 2 == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation {
                        matchedItem = item
                    }
                }
            }
        }
    }
}

// Helper: Stacking Logic
extension View {
    func stacked(at index: Int, totalCount: Int) -> some View {
        let offset = Double(index * 10)
        let scale = 1.0 - Double(index) * 0.05
        let blur = index == 0 ? 0 : 2.0
        return self
            .offset(y: offset)
            .scaleEffect(scale)
            .blur(radius: blur)
            .zIndex(Double(totalCount - index))
    }
}

struct CircleButton: View {
    let icon: String, color: Color, action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(.ultraThinMaterial).frame(width: 60, height: 60)
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                Image(systemName: icon).font(.title2).foregroundStyle(color).shadow(color: color.opacity(0.6), radius: 10)
            }
        }
    }
}

#Preview {
    FeedView()
}
