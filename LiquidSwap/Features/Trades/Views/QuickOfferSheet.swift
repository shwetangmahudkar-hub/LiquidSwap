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
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LiquidBackground()
                    .opacity(0.6)
                
                VStack(spacing: 20) {
                    
                    // 1. HEADER: The Item You Want
                    VStack(spacing: 8) {
                        Text("You are interested in")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .textCase(.uppercase)
                        
                        HStack(spacing: 12) {
                            AsyncImageView(filename: wantedItem.imageUrl)
                                .frame(width: 60, height: 60)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
                            
                            VStack(alignment: .leading) {
                                Text(wantedItem.title)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(wantedItem.category)
                                    .font(.caption)
                                    .foregroundStyle(.cyan)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // 2. YOUR INVENTORY
                    VStack(alignment: .leading, spacing: 10) {
                        Text("OFFER AN ITEM")
                            .font(.caption)
                            .fontWeight(.black)
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 24)
                        
                        if userManager.userItems.isEmpty {
                            VStack(spacing: 12) {
                                Spacer()
                                Image(systemName: "archivebox")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white.opacity(0.2))
                                Text("Your inventory is empty")
                                    .foregroundStyle(.gray)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            ScrollView {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                    ForEach(userManager.userItems) { myItem in
                                        InventoryItemCard(item: myItem, isSelected: selectedItemId == myItem.id)
                                            .onTapGesture {
                                                withAnimation {
                                                    selectedItemId = myItem.id
                                                    Haptics.shared.playLight()
                                                }
                                            }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 100) // Space for button
                            }
                        }
                    }
                    
                    Spacer()
                }
                
                // 3. ACTION BUTTON (Floating)
                VStack {
                    Spacer()
                    Button(action: sendOffer) {
                        if isSending {
                            ProgressView().tint(.black)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.white)
                                .cornerRadius(20)
                        } else {
                            HStack {
                                Text("Offer Up")
                                    .font(.headline).bold()
                                Image(systemName: "arrow.up.circle.fill")
                            }
                            .foregroundStyle(.black)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(selectedItemId == nil ? Color.white.opacity(0.5) : Color.cyan)
                            .cornerRadius(20)
                            .shadow(color: .cyan.opacity(0.3), radius: 10)
                        }
                    }
                    .disabled(selectedItemId == nil || isSending)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Quick Offer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            // ✨ FIX: iOS 16 compatible syntax
            .onChange(of: showSuccess) { newValue in
                if newValue { dismiss() }
            }
        }
    }
    
    // MARK: - Logic
    
    func sendOffer() {
        guard let myItemId = selectedItemId,
              let myItem = userManager.userItems.first(where: { $0.id == myItemId }) else { return }
        
        isSending = true
        
        Task {
            // Use the standard single-item offer logic (Not the multi-item Builder)
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
