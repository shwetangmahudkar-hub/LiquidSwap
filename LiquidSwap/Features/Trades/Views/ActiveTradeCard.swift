//
//  ActiveTradeCard.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-26.
//


import SwiftUI

struct ActiveTradeCard: View {
    let trade: TradeOffer
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Color.cyan.opacity(0.2)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundStyle(.cyan)
            }
            .frame(width: 50, height: 50)
            .cornerRadius(25)
            
            // Text Details
            VStack(alignment: .leading, spacing: 4) {
                Text(trade.offeredItem?.title ?? "Unknown Item")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                HStack {
                    Text("trading for")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Text(trade.wantedItem?.title ?? "Unknown")
                        .font(.caption).bold()
                        .foregroundStyle(.white)
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .foregroundStyle(.gray)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}