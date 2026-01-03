import SwiftUI

struct TradesView: View {
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
    @State private var selectedProfileUserId: UUID?
    @State private var selectedOfferForCounter: TradeOffer?
    
    // Navigation State (✨ NEW: For Auto-Redirect)
    @State private var navigateToChatTrade: TradeOffer?
    
    // Delete Confirmation
    @State private var itemToDelete: TradeItem?
    @State private var showDeleteConfirmation = false
    
    // Cancel Offer Confirmation
    @State private var offerToCancel: TradeOffer?
    @State private var showCancelConfirmation = false
    
    // Computed Property for Sent Offers
    var sentOffers: [TradeOffer] {
        guard let myId = userManager.currentUser?.id else { return [] }
        return tradeManager.activeTrades.filter { trade in
            trade.senderId == myId && trade.status == "pending"
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
                            VStack(spacing: 20) {
                                // List Content based on Filter
                                LazyVStack(spacing: 16) {
                                    switch selectedFilter {
                                    case .incoming:
                                        incomingOffersList
                                    case .sent:
                                        sentOffersList
                                    case .interested:
                                        interestedItemsList
                                    }
                                }
                                .padding(.bottom, 100)
                            }
                            .padding(.horizontal)
                        }
                        .refreshable {
                            await tradeManager.loadTradesData()
                        }
                    }
                }
                // ✨ NEW: Auto-Navigation to Chat Room
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
                // Profile Sheet
                .sheet(item: $selectedProfileUserId) { userId in
                    NavigationStack {
                        PublicProfileView(userId: userId)
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
                // Fallback on earlier versions
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Text("Trades")
                .appFont(34, weight: .bold)
                .foregroundColor(.white)
            Spacer()
            // Loading Indicator
            if tradeManager.isLoading {
                ProgressView().tint(.white)
            }
        }
        .padding(.horizontal)
        .padding(.top, 60)
        .padding(.bottom, 20)
    }
    
    private var filterTabs: some View {
        HStack(spacing: 8) {
            ForEach(TradeFilter.allCases, id: \.self) { filter in
                Button(action: {
                    Haptics.shared.playLight()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedFilter = filter
                    }
                }) {
                    HStack(spacing: 6) {
                        // Dynamic Icons
                        Image(systemName: iconForFilter(filter))
                            .font(.system(size: 12))
                        Text(filter.rawValue)
                            .appFont(14, weight: .bold)
                    }
                    .foregroundColor(selectedFilter == filter ? .black : .white)
                    .padding(.vertical, 12)
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
        .padding(.horizontal)
        .padding(.bottom, 16)
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
                        onViewProfile: { selectedProfileUserId = offer.senderId },
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
                            selectedProfileUserId = offer.senderId
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
                        onViewProfile: { selectedProfileUserId = item.ownerId },
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
                
                // ✨ NEW: Auto-Redirect Logic
                // 1. Create a local copy with updated status so ChatRoomView renders correctly
                var acceptedTrade = offer
                acceptedTrade.status = "accepted"
                
                // 2. Wait briefly so user sees the card animation/haptic confirmation
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                
                // 3. Navigate
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
            // Update DB Status
            try? await DatabaseService.shared.updateTradeStatus(tradeId: offer.id, status: "cancelled")
            Haptics.shared.playMedium()
            
            // Refresh Data
            await tradeManager.loadTradesData()
        }
    }
}

// MARK: - Components

