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
                            .appFont(34, weight: .bold) // ✨ Standardized
                            .foregroundStyle(.white)
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
                                    NavigationLink(destination: ChatRoomView(trade: trade)) {
                                        GamifiedChatRow(trade: trade)
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
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No active chats yet.")
                .appFont(18, weight: .bold) // ✨ Standardized
                .foregroundStyle(.white.opacity(0.5))
            
            Text("When you accept a trade, the chat will appear here.")
                .appFont(14) // ✨ Standardized
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
    }
}

// MARK: - Gamified Row Component

struct GamifiedChatRow: View {
    let trade: TradeOffer
    
    private var partnerId: UUID {
        return (trade.senderId == UserManager.shared.currentUser?.id) ? trade.receiverId : trade.senderId
    }
    
    private var incomingItem: TradeItem? {
        return (trade.senderId == UserManager.shared.currentUser?.id) ? trade.wantedItem : trade.offeredItem
    }
    
    @State private var partnerProfile: UserProfile?
    @State private var partnerTradeCount: Int = 0
    
    var rankTitle: String {
        switch partnerTradeCount {
        case 0...2: return "Novice"
        case 3...9: return "Eco Trader"
        case 10...24: return "Savant"
        case 25...49: return "Hero"
        default: return "Legend"
        }
    }
    
    var rankColor: Color {
        switch rankTitle {
        case "Novice": return .gray
        case "Eco Trader": return .green
        case "Savant": return .cyan
        case "Hero": return .purple
        case "Legend": return .yellow
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 1. Avatar with Level Ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 3)
                    .frame(width: 56, height: 56)
                
                Circle()
                    .trim(from: 0, to: min(Double(partnerTradeCount) / 50.0, 1.0))
                    .stroke(
                        AngularGradient(colors: [rankColor, rankColor.opacity(0.5)], center: .center),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 56, height: 56)
                
                AsyncImageView(filename: partnerProfile?.avatarUrl)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
            }
            
            // 2. Main Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(partnerProfile?.username ?? "Loading...")
                        .appFont(16, weight: .bold) // ✨ Standardized
                        .foregroundStyle(.white)
                    
                    if partnerProfile?.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.cyan)
                    }
                    
                    Text(rankTitle.uppercased())
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(rankColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(rankColor.opacity(0.15))
                        .clipShape(Capsule())
                }
                
                HStack(spacing: 6) {
                    ChatListStatusPill(status: trade.status)
                    
                    Text("•")
                        .foregroundStyle(.gray)
                    
                    Text("For \(incomingItem?.title ?? "Item")")
                        .appFont(12) // ✨ Standardized
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 3. Trade Thumbnail
            AsyncImageView(filename: incomingItem?.imageUrl)
                .frame(width: 50, height: 50)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    (partnerProfile?.isPremium == true) ? AnyShapeStyle(LinearGradient(colors: [.yellow.opacity(0.6), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.white.opacity(0.1)),
                    lineWidth: (partnerProfile?.isPremium == true) ? 2 : 1
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
        .task {
            if partnerProfile == nil {
                await fetchPartnerData()
            }
        }
    }
    
    func fetchPartnerData() async {
        do {
            let profile = try await DatabaseService.shared.fetchProfile(userId: partnerId)
            let trades = try await DatabaseService.shared.fetchActiveTrades(userId: partnerId)
            
            await MainActor.run {
                self.partnerProfile = profile
                self.partnerTradeCount = trades.count
            }
        } catch {
            print("Failed to load row metadata: \(error)")
        }
    }
}

struct ChatListStatusPill: View {
    let status: String
    
    var color: Color {
        switch status.lowercased() {
        case "pending": return .orange
        case "accepted": return .green
        case "rejected": return .red
        case "countered": return .purple
        case "completed": return .gray
        default: return .white
        }
    }
    
    var body: some View {
        Text(status.capitalized)
            .appFont(10, weight: .bold) // ✨ Standardized
            .foregroundStyle(color)
    }
}
