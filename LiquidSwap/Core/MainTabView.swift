import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            // 1. The Content Layer
            Group {
                switch selectedTab {
                case 0: FeedView()
                case 1: TradesView() // CHANGED: Replaced ChatListView
                case 2: InventoryView()
                default: FeedView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 2. The Floating Glass Tab Bar
            VStack {
                Spacer()
                
                HStack(spacing: 0) {
                    TabButton(icon: "flame.fill", label: "Swap", isSelected: selectedTab == 0) { selectedTab = 0 }
                    Spacer()
                    TabButton(icon: "arrow.triangle.2.circlepath", label: "Trades", isSelected: selectedTab == 1) { selectedTab = 1 } // CHANGED ICON
                    Spacer()
                    TabButton(icon: "person.fill", label: "Profile", isSelected: selectedTab == 2) { selectedTab = 2 }
                }
                .padding(.horizontal, 30).padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .background(RoundedRectangle(cornerRadius: 30).stroke(LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                .cornerRadius(30).padding(.horizontal, 20).padding(.bottom, 10).shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            }
        }
    }
}

struct TabButton: View {
    let icon: String; let label: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 24)).foregroundStyle(isSelected ? .cyan : .gray)
                    .scaleEffect(isSelected ? 1.2 : 1.0).animation(.spring(response: 0.3), value: isSelected)
                Text(label).font(.caption2).foregroundStyle(isSelected ? .white : .gray)
            }.frame(width: 60)
        }
    }
}
