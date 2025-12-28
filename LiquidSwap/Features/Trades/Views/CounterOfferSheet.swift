//
//  CounterOfferSheet.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-27.
//


import SwiftUI

struct CounterOfferSheet: View {
    let originalTrade: TradeOffer
    @Environment(\.dismiss) var dismiss
    
    @State private var availableItems: [TradeItem] = []
    @State private var selectedItem: TradeItem?
    @State private var isLoading = true
    @State private var isSending = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackground().opacity(0.3)
                
                if isLoading {
                    ProgressView("Loading their inventory...")
                        .tint(.white)
                        .foregroundStyle(.white)
                } else if availableItems.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "cube.box")
                            .font(.system(size: 50))
                            .foregroundStyle(.gray)
                        Text("This user has no other items to trade.")
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                } else {
                    VStack(spacing: 0) {
                        // Header Text
                        Text("Select an item to ask for instead:")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.vertical, 20)
                        
                        // Grid
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(availableItems) { item in
                                    InventoryItemCard(item: item, isSelected: selectedItem?.id == item.id)
                                        .onTapGesture {
                                            withAnimation { selectedItem = item }
                                            Haptics.shared.playLight()
                                        }
                                }
                            }
                            .padding()
                        }
                        
                        // Action Bar
                        VStack {
                            Divider().background(Color.white.opacity(0.2))
                            
                            Button(action: submitCounterOffer) {
                                HStack {
                                    if isSending {
                                        ProgressView().tint(.black)
                                    } else {
                                        Text("Send Counter Offer")
                                            .bold()
                                        Image(systemName: "arrow.2.squarepath")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(selectedItem == nil ? Color.gray : Color.cyan)
                                .foregroundStyle(.black)
                                .cornerRadius(12)
                            }
                            .disabled(selectedItem == nil || isSending)
                            .padding()
                        }
                        .background(.ultraThinMaterial)
                    }
                }
            }
            .navigationTitle("Counter Offer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                fetchTheirInventory()
            }
        }
    }
    
    // MARK: - Logic
    
    func fetchTheirInventory() {
        Task {
            isLoading = true
            // Fetch items belonging to the person who sent the original offer
            if let items = try? await DatabaseService.shared.fetchUserItems(userId: originalTrade.senderId) {
                // Filter out the item they already offered (optional, but good UX)
                let filtered = items.filter { $0.id != originalTrade.offeredItemId }
                
                await MainActor.run {
                    self.availableItems = filtered
                    self.isLoading = false
                }
            } else {
                await MainActor.run { isLoading = false }
            }
        }
    }
    
    func submitCounterOffer() {
        guard let newItem = selectedItem else { return }
        isSending = true
        
        Task {
            let success = await TradeManager.shared.sendCounterOffer(
                originalTrade: originalTrade,
                newWantedItem: newItem
            )
            
            await MainActor.run {
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
}