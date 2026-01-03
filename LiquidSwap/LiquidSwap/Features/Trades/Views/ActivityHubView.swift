import SwiftUI

struct ActivityHubView: View {
    @Environment(\.dismiss) var dismiss
    @State private var events: [ActivityEvent] = []
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var selectedEvent: ActivityEvent?
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackground()
                
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 16) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        Text("Activity Hub")
                            .font(.largeTitle).bold()
                            .foregroundStyle(.white)
                        
                        Spacer()
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    
                    if isLoading && events.isEmpty {
                        Spacer()
                        ProgressView().tint(.white).scaleEffect(1.2)
                        Spacer()
                    } else if events.isEmpty {
                        // Empty State
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "bell.slash.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.3))
                            Text("No new activity")
                                .font(.title3).bold()
                                .foregroundStyle(.white)
                            Text("When users swipe right on your items,\nthey will appear here.")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white.opacity(0.7))
                            Spacer()
                        }
                        .padding()
                    } else {
                        // List Content
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(events) { event in
                                    GamifiedActivityRow(event: event)
                                        .onTapGesture {
                                            selectedEvent = event
                                        }
                                }
                            }
                            .padding()
                        }
                        .refreshable { loadActivity() }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedEvent) { event in
                ActivityDetailSheet(event: event)
                    .presentationDetents([.fraction(0.95)])
            }
            .task { loadActivity() }
        }
    }
    
    func loadActivity() {
        guard let currentUserId = UserManager.shared.currentUser?.id else { return }
        if events.isEmpty { isLoading = true }
        
        Task {
            do {
                let fetchedEvents = try await DatabaseService.shared.fetchActivityEvents(for: currentUserId)
                await MainActor.run {
                    withAnimation {
                        self.events = fetchedEvents
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.loadError = error
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Row Component
struct GamifiedActivityRow: View {
    let event: ActivityEvent
    @State private var actorTradeCount: Int = 0
    @State private var isActorPremium: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar & Rank Ring
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 3)
                    .frame(width: 54, height: 54)
                
                AsyncImageView(filename: event.actor.avatarUrl)
                    .frame(width: 46, height: 46)
                    .clipShape(Circle())
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Circle().fill(.red))
                    }
                }
            }
            .frame(width: 54, height: 54)
            
            // Text Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(event.actor.username)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    if event.actor.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(.cyan)
                    }
                    
                    Spacer()
                    Text(event.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Text("Liked your **\(event.item.title)**")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
            
            // Item Thumbnail
            AsyncImageView(filename: event.item.imageUrl)
                .frame(width: 44, height: 44)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.3), lineWidth: 1))
        }
        .padding()
        .background(Color.black.opacity(0.4))
        .cornerRadius(20)
    }
}

// MARK: - Detail Sheet
struct ActivityDetailSheet: View {
    let event: ActivityEvent
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("View Mode", selection: $selectedTab) {
                Text("Profile").tag(0)
                Text("Build a Deal").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            .background(Color.black.opacity(0.8))
            
            if selectedTab == 0 {
                PublicProfileView(userId: event.actor.id, showActiveListings: false)
            } else {
                DirectTradeBuilder(actor: event.actor)
            }
        }
        .background(LiquidBackground())
    }
}

// Direct Builder
struct DirectTradeBuilder: View {
    let actor: UserProfile
    @State private var theirItems: [TradeItem] = []
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if isLoading {
                VStack {
                    ProgressView().tint(.cyan)
                    Text("Loading Inventory...").foregroundStyle(.gray)
                }
            } else if theirItems.isEmpty {
                Text("This user has no items to trade.")
                    .foregroundStyle(.white)
            } else {
                if let firstItem = theirItems.first {
                    // FIX: Pass TradeItem and UserProfile directly
                    MakeOfferView(targetItem: firstItem, targetUser: actor)
                }
            }
        }
        .onAppear {
            loadInventory()
        }
    }
    
    func loadInventory() {
        Task {
            if let items = try? await DatabaseService.shared.fetchUserItems(userId: actor.id) {
                await MainActor.run {
                    self.theirItems = items
                    self.isLoading = false
                }
            } else {
                await MainActor.run { isLoading = false }
            }
        }
    }
}
