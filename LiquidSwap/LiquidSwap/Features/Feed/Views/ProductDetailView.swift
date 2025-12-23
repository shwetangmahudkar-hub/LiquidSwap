import SwiftUI

struct ProductDetailView: View {
    let item: TradeItem
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header Image - FIXED: Uses imageUrl
                AsyncImageView(filename: item.imageUrl)
                    .frame(height: 350)
                    .frame(maxWidth: .infinity)
                    .clipped()
                
                // Content
                VStack(alignment: .leading, spacing: 20) {
                    // Title Row
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.title)
                                .font(.largeTitle)
                                .bold()
                            
                            Text(item.category)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        
                        // Condition Badge
                        Text(item.condition)
                            .font(.caption)
                            .bold()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        
                        Text(item.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }
                    
                    // Location / Distance
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.cyan)
                        Text("\(String(format: "%.1f", item.distance)) km away")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 10)
                    
                    Spacer(minLength: 50)
                }
                .padding(24)
            }
        }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .topLeading) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
                    .padding()
            }
        }
    }
}

#Preview {
    ProductDetailView(item: TradeItem.generateMockItems()[0])
}
