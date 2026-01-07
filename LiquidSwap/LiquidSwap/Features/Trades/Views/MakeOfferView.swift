import SwiftUI

struct MakeOfferView: View {
    @Environment(\.dismiss) var dismiss
    
    // Managers
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var tradeManager = TradeManager.shared
    
    // Data Inputs (Real Models)
    let targetItem: TradeItem
    let targetUser: UserProfile?
    
    // Selection State
    @State private var selectedItemIds: Set<UUID> = []
    @State private var tradeNote: String = ""
    
    // UI State
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    // Layout
    private let gridColumns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    // ✨ LOGIC: Identify items already in active trades
    // Prevents double-booking items (Rule 4 & 7)
    var busyItemIds: Set<UUID> {
        guard let myId = userManager.currentUser?.id else { return [] }
        var ids = Set<UUID>()
        
        for trade in tradeManager.activeTrades {
            // Case 1: I sent the offer (Pending or Accepted) - ✨ Issue #10: Use enum
            if trade.senderId == myId && trade.status.isCommitted {
                ids.insert(trade.offeredItemId)
                trade.additionalOfferedItemIds.forEach { ids.insert($0) }
            }
            
            // Case 2: I received an offer AND Accepted it - ✨ Issue #10: Use enum
            if trade.receiverId == myId && trade.status == .accepted {
                ids.insert(trade.wantedItemId)
                trade.additionalWantedItemIds.forEach { ids.insert($0) }
            }
        }
        return ids
    }
    
    var body: some View {
        ZStack {
            // 1. Background
            LiquidBackground()
                .opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 2. Minimalist Header (Rule 4: No Close Button)
                VStack(spacing: 12) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 40, height: 4)
                        .padding(.top, 10)
                    
                    Text("Build Your Offer")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .cyan.opacity(0.5), radius: 10)
                }
                .padding(.bottom, 20)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // 3. TARGET ITEM
                        VStack(alignment: .leading, spacing: 12) {
                            Text("YOU WANT")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.cyan)
                                .padding(.horizontal, 8)
                            
                            HStack(spacing: 16) {
                                AsyncImageView(filename: targetItem.imageUrl)
                                    .scaledToFill()
                                    .frame(width: 70, height: 70)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(targetItem.title)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .lineLimit(2)
                                    
                                    HStack {
                                        Text(targetItem.category)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.7))
                                        
                                        if let user = targetUser {
                                            Text("• @\(user.username)")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.5))
                                        }
                                    }
                                }
                                Spacer()
                            }
                            .padding(16)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                        
                        // 4. YOUR INVENTORY
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("YOU OFFER")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(.purple)
                                
                                Spacer()
                                
                                if !selectedItemIds.isEmpty {
                                    Text("\(selectedItemIds.count) Selected")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white.opacity(0.8))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.purple.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, 8)
                            
                            if userManager.userItems.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "cube.box")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.white.opacity(0.2))
                                    Text("Your inventory is empty.")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(40)
                                .background(.ultraThinMaterial)
                                .cornerRadius(20)
                            } else {
                                LazyVGrid(columns: gridColumns, spacing: 16) {
                                    ForEach(userManager.userItems) { item in
                                        let isBusy = busyItemIds.contains(item.id)
                                        
                                        Button(action: {
                                            if !isBusy {
                                                toggleSelection(item)
                                            } else {
                                                Haptics.shared.playError()
                                            }
                                        }) {
                                            InventoryItemCard(item: item, isSelected: selectedItemIds.contains(item.id))
                                                // ✨ BUSY OVERLAY (Consistent with QuickOffer)
                                                .overlay(
                                                    ZStack {
                                                        if isBusy {
                                                            Color.black.opacity(0.6)
                                                                .cornerRadius(16)
                                                            VStack(spacing: 4) {
                                                                Image(systemName: "lock.fill")
                                                                Text("PENDING")
                                                                    .font(.system(size: 10, weight: .black))
                                                            }
                                                            .foregroundStyle(.white.opacity(0.8))
                                                        }
                                                    }
                                                )
                                                .saturation(isBusy ? 0 : 1)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(isBusy)
                                    }
                                }
                            }
                        }
                        
                        // 5. TRADE NOTE
                        VStack(alignment: .leading, spacing: 12) {
                            Text("MESSAGE (OPTIONAL)")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.horizontal, 8)
                            
                            TextField("Add a note about this trade...", text: $tradeNote, axis: .vertical)
                                .lineLimit(3...6)
                                .padding(16)
                                .background(Color.black.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                                .foregroundStyle(.white)
                                .tint(.cyan)
                        }
                        
                        Spacer(minLength: 120)
                    }
                    .padding(20)
                }
            }
            
            // 6. BOTTOM ACTION BAR (Floating)
            VStack {
                Spacer()
                VStack(spacing: 0) {
                    // Summary Line
                    if !selectedItemIds.isEmpty {
                        HStack(spacing: 4) {
                            Text("Offering")
                                .foregroundStyle(.white.opacity(0.6))
                            Text("\(selectedItemIds.count) items")
                                .bold()
                                .foregroundStyle(.white)
                        }
                        .font(.caption)
                        .padding(.bottom, 12)
                    }
                    
                    Button(action: sendOffer) {
                        ZStack {
                            Capsule()
                                .fill(isValid ? Color.cyan : Color.white.opacity(0.1))
                                .frame(height: 56)
                                .shadow(color: isValid ? .cyan.opacity(0.4) : .clear, radius: 10, y: 5)
                            
                            if isSending {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                HStack {
                                    Text("Send Offer")
                                        .font(.headline.bold())
                                    Image(systemName: "paperplane.fill")
                                        .font(.subheadline)
                                }
                                .foregroundStyle(isValid ? .black : .white.opacity(0.3))
                            }
                        }
                    }
                    .disabled(!isValid || isSending)
                }
                .padding(24)
                .background(
                    LinearGradient(colors: [.black.opacity(0), .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                )
            }
        }
        .alert("Offer Sent!", isPresented: $showSuccess) {
            Button("Done") { dismiss() }
        } message: {
            Text("The owner has been notified.")
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }
    
    // MARK: - Logic
    
    var isValid: Bool {
        return !selectedItemIds.isEmpty
    }
    
    func toggleSelection(_ item: TradeItem) {
        if selectedItemIds.contains(item.id) {
            selectedItemIds.remove(item.id)
            Haptics.shared.playLight()
        } else {
            selectedItemIds.insert(item.id)
            Haptics.shared.playLight()
        }
    }
    
    func sendOffer() {
        guard isValid else { return }
        isSending = true
        
        let mySelectedItems = userManager.userItems.filter { selectedItemIds.contains($0.id) }
        
        Task {
            let success = await tradeManager.sendMultiItemOffer(
                wantedItems: [targetItem],
                offeredItems: mySelectedItems
            )
            
            await MainActor.run {
                isSending = false
                if success {
                    Haptics.shared.playSuccess()
                    showSuccess = true
                } else {
                    Haptics.shared.playError()
                    errorMessage = "Failed to send offer. You may already have a pending trade."
                }
            }
        }
    }
}
