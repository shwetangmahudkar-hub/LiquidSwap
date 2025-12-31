import SwiftUI

struct CounterOfferSheet: View {
    let originalTrade: TradeOffer
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userManager = UserManager.shared
    
    // Inventory State
    @State private var theirItems: [TradeItem] = []
    
    // Selection State
    @State private var selectedMyIds: Set<UUID> = []
    @State private var selectedTheirIds: Set<UUID> = []
    
    // UI State
    @State private var activeTab: TradeSide = .them
    @State private var isLoading = true
    @State private var isSending = false
    @State private var showSuccess = false
    
    // Premium State
    @State private var showPremiumPaywall = false
    
    enum TradeSide { case me, them }
    
    var isPremium: Bool {
        return userManager.currentUser?.isPremium ?? false
    }
    
    var body: some View {
        ZStack {
            // 1. Background
            Color.black.ignoresSafeArea()
            LiquidBackground()
                .opacity(0.5)
                .blur(radius: 40)
            
            VStack(spacing: 0) {
                // --- HEADER ---
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text("Negotiation")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        
                        if isPremium {
                            Text("PREMIUM UNLOCKED")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.yellow)
                                .clipShape(Capsule())
                        }
                    }
                    .shadow(color: .cyan.opacity(0.5), radius: 10)
                    
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                
                // --- TAB SWITCHER ---
                HStack(spacing: 0) {
                    TabPill(title: "You Want", count: selectedTheirIds.count, isActive: activeTab == .them) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { activeTab = .them }
                    }
                    
                    TabPill(title: "You Give", count: selectedMyIds.count, isActive: activeTab == .me) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { activeTab = .me }
                    }
                }
                .padding(4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                .padding(.horizontal, 40)
                .padding(.vertical, 24)
                
                // --- INVENTORY SCROLL VIEWS ---
                TabView(selection: $activeTab) {
                    
                    // 1. THEIR ITEMS (What I want)
                    ScrollView(showsIndicators: false) {
                        if isLoading {
                            ProgressView().tint(.cyan).padding(50)
                        } else {
                            ItemGrid(
                                items: theirItems,
                                selectedIds: $selectedTheirIds,
                                tint: .cyan,
                                limitReached: !isPremium && selectedTheirIds.count >= 1,
                                onLimitTriggered: { showPremiumPaywall = true }
                            )
                        }
                    }
                    .tag(TradeSide.them)
                    
                    // 2. MY ITEMS (What I give)
                    ScrollView(showsIndicators: false) {
                        ItemGrid(
                            items: userManager.userItems,
                            selectedIds: $selectedMyIds,
                            tint: .purple,
                            limitReached: !isPremium && selectedMyIds.count >= 1,
                            onLimitTriggered: { showPremiumPaywall = true }
                        )
                    }
                    .tag(TradeSide.me)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // --- DEAL DASHBOARD ---
                VStack(spacing: 0) {
                    // Summary Row
                    HStack {
                        VStack(alignment: .leading) {
                            Text("YOU GET")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.cyan)
                            Text("\(selectedTheirIds.count) Items")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("YOU GIVE")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.purple)
                            Text("\(selectedMyIds.count) Items")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    
                    // Send Button
                    Button(action: submitCounterOffer) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(isValidOffer ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.white.opacity(0.1)))
                                .frame(height: 56)
                            
                            if isSending {
                                ProgressView().tint(.black)
                            } else {
                                HStack {
                                    Text("Send Counter Proposal")
                                        .font(.system(size: 18, weight: .bold))
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 16))
                                }
                                .foregroundStyle(isValidOffer ? .black : .white.opacity(0.3))
                            }
                        }
                    }
                    .disabled(!isValidOffer || isSending)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)
                }
                .padding(.bottom, 20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 32).stroke(Color.white.opacity(0.15), lineWidth: 1))
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            }
        }
        .onAppear {
            loadContext()
        }
        .sheet(isPresented: $showPremiumPaywall) {
            // Ensure PremiumUpgradeSheet exists in your project, or replace with placeholder
            PremiumUpgradeSheet()
                .presentationDetents([.fraction(0.6)])
        }
        .onChange(of: showSuccess) { newValue in
            if newValue { dismiss() }
        }
    }
    
    // MARK: - Logic
    
    var isValidOffer: Bool {
        return !selectedMyIds.isEmpty && !selectedTheirIds.isEmpty
    }
    
    func loadContext() {
        Task {
            isLoading = true
            
            if let items = try? await DatabaseService.shared.fetchUserItems(userId: originalTrade.senderId) {
                await MainActor.run { self.theirItems = items }
            }
            
            await MainActor.run {
                // Pre-fill logic (Role Reversal)
                self.selectedTheirIds.insert(originalTrade.offeredItemId)
                originalTrade.additionalOfferedItemIds.forEach { self.selectedTheirIds.insert($0) }
                
                self.selectedMyIds.insert(originalTrade.wantedItemId)
                originalTrade.additionalWantedItemIds.forEach { self.selectedMyIds.insert($0) }
                
                self.isLoading = false
            }
        }
    }
    
    func submitCounterOffer() {
        guard isValidOffer else { return }
        isSending = true
        
        let mySelectedItems = userManager.userItems.filter { selectedMyIds.contains($0.id) }
        let theirSelectedItems = theirItems.filter { selectedTheirIds.contains($0.id) }
        
        Task {
            try? await DatabaseService.shared.updateTradeStatus(tradeId: originalTrade.id, status: "countered")
            
            let success = await TradeManager.shared.sendMultiItemOffer(
                wantedItems: theirSelectedItems,
                offeredItems: mySelectedItems
            )
            
            await MainActor.run {
                isSending = false
                if success {
                    Haptics.shared.playSuccess()
                    showSuccess = true
                } else {
                    Haptics.shared.playError()
                }
            }
        }
    }
}

