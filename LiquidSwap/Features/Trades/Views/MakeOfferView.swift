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
    
    var body: some View {
        ZStack {
            // 1. Background
            LiquidBackground()
                .opacity(0.6)
            
            VStack(spacing: 0) {
                // 2. Custom Header
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
                    
                    Text("Build Your Offer")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .cyan.opacity(0.5), radius: 10)
                    
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                ScrollView {
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
                                    .frame(width: 80, height: 80)
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
                        }
                        
                        // 4. YOUR INVENTORY
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("YOU OFFER")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(.purple)
                                
                                Spacer()
                                
                                Text("\(selectedItemIds.count) Selected")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white.opacity(0.6))
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
                                LazyVGrid(columns: gridColumns, spacing: 12) {
                                    ForEach(userManager.userItems) { item in
                                        SelectableItemCard(
                                            item: item,
                                            isSelected: selectedItemIds.contains(item.id)
                                        ) {
                                            toggleSelection(item)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 5. TRADE NOTE
                        VStack(alignment: .leading, spacing: 12) {
                            Text("MESSAGE TO SELLER (OPTIONAL)")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.horizontal, 8)
                            
                            TextField("Add a note about this trade...", text: $tradeNote, axis: .vertical)
                                .lineLimit(3...6)
                                .padding(16)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .foregroundStyle(.white)
                                .tint(.cyan)
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(20)
                }
            }
            
            // 6. BOTTOM ACTION BAR
            VStack {
                Spacer()
                VStack(spacing: 0) {
                    if !selectedItemIds.isEmpty {
                        HStack {
                            Text("Trading")
                                .foregroundStyle(.white.opacity(0.6))
                            Text("\(selectedItemIds.count) items")
                                .bold()
                                .foregroundStyle(.white)
                            Text("for")
                                .foregroundStyle(.white.opacity(0.6))
                            Text("1 item")
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
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.title3)
                                }
                                .foregroundStyle(isValid ? .black : .white.opacity(0.3))
                            }
                        }
                    }
                    .disabled(!isValid || isSending)
                }
                .padding(20)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .mask(LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .bottom, endPoint: .top))
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

// Subview for Item Cards
struct SelectableItemCard: View {
    let item: TradeItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    AsyncImageView(filename: item.imageUrl)
                        .scaledToFill()
                        .frame(height: 110)
                        .clipped()
                        .overlay(Color.black.opacity(isSelected ? 0.2 : 0))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        Text(item.category)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.purple : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                )
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.purple)
                        .background(Circle().fill(.white))
                        .padding(8)
                }
            }
            .scaleEffect(isSelected ? 0.96 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
