import SwiftUI

struct TradesView: View {
    @ObservedObject var tradeManager = TradeManager.shared
    @ObservedObject var userManager = UserManager.shared
    
    // Filter State
    enum TradeFilter: String, CaseIterable {
        // ✨ REMOVED: "Chats" case
        case incoming = "Incoming"
        case interested = "Interested"
    }
    @State private var selectedFilter: TradeFilter = .incoming // Default to Incoming
    
    // Sheet State
    @State private var selectedItemForOffer: TradeItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Global Background
                LiquidBackground()
                
                VStack(spacing: 0) {
                    // Header (No Search)
                    headerView
                    
                    // Filter Tabs
                    filterTabs
                    
                    // Main List
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if selectedFilter == .incoming {
                                incomingOffersList
                            } else {
                                interestedItemsList
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
            // Sheet for making offers on "Interested" items
            .sheet(item: $selectedItemForOffer) { item in
                MakeOfferView(targetItem: item)
                    .presentationDetents([.fraction(0.85)])
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Text("Trades")
                .font(.system(size: 34, weight: .bold))
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
                        .font(.headline)
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
        .padding(.bottom, 20)
    }
    
    private var incomingOffersList: some View {
        Group {
            if tradeManager.incomingOffers.isEmpty && !tradeManager.isLoading {
                emptyState(message: "No incoming offers yet.")
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
                emptyState(message: "You haven't liked any items yet.")
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
    
    private func emptyState(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.3))
            Text(message)
                .font(.headline)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.top, 60)
    }
}

// MARK: - Helper Cards

struct OfferCard: View {
    let offer: TradeOffer
    @State private var isProcessing = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Trade Offer")
                    .font(.caption).bold()
                    .foregroundStyle(.cyan)
                Spacer()
                Text(offer.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2).foregroundStyle(.gray)
            }
            
            // Items Swap Visual
            HStack {
                itemVisual(item: offer.offeredItem, label: "They Offer")
                Image(systemName: "arrow.left.arrow.right").font(.title2).foregroundStyle(.white.opacity(0.5))
                itemVisual(item: offer.wantedItem, label: "For Your")
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Actions
            HStack(spacing: 12) {
                Button("Decline") { handleResponse(accept: false) }
                    .buttonStyle(.bordered).tint(.red).disabled(isProcessing)
                Button("Accept") { handleResponse(accept: true) }
                    .buttonStyle(.borderedProminent).tint(.green).disabled(isProcessing)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    func itemVisual(item: TradeItem?, label: String) -> some View {
        VStack {
            AsyncImageView(filename: item?.imageUrl)
                .frame(width: 60, height: 60).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2)))
            Text(item?.title ?? "Unknown").font(.caption).bold().lineLimit(1).foregroundStyle(.white)
            Text(label).font(.caption2).foregroundStyle(.gray)
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
            AsyncImageView(filename: item.imageUrl).frame(width: 70, height: 70).cornerRadius(10)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.headline).foregroundStyle(.white)
                Text(item.category).font(.caption).foregroundStyle(.cyan)
                Text("Tap to Make Offer").font(.caption2).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.3))
        }
        .padding(10).background(.ultraThinMaterial).cornerRadius(16)
    }
}
