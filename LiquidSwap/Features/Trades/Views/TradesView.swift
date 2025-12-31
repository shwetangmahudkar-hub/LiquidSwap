import SwiftUI

struct TradesView: View {
    @ObservedObject var tradeManager = TradeManager.shared
    @ObservedObject var userManager = UserManager.shared
    
    // Filter State
    enum TradeFilter: String, CaseIterable {
        // Chats are handled in the specific "Chat" Tab
        case incoming = "Incoming"
        case interested = "Interested"
    }
    @State private var selectedFilter: TradeFilter = .incoming
    
    // Sheet State
    @State private var selectedItemForOffer: TradeItem?
    
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
            .sheet(item: $selectedItemForOffer) { item in
                QuickOfferSheet(wantedItem: item)
                    .presentationDetents([.medium, .large])
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Text("Trades")
                .appFont(34, weight: .bold) // ✨ Standardized
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
        HStack {
            ForEach(TradeFilter.allCases, id: \.self) { filter in
                Button(action: {
                    withAnimation { selectedFilter = filter }
                }) {
                    Text(filter.rawValue)
                        .appFont(16, weight: .bold) // ✨ Standardized
                        .foregroundColor(selectedFilter == filter ? .black : .white)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule()
                                .fill(selectedFilter == filter ? Color.white : Color.white.opacity(0.1))
                        )
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
    }
    
    private var incomingOffersList: some View {
        Group {
            if tradeManager.incomingOffers.isEmpty && !tradeManager.isLoading {
                emptyState(message: "No incoming offers yet.", icon: "tray")
            } else {
                ForEach(tradeManager.incomingOffers) { offer in
                    OfferCard(offer: offer)
                }
            }
        }
    }
    
    private var interestedItemsList: some View {
        Group {
            if tradeManager.interestedItems.isEmpty && !tradeManager.isLoading {
                emptyState(message: "You haven't liked items yet.", icon: "heart")
            } else {
                ForEach(tradeManager.interestedItems) { item in
                    InterestedItemCard(item: item)
                        .onTapGesture {
                            selectedItemForOffer = item
                        }
                }
            }
        }
    }
    
    private func emptyState(message: String, icon: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.3))
            Text(message)
                .appFont(18, weight: .medium)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.top, 40)
    }
}

// MARK: - Helper Cards

struct OfferCard: View {
    let offer: TradeOffer
    @State private var isProcessing = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header Row
            HStack {
                Text("Trade Offer")
                    .appFont(12, weight: .bold)
                    .foregroundStyle(.cyan)
                Spacer()
                Text(offer.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .appFont(10)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            // Items Row
            HStack {
                itemVisual(item: offer.offeredItem, label: "They Offer")
                Image(systemName: "arrow.left.arrow.right")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.5))
                itemVisual(item: offer.wantedItem, label: "For Your")
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // ✨ Action Buttons using Design System
            HStack(spacing: 12) {
                Button("Decline") { handleResponse(accept: false) }
                    .buttonStyle(DangerButtonStyle())
                    .disabled(isProcessing)
                
                Button("Accept") { handleResponse(accept: true) }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isProcessing)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    func itemVisual(item: TradeItem?, label: String) -> some View {
        VStack(spacing: 6) {
            AsyncImageView(filename: item?.imageUrl)
                .frame(width: 60, height: 60)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
            
            Text(item?.title ?? "Unknown")
                .appFont(12, weight: .bold)
                .lineLimit(1)
                .foregroundStyle(.white)
            
            Text(label)
                .appFont(10)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
    
    func handleResponse(accept: Bool) {
        isProcessing = true
        Task {
            _ = await TradeManager.shared.respondToOffer(offer: offer, accept: accept)
            isProcessing = false
        }
    }
}

struct InterestedItemCard: View {
    let item: TradeItem
    var body: some View {
        HStack(spacing: 15) {
            AsyncImageView(filename: item.imageUrl)
                .frame(width: 70, height: 70)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .appFont(18, weight: .bold)
                    .foregroundStyle(.white)
                
                Text(item.category)
                    .appFont(12, weight: .medium)
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.1))
                    .clipShape(Capsule())
                
                Text("Tap to Make Offer")
                    .appFont(12)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.cyan)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
