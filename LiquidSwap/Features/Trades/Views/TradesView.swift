import SwiftUI

struct TradesView: View {
    @ObservedObject var tradeManager = TradeManager.shared
    @ObservedObject var userManager = UserManager.shared
    
    // Navigation State
    @State private var showActivityHub = false
    
    // Filter State
    enum TradeFilter: String, CaseIterable {
        // Chats are handled in the specific "Chat" Tab, so we exclude them here.
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
                            
                            // ✨ NEW: Activity Hub Banner
                            // This is the entry point for the "Who Liked Me" feature
                            activityHubBanner
                            
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
            // Navigate to Activity Hub
            .navigationDestination(isPresented: $showActivityHub) {
                ActivityHubView()
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
        .padding(.bottom, 10)
    }
    
    // ✨ NEW: Activity Hub Banner Component
    private var activityHubBanner: some View {
        Button(action: { showActivityHub = true }) {
            HStack {
                ZStack {
                    Circle().fill(.white.opacity(0.2)).frame(width: 40, height: 40)
                    Image(systemName: "sparkles").foregroundStyle(.yellow).font(.title3)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("See Who Liked You").font(.headline).foregroundStyle(.white)
                    Text("View interested users").font(.caption).foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.5))
            }
            .padding()
            .background(
                LinearGradient(colors: [.orange.opacity(0.8), .yellow.opacity(0.6)], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.3), lineWidth: 1))
            .shadow(radius: 5)
        }
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
                .font(.headline)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.top, 40)
    }
}

// MARK: - Helper Cards (Preserved Logic)

struct OfferCard: View {
    let offer: TradeOffer
    @State private var isProcessing = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Trade Offer").font(.caption).bold().foregroundStyle(.cyan)
                Spacer()
                Text(offer.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2).foregroundStyle(.gray)
            }
            HStack {
                itemVisual(item: offer.offeredItem, label: "They Offer")
                Image(systemName: "arrow.left.arrow.right").font(.title2).foregroundStyle(.white.opacity(0.5))
                itemVisual(item: offer.wantedItem, label: "For Your")
            }
            Divider().background(Color.white.opacity(0.1))
            HStack(spacing: 12) {
                Button("Decline") { handleResponse(accept: false) }.buttonStyle(.bordered).tint(.red).disabled(isProcessing)
                Button("Accept") { handleResponse(accept: true) }.buttonStyle(.borderedProminent).tint(.green).disabled(isProcessing)
            }
        }
        .padding().background(.ultraThinMaterial).cornerRadius(16)
    }
    
    func itemVisual(item: TradeItem?, label: String) -> some View {
        VStack {
            AsyncImageView(filename: item?.imageUrl).frame(width: 60, height: 60).cornerRadius(8)
            Text(item?.title ?? "Unknown").font(.caption).bold().lineLimit(1).foregroundStyle(.white)
            Text(label).font(.caption2).foregroundStyle(.gray)
        }.frame(maxWidth: .infinity)
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
