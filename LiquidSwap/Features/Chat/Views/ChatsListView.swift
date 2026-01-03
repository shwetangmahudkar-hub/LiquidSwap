import SwiftUI

struct ChatsListView: View {
    @ObservedObject var tradeManager = TradeManager.shared
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var chatManager = ChatManager.shared
    
    // UI State
    @State private var searchText = ""
    
    // Computed Properties
    var filteredTrades: [TradeOffer] {
        let trades = tradeManager.activeTrades
        
        if searchText.isEmpty {
            return trades.sorted { t1, t2 in
                // Sort Priority: 1. Pending Action, 2. Newest Message, 3. Newest Trade
                let t1Action = requiresAction(t1)
                let t2Action = requiresAction(t2)
                
                if t1Action && !t2Action { return true }
                if !t1Action && t2Action { return false }
                
                return t1.createdAt > t2.createdAt
            }
        } else {
            return trades.filter { trade in
                let partnerId = (trade.senderId == userManager.currentUser?.id) ? trade.receiverId : trade.senderId
                let profile = tradeManager.relatedProfiles[partnerId]
                let username = profile?.username.lowercased() ?? ""
                return username.contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. Global Background
                LiquidBackground()
                    .opacity(0.6)
                
                VStack(spacing: 0) {
                    // 2. Header
                    HStack {
                        Text("Chats")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .cyan.opacity(0.5), radius: 10)
                        
                        Spacer()
                        
                        if tradeManager.isLoading {
                            ProgressView().tint(.white)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    .padding(.bottom, 10)
                    
                    // 3. Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.white.opacity(0.5))
                        TextField("Search chats...", text: $searchText)
                            .foregroundStyle(.white)
                            .tint(.cyan)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    
                    // 4. Main List
                    if filteredTrades.isEmpty && !tradeManager.isLoading {
                        emptyState
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredTrades) { trade in
                                    // Identify Partner
                                    let partnerId = (trade.senderId == userManager.currentUser?.id) ? trade.receiverId : trade.senderId
                                    
                                    // Get Cached Profile (Instant O(1) Lookup)
                                    let cachedProfile = tradeManager.relatedProfiles[partnerId]
                                    
                                    // Get Last Message (Realtime)
                                    let lastMsg = chatManager.conversations[trade.id]?.last
                                    
                                    NavigationLink(destination: ChatRoomView(trade: trade)) {
                                        GamifiedChatRow(
                                            trade: trade,
                                            partnerProfile: cachedProfile,
                                            lastMessage: lastMsg,
                                            requiresAction: requiresAction(trade)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    // ✨ Rule 4: Context Menu for Quick Actions
                                    .contextMenu {
                                        Button {
                                            // Navigation handled by tap, but valid for context
                                        } label: {
                                            Label("Open Chat", systemImage: "bubble.left.and.bubble.right")
                                        }
                                        
                                        Divider()
                                        
                                        Button(role: .destructive) {
                                            Task { await userManager.blockUser(userId: partnerId) }
                                        } label: {
                                            Label("Block User", systemImage: "hand.raised.fill")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100)
                        }
                        .refreshable {
                            Haptics.shared.playLight()
                            await tradeManager.loadTradesData()
                            if let myId = userManager.currentUser?.id {
                                // ✨ FIXED: Use fetchInbox instead of fetchAllMessages
                                await chatManager.fetchInbox(userId: myId)
                            }
                        }
                    }
                }
            }
            .onAppear {
                // Ensure data is fresh when view appears
                Task {
                    await tradeManager.loadTradesData()
                    if let myId = userManager.currentUser?.id {
                        // ✨ FIXED: Use fetchInbox here as well
                        await chatManager.fetchInbox(userId: myId)
                    }
                }
            }
        }
    }
    
    // Logic: Does this trade need my attention?
    func requiresAction(_ trade: TradeOffer) -> Bool {
        guard let myId = userManager.currentUser?.id else { return false }
        // If I received it and it's pending -> I need to act
        if trade.receiverId == myId && trade.status == "pending" { return true }
        // If I received a counter offer -> I need to act
        if trade.receiverId == myId && trade.status == "countered" { return true }
        return false
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.cyan.opacity(0.5))
            }
            .padding(.bottom, 10)
            
            Text("No active chats")
                .font(.title3.bold())
                .foregroundStyle(.white.opacity(0.8))
            
            Text("When you accept a trade or make an offer, the conversation will appear here.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            Spacer()
        }
    }
}

// MARK: - Gamified Row Component

struct GamifiedChatRow: View {
    let trade: TradeOffer
    let partnerProfile: UserProfile?
    let lastMessage: Message?
    let requiresAction: Bool
    
    // Computed context
    private var incomingItem: TradeItem? {
        return (trade.senderId == UserManager.shared.currentUser?.id) ? trade.wantedItem : trade.offeredItem
    }
    
    private var partnerTradeCount: Int {
        return partnerProfile?.completedTradeCount ?? 0
    }
    
    var rankColor: Color {
        switch partnerTradeCount {
        case 0...2: return .gray
        case 3...9: return .green
        case 10...24: return .cyan
        case 25...49: return .purple
        default: return .yellow
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 1. Avatar with Level Ring
            ZStack {
                // Level Ring
                Circle()
                    .trim(from: 0, to: min(Double(partnerTradeCount) / 50.0, 1.0))
                    .stroke(
                        AngularGradient(colors: [rankColor, rankColor.opacity(0.3)], center: .center),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 58, height: 58)
                    .shadow(color: rankColor.opacity(0.4), radius: 5)
                
                // Avatar
                if let url = partnerProfile?.avatarUrl {
                    AsyncImageView(filename: url)
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundStyle(.white.opacity(0.2))
                        .frame(width: 50, height: 50)
                }
                
                // Online Indicator (Mock logic)
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.black, lineWidth: 2))
                    .offset(x: 18, y: 18)
            }
            
            // 2. Main Info
            VStack(alignment: .leading, spacing: 4) {
                // Top Row: Name + Verification + Time
                HStack(spacing: 6) {
                    Text(partnerProfile?.username ?? "Loading...")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    if partnerProfile?.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.cyan)
                    }
                    
                    Spacer()
                    
                    if let date = lastMessage?.createdAt {
                        Text(date.formatted(.dateTime.hour().minute()))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    } else {
                        Text(trade.createdAt.formatted(.dateTime.month().day()))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                
                // Bottom Row: Message Preview or Status
                HStack(spacing: 6) {
                    if let msg = lastMessage {
                        // Show Message
                        Text(msg.content.isEmpty ? "Sent an image" : msg.content)
                            .font(.subheadline)
                            .foregroundStyle(requiresAction ? .white : .white.opacity(0.6))
                            .fontWeight(requiresAction ? .semibold : .regular)
                            .lineLimit(1)
                    } else {
                        // Show Status if no messages yet
                        StatusPillSmall(status: trade.status)
                        
                        Text("•")
                            .foregroundStyle(.white.opacity(0.3))
                        
                        Text("For \(incomingItem?.title ?? "Item")")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // 3. Action Indicator
            if requiresAction {
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 10, height: 10)
                    .shadow(color: .cyan, radius: 5)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    requiresAction ? AnyShapeStyle(Color.cyan.opacity(0.5)) : AnyShapeStyle(Color.white.opacity(0.1)),
                    lineWidth: requiresAction ? 1.5 : 1
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    }
}

// Helper Pill
struct StatusPillSmall: View {
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
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}
