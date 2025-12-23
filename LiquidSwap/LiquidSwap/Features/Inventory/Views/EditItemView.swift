import SwiftUI

struct EditItemView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userManager = UserManager.shared
    
    // The item we are editing
    @State var item: TradeItem
    
    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Image (Read Only for now)
                Section {
                    HStack {
                        Spacer()
                        // FIXED: Use 'imageUrl' instead of 'imageFilename'
                        AsyncImageView(filename: item.imageUrl)
                            .frame(width: 150, height: 150)
                            .cornerRadius(12)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
                
                // Section 2: Details
                Section("Item Details") {
                    TextField("Title", text: $item.title)
                    
                    TextField("Description", text: $item.description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Picker("Category", selection: $item.category) {
                        ForEach(["Electronics", "Fashion", "Home", "Sports", "Books", "Other"], id: \.self) {
                            Text($0)
                        }
                    }
                    
                    Picker("Condition", selection: $item.condition) {
                        ForEach(["New", "Like New", "Good", "Fair", "Poor"], id: \.self) {
                            Text($0)
                        }
                    }
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        // Call the new function in UserManager
                        userManager.updateItem(item: item)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    EditItemView(item: TradeItem.generateMockItems()[0])
}