struct GlassEmptyState: View {
    let icon: String
    let message: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 80, height: 80)
                
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.3))
            }
            
            VStack(spacing: 6) {
                Text(message)
                    .appFont(18, weight: .bold)
                    .foregroundStyle(.white.opacity(0.6))
                
                Text(subtitle)
                    .appFont(14)
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct OfferCard: View {
    let offer: TradeOffer
    let onViewProfile: () -> Void
    let onCounter: () -> Void
    
    @State private var isProcessing = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.cyan.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 14, weight: .bold)).foregroundStyle(.cyan))
                    Text("Trade Offer")
                        .appFont(14, weight: .bold)
                        .foregroundStyle(.white)
                }
                Spacer()
                Text(timeAgoString(from: offer.createdAt))
                    .appFont(11)
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            // Items
            HStack(spacing: 12) {
                itemVisual(item: offer.offeredItem, label: "THEY OFFER", borderColor: .cyan)
                VStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                itemVisual(item: offer.wantedItem, label: "FOR YOUR", borderColor: .purple)
            }
            
            // Sender
            Button(action: onViewProfile) {
                HStack(spacing: 8) {
                    Image(systemName: "person.circle.fill").font(.system(size: 14)).foregroundStyle(.cyan)
                    Text("View Sender Profile").appFont(12, weight: .medium).foregroundStyle(.cyan)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(.cyan.opacity(0.6))
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color.cyan.opacity(0.1)).cornerRadius(12)
            }
            
            // Actions
            HStack(spacing: 12) {
                Button(action: { handleResponse(accept: false) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                        Text("Decline").appFont(14, weight: .bold)
                    }
                    .foregroundStyle(.red).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.red.opacity(0.15)).cornerRadius(14)
                }
                .disabled(isProcessing)
                
                Button(action: onCounter) {
                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white).frame(width: 50).padding(.vertical, 14)
                        .background(.ultraThinMaterial).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                .disabled(isProcessing)
                
                Button(action: { handleResponse(accept: true) }) {
                    HStack(spacing: 6) {
                        if isProcessing { ProgressView().tint(.black) } else {
                            Image(systemName: "checkmark").font(.system(size: 14, weight: .bold))
                            Text("Accept").appFont(14, weight: .bold)
                        }
                    }
                    .foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.cyan).cornerRadius(14)
                }
                .disabled(isProcessing)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
    }
    
    func itemVisual(item: TradeItem?, label: String, borderColor: Color) -> some View {
        VStack(spacing: 8) {
            Text(label).appFont(9, weight: .black).foregroundStyle(borderColor.opacity(0.8))
            AsyncImageView(filename: item?.imageUrl)
                .frame(width: 70, height: 70).cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor.opacity(0.4), lineWidth: 2))
            Text(item?.title ?? "Unknown").appFont(12, weight: .bold).lineLimit(1).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }
    
    func handleResponse(accept: Bool) {
        // Updated to use the new method that handles navigation
        // But for generic buttons outside the main list, we can keep simple
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

// ✨ NEW: Sent Offer Card
struct SentOfferCard: View {
    let offer: TradeOffer
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(Image(systemName: "paperplane.fill").font(.system(size: 14)).foregroundStyle(.orange))
                    Text("Offer Sent")
                        .appFont(14, weight: .bold)
                        .foregroundStyle(.white)
                }
                Spacer()
                Text("Pending")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1)).clipShape(Capsule())
            }
            
            // Items
            HStack(spacing: 12) {
                // For Sent Offers: "You Offered" (Offered Item) -> "For Their" (Wanted Item)
                itemVisual(item: offer.offeredItem, label: "YOU OFFERED", borderColor: .orange)
                VStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                itemVisual(item: offer.wantedItem, label: "FOR THEIR", borderColor: .gray)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Cancel Action
            Button(action: onCancel) {
                HStack {
                    Image(systemName: "trash")
                    Text("Cancel Offer")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.red.opacity(0.8))
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    func itemVisual(item: TradeItem?, label: String, borderColor: Color) -> some View {
        VStack(spacing: 8) {
            Text(label).appFont(9, weight: .black).foregroundStyle(borderColor.opacity(0.8))
            AsyncImageView(filename: item?.imageUrl)
                .frame(width: 60, height: 60).cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(borderColor.opacity(0.4), lineWidth: 2))
            Text(item?.title ?? "Unknown").appFont(12, weight: .bold).lineLimit(1).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }
}

struct InterestedItemCard: View {
    let item: TradeItem
    let onTap: () -> Void
    let onViewDetail: () -> Void
    let onViewProfile: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                AsyncImageView(filename: item.imageUrl)
                    .frame(width: 70, height: 70).cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title).appFont(16, weight: .bold).foregroundStyle(.white).lineLimit(1)
                    HStack(spacing: 8) {
                        Text(item.category.uppercased())
                            .appFont(9, weight: .bold).foregroundStyle(.cyan)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.cyan.opacity(0.15)).clipShape(Capsule())
                        if item.distance > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "location.fill").font(.system(size: 8))
                                Text("\(String(format: "%.1f", item.distance)) km").appFont(10)
                            }
                            .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    Text("Tap to make an offer").appFont(11).foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(.cyan.opacity(0.6))
            }
            .padding(14).background(.ultraThinMaterial).cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
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
