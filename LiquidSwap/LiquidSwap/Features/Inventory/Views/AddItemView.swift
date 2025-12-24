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
    
    // Image Handling
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showCamera = false // Controls Camera sheet
    
    // AI State
    @State private var isAnalyzing = false
    @State private var showSafetyAlert = false
    
    // Error & Loading State
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    let categories = ["Electronics", "Fashion", "Home & Garden", "Sports", "Books", "Other"]
    let conditions = ["New", "Like New", "Good", "Fair", "Poor"]
    
    var body: some View {
        NavigationStack {
            Form {
                // Image Section
                Section {
                    HStack {
                        Spacer()
                        // Menu allows choosing between Camera and Library
                        Menu {
                            Button {
                                showCamera = true
                            } label: {
                                Label("Take Photo", systemImage: "camera")
                            }
                            
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Label("Choose from Library", systemImage: "photo.on.rectangle")
                            }
                        } label: {
                            ZStack {
                                if let image = selectedImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 200, height: 200)
                                        .cornerRadius(12)
                                        .clipped()
                                        .opacity(isAnalyzing ? 0.5 : 1.0)
                                    
                                    if isAnalyzing {
                                        VStack(spacing: 8) {
                                            ProgressView()
                                                .tint(.white)
                                            Text("AI Analyzing...")
                                                .font(.caption)
                                                .bold()
                                                .foregroundStyle(.white)
                                                .shadow(radius: 2)
                                        }
                                    }
                                } else {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.gray.opacity(0.1))
                                            .frame(width: 200, height: 200)
                                        VStack(spacing: 8) {
                                            Image(systemName: "camera.fill")
                                                .font(.largeTitle)
                                                .foregroundStyle(.cyan)
                                            Text("Tap to Add Photo")
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
                
                ItemDetailsSection(
                    title: $title,
                    description: $description,
                    category: $category,
                    condition: $condition,
                    categories: categories,
                    conditions: conditions
                )
                
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("Add New Item")
            .navigationBarTitleDisplayMode(.inline)
            .disabled(isSaving || isAnalyzing)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveItem() }
                    } label: {
                        if isSaving { ProgressView() } else { Text("List Item") }
                    }
                    .disabled(title.isEmpty || selectedImage == nil || isSaving)
                }
            }
            // 1. Handle Camera Presentation
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(selectedImage: $selectedImage)
                    .ignoresSafeArea()
            }
            // 2. Handle Library Selection
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                    }
                }
            }
            // 3. Trigger AI when Image Changes (Source doesn't matter)
            .onChange(of: selectedImage) { _, newImage in
                if let img = newImage {
                    Task { await analyzeImage(img) }
                }
            }
            .alert("Unsafe Content", isPresented: $showSafetyAlert) {
                Button("OK", role: .cancel) { selectedImage = nil; selectedItem = nil }
            } message: {
                Text("This image contains content that is not allowed on LiquidSwap.")
            }
            .alert("Failed to Save", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }
    
    // MARK: - AI Logic
    func analyzeImage(_ image: UIImage) async {
        isAnalyzing = true
        do {
            let labels = try await ImageAnalyzer.analyze(image: image)
            print("🤖 AI saw: \(labels)")
            
            if !ImageAnalyzer.isSafeContent(labels: labels) {
                showSafetyAlert = true
                isAnalyzing = false
                return
            }
            
            if title.isEmpty, let firstLabel = labels.first {
                withAnimation {
                    title = firstLabel.capitalized
                }
            }
            
            let suggestedCategory = ImageAnalyzer.suggestCategory(from: labels)
            withAnimation {
                category = suggestedCategory
            }
            
        } catch {
            print("AI Analysis failed: \(error)")
        }
        isAnalyzing = false
    }
    
    // MARK: - Save Logic
    func saveItem() async {
        guard let image = selectedImage else { return }
        isSaving = true
        errorMessage = nil
        
        do {
            try await userManager.addItem(
                title: title,
                description: description.isEmpty ? "No description provided." : description,
                image: image
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isSaving = false
    }
}

// Helper Subview
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
