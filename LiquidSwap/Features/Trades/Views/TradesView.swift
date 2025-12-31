import SwiftUI

struct TradesView: View {
    @ObservedObject var tradeManager = TradeManager.shared
    @ObservedObject var userManager = UserManager.shared
    
    // Filter State
    enum TradeFilter: String, CaseIterable {
        case incoming = "Incoming"
        case interested = "Interested"
    }
    @State private var selectedFilter: TradeFilter = .incoming
    
    // Sheet State
    @State private var selectedItemForOffer: TradeItem?
    @State private var selectedItemForDetail: TradeItem?
    @State private var selectedProfileUserId: UUID?
    @State private var selectedOfferForCounter: TradeOffer?
    
    // Delete Confirmation
    @State private var itemToDelete: TradeItem?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
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
                                if selectedFilter == .incoming {
                                    incomingOffersList
                                } else {
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
            // Delete Confirmation Alert
            .alert("Remove from Interested?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    if let item = itemToDelete {
                        deleteInterestedItem(item)
                    }
                }
            } message: {
                Text("This item will be removed from your interested list.")
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedFilter = filter
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: filter == .incoming ? "tray.and.arrow.down.fill" : "heart.fill")
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
    
    private var incomingOffersList: some View {
        Group {
            if tradeManager.incomingOffers.isEmpty && !tradeManager.isLoading {
                GlassEmptyState(
                    icon: "tray",
                    message: "No incoming offers yet",
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
                        
                        if let item = offer.offeredItem {
                            Button {
                                selectedItemForDetail = item
                            } label: {
                                Label("View Their Item", systemImage: "cube.box")
                            }
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            handleOfferResponse(offer: offer, accept: false)
                        } label: {
                            Label("Decline Offer", systemImage: "xmark.circle.fill")
                        }
                    }
                }
            }
        }
    }
    
    private var interestedItemsList: some View {
        Group {
            if tradeManager.interestedItems.isEmpty && !tradeManager.isLoading {
                GlassEmptyState(
                    icon: "heart",
                    message: "No liked items yet",
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
            _ = await tradeManager.respondToOffer(offer: offer, accept: accept)
            if accept {
                Haptics.shared.playSuccess()
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
}

// MARK: - Glass Empty State Component

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

// MARK: - Offer Card Component

struct OfferCard: View {
    let offer: TradeOffer
    let onViewProfile: () -> Void
    let onCounter: () -> Void
    
    @State private var isProcessing = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header Row
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.cyan.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.cyan)
                        )
                    
                    Text("Trade Offer")
                        .appFont(14, weight: .bold)
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                Text(timeAgoString(from: offer.createdAt))
                    .appFont(11)
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            // Items Row
            HStack(spacing: 12) {
                itemVisual(item: offer.offeredItem, label: "THEY OFFER", borderColor: .cyan)
                
                VStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                itemVisual(item: offer.wantedItem, label: "FOR YOUR", borderColor: .purple)
            }
            
            // Sender Info Button
            Button(action: onViewProfile) {
                HStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.cyan)
                    Text("View Sender Profile")
                        .appFont(12, weight: .medium)
                        .foregroundStyle(.cyan)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.cyan.opacity(0.6))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.cyan.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Action Buttons (Bottom, easy thumb reach)
            HStack(spacing: 12) {
                // Decline Button
                Button(action: { handleResponse(accept: false) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                        Text("Decline")
                            .appFont(14, weight: .bold)
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                }
                .disabled(isProcessing)
                
                // Counter Button
                Button(action: onCounter) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 50)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .disabled(isProcessing)
                
                // Accept Button
                Button(action: { handleResponse(accept: true) }) {
                    HStack(spacing: 6) {
                        if isProcessing {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                            Text("Accept")
                                .appFont(14, weight: .bold)
                        }
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.cyan)
                    .cornerRadius(14)
                }
                .disabled(isProcessing)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
    }
    
    func itemVisual(item: TradeItem?, label: String, borderColor: Color) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .appFont(9, weight: .black)
                .foregroundStyle(borderColor.opacity(0.8))
            
            AsyncImageView(filename: item?.imageUrl)
                .frame(width: 70, height: 70)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(borderColor.opacity(0.4), lineWidth: 2)
                )
            
            Text(item?.title ?? "Unknown")
                .appFont(12, weight: .bold)
                .lineLimit(1)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }
    
    func handleResponse(accept: Bool) {
        isProcessing = true
        Haptics.shared.playLight()
        Task {
            _ = await TradeManager.shared.respondToOffer(offer: offer, accept: accept)
            await MainActor.run {
                isProcessing = false
                if accept {
                    Haptics.shared.playSuccess()
                }
            }
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

// MARK: - Interested Item Card Component

struct InterestedItemCard: View {
    let item: TradeItem
    let onTap: () -> Void
    let onViewDetail: () -> Void
    let onViewProfile: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Item Image
                AsyncImageView(filename: item.imageUrl)
                    .frame(width: 70, height: 70)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                
                // Item Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .appFont(16, weight: .bold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        // Category Pill
                        Text(item.category.uppercased())
                            .appFont(9, weight: .bold)
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.cyan.opacity(0.15))
                            .clipShape(Capsule())
                        
                        // Distance
                        if item.distance > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 8))
                                Text("\(String(format: "%.1f", item.distance)) km")
                                    .appFont(10)
                            }
                            .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    
                    Text("Tap to make an offer")
                        .appFont(11)
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                Spacer()
                
                // Arrow Icon
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.cyan.opacity(0.6))
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onTap()
            } label: {
                Label("Make Offer", systemImage: "arrow.triangle.2.circlepath")
            }
            
            Button {
                onViewDetail()
            } label: {
                Label("View Item Details", systemImage: "cube.box")
            }
            
            Button {
                onViewProfile()
            } label: {
                Label("View Owner Profile", systemImage: "person.circle")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Remove from Interested", systemImage: "heart.slash")
            }
        }
    }
}
