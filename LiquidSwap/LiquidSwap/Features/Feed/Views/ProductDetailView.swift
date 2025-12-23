//
//  ProductDetailView.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-22.
//


import SwiftUI

struct ProductDetailView: View {
    let item: TradeItem
    // Environment value to handle the "Back" action
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Layer 1: Background (Dimmed slightly for readability)
            LiquidBackground()
                .opacity(0.3)
            
            // Layer 2: Scrollable Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Large Hero Image Area
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 30)
                            .fill(item.color.opacity(0.3))
                            .frame(height: 350)
                            .overlay(
                                Image(systemName: item.systemImage)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(80)
                                    .foregroundStyle(.white)
                                    .shadow(radius: 20)
                            )
                        
                        // "Glass" Title Overlay
                        GlassCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(.white)
                                Text(item.category.uppercased())
                                    .font(.caption)
                                    .bold()
                                    .foregroundStyle(.cyan)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                    }
                    
                    // Details Section
                    GlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            // Owner Info Row
                            HStack {
                                Circle()
                                    .fill(.white.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(item.ownerName.prefix(1))
                                            .bold()
                                            .foregroundStyle(.white)
                                    )
                                
                                VStack(alignment: .leading) {
                                    Text("Owned by")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.6))
                                    Text(item.ownerName)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }
                                
                                Spacer()
                                
                                // Distance Badge
                                HStack(spacing: 4) {
                                    Image(systemName: "location.fill")
                                    Text(item.distance)
                                }
                                .font(.subheadline)
                                .foregroundStyle(.cyan)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(10)
                            }
                            
                            Divider().background(.white.opacity(0.2))
                            
                            // Description Text
                            Text("About this item")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            Text(item.description)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.8))
                                .lineSpacing(5) // Improves readability on glass
                        }
                    }
                    .padding(.horizontal)
                    
                    // Safety / Report Section (Requirement 7.2 from docs)
                    Button(action: { print("Report Item Tapped") }) {
                        HStack {
                            Image(systemName: "flag.fill")
                            Text("Report this item")
                        }
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        // Custom Navigation Bar
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.8))
                        .shadow(radius: 5)
                }
            }
        }
    }
}

#Preview {
    ProductDetailView(item: TradeItem.mockData[0])
}