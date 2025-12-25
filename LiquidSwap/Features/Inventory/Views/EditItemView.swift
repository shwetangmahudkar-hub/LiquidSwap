import SwiftUI

struct EditItemView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userManager = UserManager.shared
    
    // The item we are editing
    @State var item: TradeItem
    
    @State private var isSaving = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Image (Read Only for now)
                Section {
                    HStack {
                        Spacer()
                        // CLOUD FIX: Use 'imageUrl'
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
                        ForEach(["Electronics", "Fashion", "Home & Garden", "Sports", "Books", "Other"], id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    
                    Picker("Condition", selection: $item.condition) {
                        ForEach(["New", "Like New", "Good", "Fair", "Poor"], id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                }
                
                // FEATURE: Delete Button
                Section {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Item")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .disabled(isSaving)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
            // Confirmation Alert
            .alert("Delete Item?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) { deleteItem() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
    
    func saveChanges() {
        Task {
            isSaving = true
            try? await userManager.updateItem(item)
            isSaving = false
            dismiss()
        }
    }
    
    func deleteItem() {
        Task {
            isSaving = true
            try? await userManager.deleteItem(item: item)
            isSaving = false
            dismiss()
        }
    }
}
