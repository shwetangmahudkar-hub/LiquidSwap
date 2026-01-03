//
//  InventoryItemCard.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-26.
//


import SwiftUI

struct InventoryItemCard: View {
    let title: String
    let imageUrl: String?
    let condition: String
    let isSelected: Bool
    
    // Initializer for raw strings (used in mocks or simple views)
    init(title: String, imageUrl: String?, condition: String, isSelected: Bool = false) {
        self.title = title
        self.imageUrl = imageUrl
        self.condition = condition
        self.isSelected = isSelected
    }
    
    // Convenience Initializer for TradeItem
    init(item: TradeItem, isSelected: Bool = false) {
        self.title = item.title
        self.imageUrl = item.imageUrl
        self.condition = item.condition
        self.isSelected = isSelected
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image Area
            ZStack {
                Color.gray.opacity(0.2)
                if let url = imageUrl {
                    AsyncImageView(filename: url)
                } else {
                    Image(systemName: "cube.box.fill")
                        .foregroundStyle(.white.opacity(0.3))
                        .font(.largeTitle)
                }
                
                // Selection Overlay
                if isSelected {
                    ZStack {
                        Color.black.opacity(0.3)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.cyan)
                    }
                }
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .clipped()
            
            // Text Area
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(condition)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(8)
            .background(isSelected ? Color.cyan.opacity(0.2) : Color.clear)
        }
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.cyan : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
        )
    }
}