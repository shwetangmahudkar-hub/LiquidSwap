import SwiftUI

struct ActiveTradeCard: View {
    let trade: TradeOffer
    
    // We need to know who is looking at the card to orient "Give" vs "Get" correctly
    private var currentUserId: UUID? {
        UserManager.shared.currentUser?.id
    }
    
    // Logic to determine orientation
    private var isReceiver: Bool {
        return trade.receiverId == currentUserId
    }
    
    // --- OUTGOING (You Give) ---
    private var outgoingItem: TradeItem? {
        isReceiver ? trade.wantedItem : trade.offeredItem
    }
    
    private var outgoingExtrasCount: Int {
        isReceiver ? trade.additionalWantedItemIds.count : trade.additionalOfferedItemIds.count
    }
    
    // --- INCOMING (You Get) ---
    private var incomingItem: TradeItem? {
        isReceiver ? trade.offeredItem : trade.wantedItem
    }
    
    private var incomingExtrasCount: Int {
        isReceiver ? trade.additionalOfferedItemIds.count : trade.additionalWantedItemIds.count
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon / Status Indicator
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .foregroundStyle(statusColor)
            }
            
            // Text Details
            VStack(alignment: .leading, spacing: 6) {
                // "You Give" Section
                HStack(spacing: 6) {
                    Text("You give:")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    HStack(spacing: 4) {
                        Text(outgoingItem?.title ?? "Unknown Item")
                            .font(.subheadline).bold()
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        if outgoingExtrasCount > 0 {
                            BundleBadge(count: outgoingExtrasCount)
                        }
                    }
                }
                
                // "You Get" Section
                HStack(spacing: 6) {
                    Text("You get:")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                    
                    HStack(spacing: 4) {
                        Text(incomingItem?.title ?? "Unknown Item")
                            .font(.headline).bold()
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        if incomingExtrasCount > 0 {
                            BundleBadge(count: incomingExtrasCount)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Status / Chevron
            VStack(alignment: .trailing, spacing: 6) {
                StatusBadge(status: trade.status)  // ✨ Issue #10: Pass enum directly
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // ✨ Issue #10: Use enum directly instead of string comparison
    var statusColor: Color {
        switch trade.status {
        case .pending: return .orange
        case .accepted: return .green
        case .rejected: return .red
        case .countered: return .purple
        case .completed: return .gray
        case .cancelled: return .gray
        }
    }
}

// MARK: - Subviews

struct BundleBadge: View {
    let count: Int
    
    var body: some View {
        Text("+\(count)")
            .font(.system(size: 10, weight: .black))
            .foregroundStyle(.black)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.8))
            .clipShape(Capsule())
    }
}

// ✨ Issue #10: Updated to accept TradeStatus enum
struct StatusBadge: View {
    let status: TradeStatus
    
    var color: Color {
        switch status {
        case .pending: return .orange
        case .accepted: return .green
        case .rejected: return .red
        case .countered: return .purple
        case .completed: return .gray
        case .cancelled: return .gray
        }
    }
    
    var body: some View {
        Text(status.displayName)  // ✨ Use enum's displayName
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(color.opacity(0.3), lineWidth: 1)
            )
    }
}
