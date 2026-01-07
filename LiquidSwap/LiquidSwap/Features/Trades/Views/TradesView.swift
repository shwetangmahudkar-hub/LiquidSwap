import SwiftUI

struct TradesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var tradeManager = TradeManager.shared
    @ObservedObject var userManager = UserManager.shared
    
    // Filter State
    enum TradeFilter: String, CaseIterable {
        case incoming = "Incoming"
        case sent = "Sent"
        case interested = "Saved"
    }
    @State private var selectedFilter: TradeFilter = .incoming
    
    // Sheet State
    @State private var selectedItemForOffer: TradeItem?
    @State private var selectedItemForDetail: TradeItem?
    @State private var selectedProfileSheet: TradeProfileSheetWrapper?
    @State private var selectedOfferForCounter: TradeOffer?
    
    // Navigation State (For Auto-Redirect)
    @State private var navigateToChatTrade: TradeOffer?
    
    // Delete Confirmation
    @State private var itemToDelete: TradeItem?
    @State private var showDeleteConfirmation = false
    
    // Cancel Offer Confirmation
    @State private var offerToCancel: TradeOffer?
    @State private var showCancelConfirmation = false
    
    // MARK: - Adaptive Colors
    private var primaryText: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5)
    }
    
    // Computed Property for Sent Offers
    var sentOffers: [TradeOffer] {
        guard let myId = userManager.currentUser?.id else { return [] }
        return tradeManager.activeTrades.filter { trade in
            trade.senderId == myId && trade.status == .pending  // ✨ Issue #10: Use enum
        }
    }
    
    var body: some View {
        NavigationStack {
            if #available(iOS 17.0, *) {
                ZStack {
                    // Global Background
                    LiquidBackground()
                    
                    VStack(spacing: 0) {
                        // 1. Header
                        headerView
                        
                        // 2. Filter Tabs
                        filterTabs
                        
                        // 3. Main Content
                        ScrollView {
                            VStack(spacing: 16) {
                                // List Content based on Filter
                                LazyVStack(spacing: 12) {
                                    switch selectedFilter {
                                    case .incoming:
                                        incomingOffersList
                                    case .sent:
                                        sentOffersList
                                    case .interested:
                                        interestedItemsList
                                    }
                                }
                                .padding(.bottom, 90)
                            }
                            .padding(.horizontal, 12)
                        }
                        .refreshable {
                            await tradeManager.loadTradesData()
                        }
                    }
                }
                // Auto-Navigation to Chat Room
                .navigationDestination(item: $navigateToChatTrade) { trade in
                    ChatRoomView(trade: trade)
                }
                .onAppear {
                    Task { await tradeManager.loadTradesData() }
                }
                // Quick Offer Sheet
                .sheet(item: $selectedItemForOffer) { item in
                    QuickOfferSheet(wantedItem: item)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
                // Product Detail Sheet
                .sheet(item: $selectedItemForDetail) { item in
                    NavigationStack {
                        ProductDetailView(item: item)
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
                // Profile Sheet using Wrapper
                .sheet(item: $selectedProfileSheet) { wrapper in
                    NavigationStack {
                        PublicProfileView(userId: wrapper.id)
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
                // Counter Offer Sheet
                .sheet(item: $selectedOfferForCounter) { offer in
                    CounterOfferSheet(originalTrade: offer)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
                // Delete Interested Alert
                .alert("Remove from Saved?", isPresented: $showDeleteConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Remove", role: .destructive) {
                        if let item = itemToDelete {
                            deleteInterestedItem(item)
                        }
                    }
                } message: {
                    Text("This item will be removed from your saved list.")
                }
                // Cancel Offer Alert
                .alert("Cancel Offer?", isPresented: $showCancelConfirmation) {
                    Button("Keep Offer", role: .cancel) { }
                    Button("Cancel Offer", role: .destructive) {
                        if let offer = offerToCancel {
                            cancelSentOffer(offer)
                        }
                    }
                } message: {
                    Text("This will remove the offer permanently.")
                }
            } else {
                EmptyView()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Text("Trades")
                .appFont(28, weight: .bold)
                .foregroundColor(primaryText)
            Spacer()
            if tradeManager.isLoading {
                ProgressView().tint(primaryText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 56)
        .padding(.bottom, 14)
    }
    
    private var filterTabs: some View {
        HStack(spacing: 6) {
            ForEach(TradeFilter.allCases, id: \.self) { filter in
                Button(action: {
                    Haptics.shared.playLight()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedFilter = filter
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: iconForFilter(filter))
                            .font(.system(size: 11))
                        Text(filter.rawValue)
                            .appFont(13, weight: .bold)
                    }
                    .foregroundColor(selectedFilter == filter ? .black : primaryText)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        Group {
                            if selectedFilter == filter {
                                Capsule().fill(Color.cyan)
                            } else {
                                Capsule().fill(.ultraThinMaterial)
                            }
                        }
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(selectedFilter == filter ? 0 : 0.1), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
    
    private func iconForFilter(_ filter: TradeFilter) -> String {
        switch filter {
        case .incoming: return "tray.and.arrow.down.fill"
        case .sent: return "paperplane.fill"
        case .interested: return "heart.fill"
        }
    }
    
    // MARK: - List Views
    
    private var incomingOffersList: some View {
        Group {
            if tradeManager.incomingOffers.isEmpty && !tradeManager.isLoading {
                GlassEmptyState(
                    icon: "tray",
                    message: "No incoming offers",
                    subtitle: "When someone wants to trade with you, it'll appear here."
                )
            } else {
                ForEach(tradeManager.incomingOffers) { offer in
                    OfferCard(
                        offer: offer,
                        onViewProfile: {
                            selectedProfileSheet = TradeProfileSheetWrapper(id: offer.senderId)
                        },
                        onCounter: { selectedOfferForCounter = offer }
                    )
                    .contextMenu {
                        Button {
                            handleOfferResponse(offer: offer, accept: true)
                        } label: {
                            Label("Accept Offer", systemImage: "checkmark.circle.fill")
                        }
                        Button {
                            selectedOfferForCounter = offer
                        } label: {
                            Label("Counter Offer", systemImage: "arrow.triangle.2.circlepath")
                        }
                        Button {
                            selectedProfileSheet = TradeProfileSheetWrapper(id: offer.senderId)
                        } label: {
                            Label("View Sender Profile", systemImage: "person.circle")
                        }
                    }
                }
            }
        }
    }
    
    private var sentOffersList: some View {
        Group {
            if sentOffers.isEmpty && !tradeManager.isLoading {
                GlassEmptyState(
                    icon: "paperplane",
                    message: "No sent offers",
                    subtitle: "Offers you make will appear here until accepted."
                )
            } else {
                ForEach(sentOffers) { offer in
                    SentOfferCard(
                        offer: offer,
                        onCancel: {
                            offerToCancel = offer
                            showCancelConfirmation = true
                        }
                    )
                }
            }
        }
    }
    
    private var interestedItemsList: some View {
        Group {
            if tradeManager.interestedItems.isEmpty && !tradeManager.isLoading {
                GlassEmptyState(
                    icon: "heart",
                    message: "No saved items",
                    subtitle: "Double-tap items in the feed to save them here."
                )
            } else {
                ForEach(tradeManager.interestedItems) { item in
                    InterestedItemCard(
                        item: item,
                        onTap: { selectedItemForOffer = item },
                        onViewDetail: { selectedItemForDetail = item },
                        onViewProfile: {
                            selectedProfileSheet = TradeProfileSheetWrapper(id: item.ownerId)
                        },
                        onDelete: {
                            itemToDelete = item
                            showDeleteConfirmation = true
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleOfferResponse(offer: TradeOffer, accept: Bool) {
        Task {
            let success = await tradeManager.respondToOffer(offer: offer, accept: accept)
            
            if accept && success {
                Haptics.shared.playSuccess()
                
                var acceptedTrade = offer
                acceptedTrade.status = .accepted  // ✨ Issue #10: Use enum
                
                try? await Task.sleep(nanoseconds: 500_000_000)
                
                await MainActor.run {
                    navigateToChatTrade = acceptedTrade
                }
            }
        }
    }
    
    private func deleteInterestedItem(_ item: TradeItem) {
        Task {
            let success = await tradeManager.removeInterest(item: item)
            if success {
                Haptics.shared.playLight()
            }
        }
    }
    
    private func cancelSentOffer(_ offer: TradeOffer) {
        Task {
            try? await DatabaseService.shared.updateTradeStatus(tradeId: offer.id, status: TradeStatus.cancelled.rawValue)  // ✨ Issue #10: Use enum
            Haptics.shared.playMedium()
            await tradeManager.loadTradesData()
        }
    }
}

// MARK: - Components

struct GlassEmptyState: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let icon: String
    let message: String
    let subtitle: String
    
    private var primaryText: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(.cyan.opacity(0.6))
            }
            VStack(spacing: 6) {
                Text(message)
                    .appFont(16, weight: .bold)
                    .foregroundStyle(primaryText)
                Text(subtitle)
                    .appFont(13)
                    .foregroundStyle(secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Offer Card

struct OfferCard: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let offer: TradeOffer
    let onViewProfile: () -> Void
    let onCounter: () -> Void
    
    @State private var isProcessing = false
    
    private var primaryText: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5)
    }
    
    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.cyan.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: "arrow.down.circle.fill").font(.system(size: 16)).foregroundStyle(.cyan))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Offer")
                        .appFont(14, weight: .bold)
                        .foregroundStyle(primaryText)
                    Text(timeAgoString(from: offer.createdAt))
                        .appFont(11)
                        .foregroundStyle(secondaryText)
                }
                
                Spacer()
                
                Button(action: onViewProfile) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 14))
                        Text("Profile")
                            .appFont(11, weight: .bold)
                    }
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.cyan.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            
            // Items
            HStack(spacing: 10) {
                itemVisual(item: offer.offeredItem, label: "THEY OFFER", borderColor: .cyan)
                VStack(spacing: 4) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.3))
                }
                itemVisual(item: offer.wantedItem, label: "FOR YOUR", borderColor: .orange)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Actions
            HStack(spacing: 12) {
                Button(action: onCounter) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 12))
                        Text("Counter").appFont(13, weight: .bold)
                    }
                    .foregroundStyle(.cyan).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(.ultraThinMaterial).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                .disabled(isProcessing)
                
                Button(action: { handleResponse(accept: false) }) {
                    HStack(spacing: 5) {
                        if isProcessing { ProgressView().tint(primaryText) } else {
                            Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                            Text("Decline").appFont(13, weight: .bold)
                        }
                    }
                    .foregroundStyle(primaryText).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(.ultraThinMaterial).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                .disabled(isProcessing)
                
                Button(action: { handleResponse(accept: true) }) {
                    HStack(spacing: 5) {
                        if isProcessing { ProgressView().tint(.black) } else {
                            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                            Text("Accept").appFont(13, weight: .bold)
                        }
                    }
                    .foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.cyan).cornerRadius(12)
                }
                .disabled(isProcessing)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
    
    func itemVisual(item: TradeItem?, label: String, borderColor: Color) -> some View {
        VStack(spacing: 6) {
            Text(label).appFont(8, weight: .black).foregroundStyle(borderColor.opacity(0.8))
            AsyncImageView(filename: item?.imageUrl)
                .frame(width: 60, height: 60).cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(borderColor.opacity(0.4), lineWidth: 2))
            Text(item?.title ?? "Unknown").appFont(11, weight: .bold).lineLimit(1).foregroundStyle(primaryText)
        }
        .frame(maxWidth: .infinity)
    }
    
    func handleResponse(accept: Bool) {
        isProcessing = true
        Haptics.shared.playLight()
        Task {
            _ = await TradeManager.shared.respondToOffer(offer: offer, accept: accept)
            await MainActor.run { isProcessing = false; if accept { Haptics.shared.playSuccess() } }
        }
    }
    
    func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}

struct SentOfferCard: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let offer: TradeOffer
    let onCancel: () -> Void
    
    private var primaryText: Color {
        colorScheme == .dark ? .white : .black
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 28, height: 28)
                        .overlay(Image(systemName: "paperplane.fill").font(.system(size: 12)).foregroundStyle(.orange))
                    Text("Offer Sent")
                        .appFont(13, weight: .bold)
                        .foregroundStyle(primaryText)
                }
                Spacer()
                Text(offer.status.displayName)  // ✨ Issue #10: Use enum displayName
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color.orange.opacity(0.1)).clipShape(Capsule())
            }
            
            // Items
            HStack(spacing: 10) {
                itemVisual(item: offer.offeredItem, label: "YOU OFFERED", borderColor: .orange)
                VStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.4))
                }
                itemVisual(item: offer.wantedItem, label: "FOR THEIR", borderColor: .gray)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            Button(action: onCancel) {
                HStack {
                    Image(systemName: "trash")
                    Text("Cancel Offer")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.red.opacity(0.8))
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    func itemVisual(item: TradeItem?, label: String, borderColor: Color) -> some View {
        VStack(spacing: 6) {
            Text(label).appFont(8, weight: .black).foregroundStyle(borderColor.opacity(0.8))
            AsyncImageView(filename: item?.imageUrl)
                .frame(width: 52, height: 52).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor.opacity(0.4), lineWidth: 2))
            Text(item?.title ?? "Unknown").appFont(11, weight: .bold).lineLimit(1).foregroundStyle(primaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

struct InterestedItemCard: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let item: TradeItem
    let onTap: () -> Void
    let onViewDetail: () -> Void
    let onViewProfile: () -> Void
    let onDelete: () -> Void
    
    private var primaryText: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5)
    }
    
    private var tertiaryText: Color {
        colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.4)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AsyncImageView(filename: item.imageUrl)
                    .frame(width: 60, height: 60).cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.15), lineWidth: 1))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).appFont(15, weight: .bold).foregroundStyle(primaryText).lineLimit(1)
                    HStack(spacing: 6) {
                        Text(item.category.uppercased())
                            .appFont(8, weight: .bold).foregroundStyle(.cyan)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.15)).clipShape(Capsule())
                        if item.distance > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "location.fill").font(.system(size: 7))
                                Text("\(String(format: "%.1f", item.distance)) km").appFont(9)
                            }
                            .foregroundStyle(secondaryText)
                        }
                    }
                    Text("Tap to make an offer").appFont(10).foregroundStyle(tertiaryText)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(.cyan.opacity(0.6))
            }
            .padding(12).background(.ultraThinMaterial).cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onTap() } label: { Label("Make Offer", systemImage: "arrow.triangle.2.circlepath") }
            Button { onViewDetail() } label: { Label("View Details", systemImage: "cube.box") }
            Button { onViewProfile() } label: { Label("View Owner", systemImage: "person.circle") }
            Divider()
            Button(role: .destructive) { onDelete() } label: { Label("Remove", systemImage: "heart.slash") }
        }
    }
}

// Helper Struct for Identifiable UUID
struct TradeProfileSheetWrapper: Identifiable {
    let id: UUID
}
