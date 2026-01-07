//
//  QuickOfferSheet.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-29.
//

import SwiftUI

struct QuickOfferSheet: View {
    // The item you are interested in (Target)
    let wantedItem: TradeItem
    
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var tradeManager = TradeManager.shared
    
    // Selection State
    @State private var selectedItemId: UUID?
    @State private var isSending = false
    @State private var showSuccess = false
    
    // ✅ NEW: Add Item Sheet State
    @State private var showAddItemSheet = false
    
    // ✨ Calculate items that are already in pending/accepted trades
    // This prevents double-booking items and saves server errors.
    var busyItemIds: Set<UUID> {
        guard let myId = userManager.currentUser?.id else { return [] }
        var ids = Set<UUID>()
        
        for trade in tradeManager.activeTrades {
            // Check active statuses - ✨ Issue #10: Use enum
            if trade.status.isCommitted {
                // Case A: I sent the offer -> My offered items are busy
                if trade.senderId == myId {
                    ids.insert(trade.offeredItemId)
                    trade.additionalOfferedItemIds.forEach { ids.insert($0) }
                }
                // Case B: I received an offer AND accepted it -> My item is promised
                // ✨ Issue #10: Use enum
                if trade.receiverId == myId && trade.status == .accepted {
                    ids.insert(trade.wantedItemId)
                    trade.additionalWantedItemIds.forEach { ids.insert($0) }
                }
            }
        }
        return ids
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LiquidBackground()
                    .opacity(0.6)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // 1. HEADER: The Item You Want (Glassmorphic)
                    VStack(spacing: 12) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 40, height: 4)
                            .padding(.top, 10)
                        
                        HStack(spacing: 16) {
                            AsyncImageView(filename: wantedItem.imageUrl)
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("YOU WANT")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(.cyan)
                                
                                Text(wantedItem.title)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                
                                Text(wantedItem.category)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    
                    // 2. YOUR INVENTORY
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SELECT AN ITEM TO OFFER")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 24)
                        
                        if userManager.userItems.isEmpty {
                            // ✅ UPDATED: Empty State with Add Item Button
                            emptyInventoryView
                        } else {
                            // ✅ UPDATED: Grid with Add Item Card
                            inventoryGridView
                        }
                    }
                    
                    Spacer()
                }
                
                // 3. ACTION BUTTON (Floating Glass)
                VStack {
                    Spacer()
                    
                    // Button Container
                    VStack(spacing: 0) {
                        Button(action: sendOffer) {
                            ZStack {
                                // Background
                                Capsule()
                                    .fill(selectedItemId != nil ? Color.cyan : Color.white.opacity(0.1))
                                    .frame(height: 56)
                                    .shadow(color: selectedItemId != nil ? .cyan.opacity(0.4) : .clear, radius: 10, y: 5)
                                
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
                                    .foregroundStyle(selectedItemId != nil ? .black : .white.opacity(0.3))
                                }
                            }
                        }
                        .disabled(selectedItemId == nil || isSending)
                    }
                    .padding(24)
                    .background(
                        LinearGradient(colors: [.black.opacity(0), .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                            .ignoresSafeArea()
                    )
                }
            }
            .navigationBarHidden(true) // Hide default nav bar for custom feel
            .onChange(of: showSuccess) { newValue in
                if newValue { dismiss() }
            }
            // ✅ NEW: Add Item Sheet (Slide-up)
            .sheet(isPresented: $showAddItemSheet) {
                AddItemView(isPresented: $showAddItemSheet)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    // MARK: - Empty Inventory View
    
    private var emptyInventoryView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.cyan.opacity(0.6))
            }
            
            // Text
            VStack(spacing: 8) {
                Text("Your inventory is empty")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
                
                Text("Add an item to make an offer")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            
            // ✅ NEW: Add Item Button (Compact, Bottom-positioned)
            Button(action: {
                Haptics.shared.playMedium()
                showAddItemSheet = true
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                    Text("Add Your First Item")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.cyan)
                .clipShape(Capsule())
                .shadow(color: .cyan.opacity(0.4), radius: 10, y: 5)
            }
            .padding(.top, 8)
            
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Inventory Grid View
    
    private var inventoryGridView: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                
                // ✅ NEW: Add Item Card (Always First)
                Button(action: {
                    Haptics.shared.playMedium()
                    showAddItemSheet = true
                }) {
                    AddItemCard()
                }
                .buttonStyle(.plain)
                
                // Existing Items
                ForEach(userManager.userItems) { myItem in
                    let isBusy = busyItemIds.contains(myItem.id)
                    let isSelected = selectedItemId == myItem.id
                    
                    // Custom Card Logic for Busy State
                    Button(action: {
                        if !isBusy {
                            withAnimation(.spring(response: 0.3)) {
                                selectedItemId = (selectedItemId == myItem.id) ? nil : myItem.id
                                Haptics.shared.playLight()
                            }
                        } else {
                            Haptics.shared.playError()
                        }
                    }) {
                        InventoryItemCard(item: myItem, isSelected: isSelected)
                            // ✨ BUSY OVERLAY
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
                            // Grayscale busy items
                            .saturation(isBusy ? 0 : 1)
                            .scaleEffect(isSelected ? 0.98 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(isBusy)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120) // Space for floating button
        }
    }
    
    // MARK: - Logic
    
    func sendOffer() {
        guard let myItemId = selectedItemId,
              let myItem = userManager.userItems.first(where: { $0.id == myItemId }) else { return }
        
        isSending = true
        
        Task {
            // Use the standard single-item offer logic (Optimized in TradeManager)
            let success = await tradeManager.sendOffer(wantedItem: wantedItem, myItem: myItem)
            
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

// MARK: - Add Item Card Component (Glassmorphism)

struct AddItemCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            
            // Plus Icon with Glow
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.cyan)
            }
            
            Text("Add Item")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.cyan.opacity(0.5), .cyan.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .overlay(
            // Dashed Inner Border
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(.cyan.opacity(0.3))
                .padding(8)
        )
    }
}