// MARK: - Helper Views

struct ItemGrid: View {
    let items: [TradeItem]
    @Binding var selectedIds: Set<UUID>
    let tint: Color
    
    // Premium Limits
    let limitReached: Bool
    let onLimitTriggered: () -> Void
    
    var mutualMatchId: UUID? = nil
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(items, id: \.id) { item in
                let isSelected = selectedIds.contains(item.id)
                let isMutual = (item.id == mutualMatchId)
                
                Button(action: {
                    if isSelected {
                        selectedIds.remove(item.id)
                        Haptics.shared.playLight()
                    } else {
                        if limitReached {
                            Haptics.shared.playError()
                            onLimitTriggered()
                        } else {
                            selectedIds.insert(item.id)
                            Haptics.shared.playLight()
                        }
                    }
                }) {
                    ZStack(alignment: .topTrailing) {
                        // Card
                        VStack(spacing: 0) {
                            AsyncImageView(filename: item.imageUrl)
                                .scaledToFill()
                                .frame(height: 150)
                                .clipped()
                                .overlay(Color.black.opacity(isSelected ? 0.3 : 0))
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.title)
                                        .font(.caption).bold()
                                        .lineLimit(1)
                                        .foregroundStyle(.white)
                                    Text(item.category)
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(.ultraThinMaterial)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isSelected ? tint : Color.white.opacity(0.1), lineWidth: isSelected ? 3 : 1)
                        )
                        .scaleEffect(isSelected ? 0.96 : 1.0)
                        
                        // Selected Checkmark
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(tint)
                                .background(Circle().fill(.white))
                                .padding(10)
                        }
                        
                        // Lock Badge
                        if !isSelected && limitReached {
                            Image(systemName: "lock.fill")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(Circle().fill(.black.opacity(0.6)))
                                .padding(10)
                        }
                        
                        if isMutual {
                            VStack {
                                Spacer()
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .foregroundStyle(.pink)
                                    Text("THEY WANT THIS")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundStyle(.white)
                                    Spacer()
                                }
                                .padding(6)
                                .background(Color.black.opacity(0.6))
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .padding(.bottom, 100)
    }
}

// MARK: - Missing TabPill Component
struct TabPill: View {
    let title: String
    let count: Int
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isActive ? Color.white.opacity(0.3) : Color.black.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isActive ? Color.white.opacity(0.2) : Color.clear)
            .foregroundStyle(.white)
            .clipShape(Capsule())
        }
    }
}
