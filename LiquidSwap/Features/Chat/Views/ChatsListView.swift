import SwiftUI

struct ChatsListView: View {
    @ObservedObject var tradeManager = TradeManager.shared
    @ObservedObject var userManager = UserManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Global Background
                LiquidBackground()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Chats")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        if tradeManager.isLoading {
                            ProgressView().tint(.white)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 60)
                    .padding(.bottom, 20)
                    
                    // Main List
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if tradeManager.activeTrades.isEmpty && !tradeManager.isLoading {
                                emptyState
                            } else {
                                ForEach(tradeManager.activeTrades) { trade in
                                    // ✅ FIX: Pass the 'trade' object directly
                                    NavigationLink(destination: ChatRoomView(trade: trade)) {
                                        ActiveTradeCard(trade: trade)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100)
                    }
                    .refreshable {
                        await tradeManager.loadTradesData()
                    }
                }
            }
            .onAppear {
                Task { await tradeManager.loadTradesData() }
            }
        }
    }
}

private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.3))
            Text("No active chats yet.")
                .font(.headline)
                .foregroundColor(.white.opacity(0.5))
            Text("When you accept a trade, the chat will appear here.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.top, 60)
    }
