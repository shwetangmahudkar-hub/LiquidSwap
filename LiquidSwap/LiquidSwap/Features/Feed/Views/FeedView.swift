import SwiftUI

struct FeedView: View {
    // Connect to the ViewModel
    @StateObject var viewModel = FeedViewModel()
    
    // State for showing details
    @State private var selectedItem: TradeItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. Background
                LiquidBackground()
                
                // 2. Main Content
                VStack {
                    // --- HEADER ---
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("Liquid Swap")
                            .font(.title2)
                            .bold()
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "bell.fill")
                            .foregroundStyle(.white)
                    }
                    .padding()
                    
                    Spacer()
                    
                    // --- CARD STACK ---
                    ZStack {
                        if viewModel.items.isEmpty {
                            // Empty State
                            VStack(spacing: 20) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.green)
                                Text("You've seen everything!")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Button("Refresh") {
                                    Task {
                                        await viewModel.fetchItems()
                                    }
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                            }
                        } else {
                            // Render Cards in Reverse Order (Stack effect)
                            ForEach(Array(viewModel.items.reversed())) { item in
                                SwipeableCard(item: item) { direction in
                                    handleSwipe(direction: direction, item: item)
                                }
                                // Tap to see details
                                .onTapGesture {
                                    selectedItem = item
                                }
                            }
                        }
                    }
                    .frame(height: 500)
                    .padding()
                    
                    Spacer()
                    
                    // --- BOTTOM CONTROLS (Restored!) ---
                    if !viewModel.items.isEmpty {
                        HStack(spacing: 40) {
                            // PASS Button
                            Button(action: {
                                withAnimation {
                                    viewModel.swipeLeft()
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundStyle(.red)
                                    .frame(width: 65, height: 65)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                                    .shadow(radius: 5)
                            }
                            
                            // LIKE Button
                            Button(action: {
                                withAnimation {
                                    viewModel.swipeRight()
                                }
                            }) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundStyle(.green)
                                    .frame(width: 65, height: 65)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                                    .shadow(radius: 5)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
                
                // 3. MATCH OVERLAY (Restored!)
                if let matchItem = viewModel.matchItem {
                    MatchView(item: matchItem, showMatch: Binding(
                        get: { viewModel.matchItem != nil },
                        set: { if !$0 { viewModel.matchItem = nil } }
                    ))
                    .transition(.opacity)
                    .zIndex(100) // Ensure it sits on top of everything
                }
            }
            // 4. Detail Sheet
            .sheet(item: $selectedItem) { item in
                ProductDetailView(item: item)
            }
        }
    }
    
    // Handle Swipe from Card Component
    func handleSwipe(direction: SwipeDirection, item: TradeItem) {
        // Trigger animation delay to let card fly off screen before removing data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            viewModel.saveSwipe(item: item, isLike: (direction == .right))
            viewModel.removeItem(item: item)
        }
    }
}

#Preview {
    FeedView()
}
