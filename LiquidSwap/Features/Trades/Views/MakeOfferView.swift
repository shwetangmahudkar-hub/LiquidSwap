//
//  MakeOfferView.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-24.
//


import SwiftUI

struct MakeOfferView: View {
    let wantedItem: TradeItem
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var tradeManager = TradeManager.shared
    
    @State private var selectedMyItemId: UUID?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Select an item to offer for\n\(wantedItem.title)")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top)
                    
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(userManager.userItems) { myItem in
                                Button(action: { selectedMyItemId = myItem.id }) {
                                    VStack {
                                        AsyncImageView(filename: myItem.imageUrl)
                                            .frame(height: 120)
                                            .frame(maxWidth: .infinity)
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(selectedMyItemId == myItem.id ? Color.cyan : Color.clear, lineWidth: 3)
                                            )
                                        
                                        Text(myItem.title)
                                            .font(.caption)
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    
                    Button(action: sendOffer) {
                        Text("Send Offer")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedMyItemId == nil ? Color.gray : Color.cyan)
                            .foregroundStyle(.black)
                            .cornerRadius(12)
                    }
                    .disabled(selectedMyItemId == nil)
                    .padding()
                }
            }
            .navigationTitle("Make Offer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    func sendOffer() {
        guard let myItemId = selectedMyItemId,
              let myItem = userManager.userItems.first(where: { $0.id == myItemId }) else { return }
        
        Task {
            let success = await tradeManager.sendOffer(wantedItem: wantedItem, myItem: myItem)
            if success { dismiss() }
        }
    }
}