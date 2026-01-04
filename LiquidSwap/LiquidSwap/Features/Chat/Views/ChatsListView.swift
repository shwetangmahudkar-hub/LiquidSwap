import SwiftUI

struct ChatsListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var tradeManager = TradeManager.shared
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var chatManager = ChatManager.shared
    
    // UI State
    @State private var searchText = ""
    
    // MARK: - Adaptive Colors
    private var primaryText: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5)
    }
    
    private var tertiaryText: Color {
        colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.4)
    }
    
    // Computed Properties
    var filteredTrades: [TradeOffer] {
        let trades = tradeManager.activeTrades
        
        if searchText.isEmpty {
            return trades.sorted { t1, t2 in
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
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(primaryText)
                            .shadow(color: .cyan.opacity(0.4), radius: 8)
                        
                        Spacer()
                        
                        if tradeManager.isLoading {
                            ProgressView().tint(primaryText)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 56)
                    .padding(.bottom, 8)
                    
                    // 3. Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(secondaryText)
                        TextField("Search chats...", text: $searchText)
                            .foregroundStyle(primaryText)
                            .tint(.cyan)
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 14)
                    
                    // 4. Main List
                    if filteredTrades.isEmpty && !tradeManager.isLoading {
                        emptyState
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredTrades) { trade in
                                    let partnerId = (trade.senderId == userManager.currentUser?.id) ? trade.receiverId : trade.senderId
                                    let cachedProfile = tradeManager.relatedProfiles[partnerId]
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
                                    .contextMenu {
                                        Button {
                                            // Navigation handled by tap
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
                            .padding(.horizontal, 12)
                            .padding(.bottom, 90)
                        }
                        .refreshable {
                            Haptics.shared.playLight()
                            await tradeManager.loadTradesData()
                            if let myId = userManager.currentUser?.id {
                                await chatManager.fetchInbox(userId: myId)
                            }
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    await tradeManager.loadTradesData()
                    if let myId = userManager.currentUser?.id {
                        await chatManager.fetchInbox(userId: myId)
                    }
                }
            }
        }
    }
    
    // Logic: Does this trade need my attention?
    func requiresAction(_ trade: TradeOffer) -> Bool {
        guard let myId = userManager.currentUser?.id else { return false }
        if trade.receiverId == myId && trade.status == "pending" { return true }
        if trade.receiverId == myId && trade.status == "countered" { return true }
        return false
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                    .frame(width: 90, height: 90)
                
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.cyan.opacity(0.5))
            }
            .padding(.bottom, 8)
            
            Text("No active chats")
                .font(.title3.bold())
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
            
            Text("When you accept a trade or make an offer, the conversation will appear here.")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
            Spacer()
        }
    }
}

// MARK: - Gamified Row Component

struct GamifiedChatRow: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let trade: TradeOffer
    let partnerProfile: UserProfile?
    let lastMessage: Message?
    let requiresAction: Bool
    
    // MARK: - Adaptive Colors
    private var primaryText: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6)
    }
    
    private var tertiaryText: Color {
        colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.4)
    }
    
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
        HStack(spacing: 12) {
            // 1. Avatar with Level Ring
            ZStack {
                // Level Ring
                Circle()
                    .trim(from: 0, to: min(Double(partnerTradeCount) / 50.0, 1.0))
                    .stroke(
                        AngularGradient(colors: [rankColor, rankColor.opacity(0.3)], center: .center),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 52, height: 52)
                    .shadow(color: rankColor.opacity(0.4), radius: 4)
                
                // Avatar
                if let url = partnerProfile?.avatarUrl {
                    AsyncImageView(filename: url)
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundStyle(tertiaryText)
                        .frame(width: 44, height: 44)
                }
                
                // Online Indicator
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                    .offset(x: 16, y: 16)
            }
            
            // 2. Main Info
            VStack(alignment: .leading, spacing: 3) {
                // Top Row: Name + Verification + Time
                HStack(spacing: 5) {
                    Text(partnerProfile?.username ?? "Loading...")
                        .font(.subheadline.bold())
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                    
                    if partnerProfile?.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(.cyan)
                    }
                    
                    Spacer()
                    
                    if let date = lastMessage?.createdAt {
                        Text(date.formatted(.dateTime.hour().minute()))
                            .font(.caption2)
                            .foregroundStyle(tertiaryText)
                    } else {
                        Text(trade.createdAt.formatted(.dateTime.month().day()))
                            .font(.caption2)
                            .foregroundStyle(tertiaryText)
                    }
                }
                
                // Bottom Row: Message Preview or Status
                HStack(spacing: 5) {
                    if let msg = lastMessage {
                        Text(msg.content.isEmpty ? "Sent an image" : msg.content)
                            .font(.caption)
                            .foregroundStyle(requiresAction ? primaryText : secondaryText)
                            .fontWeight(requiresAction ? .semibold : .regular)
                            .lineLimit(1)
                    } else {
                        StatusPillSmall(status: trade.status)
                        
                        Text("•")
                            .foregroundStyle(tertiaryText)
                        
                        Text("For \(incomingItem?.title ?? "Item")")
                            .font(.caption2)
                            .foregroundStyle(secondaryText)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // 3. Action Indicator
            if requiresAction {
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 9, height: 9)
                    .shadow(color: .cyan, radius: 4)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(tertiaryText)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    requiresAction ? AnyShapeStyle(Color.cyan.opacity(0.5)) : AnyShapeStyle(Color.white.opacity(0.1)),
                    lineWidth: requiresAction ? 1.5 : 1
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
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
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}
