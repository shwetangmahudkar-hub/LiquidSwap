import SwiftUI

struct MakeOfferView: View {
    // MARK: - Properties
    let targetItem: TradeItem // The item we want
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userManager = UserManager.shared
    
    // Form State
    @State private var offerMessage = ""
    @State private var selectedMyItem: TradeItem?
    @State private var isSending = false
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // 1. Dark Background + Subtle Liquid Effect
            Color.black.edgesIgnoringSafeArea(.all)
            LiquidBackground().opacity(0.3)
            
            VStack(spacing: 24) {
                // 2. Drag Handle
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 6)
                    .padding(.top, 20)
                
                // 3. Title
                Text("Make an Offer")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // 4. Target Item Summary (What you get)
                targetItemSummary
                
                Divider().background(Color.white.opacity(0.2))
                
                // 5. Inventory Selector (What you give)
                inventorySelectionSection
                
                Spacer()
                
                // 6. Action Button
                sendOfferButton
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Subviews
    
    private var targetItemSummary: some View {
        HStack(spacing: 16) {
            // Small Image
            AsyncImageView(filename: targetItem.imageUrl)
                .frame(width: 60, height: 60)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1)))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("You are offering for:")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                Text(targetItem.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(targetItem.condition)
                    .font(.caption2)
                    .foregroundColor(.cyan)
            }
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var inventorySelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select item to trade")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.9))
            
            if userManager.userItems.isEmpty {
                Text("You have no items in your inventory.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(userManager.userItems) { item in
                            InventoryItemCard(
                                item: item,
                                isSelected: selectedMyItem?.id == item.id
                            )
                            .frame(width: 110)
                            .onTapGesture {
                                withAnimation { selectedMyItem = item }
                                Haptics.shared.playLight()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var sendOfferButton: some View {
        Button(action: submitOffer) {
            HStack {
                if isSending {
                    ProgressView().tint(.black)
                } else {
                    Text("Send Offer").font(.headline)
                    Image(systemName: "paperplane.fill")
                }
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                selectedMyItem == nil
                ? LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(16)
        }
        .disabled(selectedMyItem == nil || isSending)
        .opacity(selectedMyItem == nil ? 0.6 : 1.0)
    }
    
    func submitOffer() {
        guard let myItem = selectedMyItem else { return }
        isSending = true
        
        Task {
            let success = await TradeManager.shared.sendOffer(wantedItem: targetItem, myItem: myItem)
            isSending = false
            
            if success {
                Haptics.shared.playSuccess()
                dismiss()
            } else {
                Haptics.shared.playError()
            }
        }
    }
}
