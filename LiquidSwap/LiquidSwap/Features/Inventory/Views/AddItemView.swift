import SwiftUI
import PhotosUI

struct AddItemView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userManager = UserManager.shared
    
    @Binding var isPresented: Bool
    
    // Form State
    @State private var title = ""
    @State private var description = ""
    @State private var category = "Electronics"
    @State private var condition = "Good"
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
    // NEW: Error & Loading State
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    let categories = ["Electronics", "Fashion", "Home & Garden", "Sports", "Books", "Other"]
    let conditions = ["New", "Like New", "Good", "Fair", "Poor"]
    
    var body: some View {
        NavigationStack {
            Form {
                ImageSelectionSection(selectedItem: $selectedItem, selectedImage: $selectedImage)
                
                ItemDetailsSection(
                    title: $title,
                    description: $description,
                    category: $category,
                    condition: $condition,
                    categories: categories,
                    conditions: conditions
                )
                
                // Show error in form if exists
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add New Item")
            .navigationBarTitleDisplayMode(.inline)
            .disabled(isSaving) // Disable interaction while saving
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await saveItem()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("List Item")
                        }
                    }
                    .disabled(title.isEmpty || selectedImage == nil || isSaving)
                }
            }
            // Handle Photo Selection
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                    }
                }
            }
            // Error Alert
            .alert("Failed to Save", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }
    
    func saveItem() async {
        guard let image = selectedImage else { return }
        
        isSaving = true
        errorMessage = nil
        
        do {
            // Wait for the upload to finish
            try await userManager.addItem(
                title: title,
                description: description.isEmpty ? "No description provided." : description,
                image: image
            )
            // Only dismiss if successful
            dismiss()
        } catch {
            // Show error
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isSaving = false
    }
}

// MARK: - Subviews
struct ImageSelectionSection: View {
    @Binding var selectedItem: PhotosPickerItem?
    @Binding var selectedImage: UIImage?
    var body: some View {
        Section {
            HStack {
                Spacer()
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    if let image = selectedImage {
                        Image(uiImage: image).resizable().scaledToFill().frame(width: 200, height: 200).cornerRadius(12).clipped()
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)).frame(width: 200, height: 200)
                            VStack { Image(systemName: "camera.fill"); Text("Tap to upload") }
                        }
                    }
                }
                Spacer()
            }
        }
    }
}

struct ItemDetailsSection: View {
    @Binding var title: String
    @Binding var description: String
    @Binding var category: String
    @Binding var condition: String
    let categories: [String]
    let conditions: [String]
    var body: some View {
        Section("Details") {
            TextField("Title", text: $title)
            TextField("Description", text: $description, axis: .vertical)
            Picker("Category", selection: $category) { ForEach(categories, id: \.self) { Text($0).tag($0) } }
            Picker("Condition", selection: $condition) { ForEach(conditions, id: \.self) { Text($0).tag($0) } }
        }
    }
}

#Preview {
    AddItemView(isPresented: .constant(true))
}
