import SwiftUI
import PhotosUI
import CoreLocation

struct AddItemView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userManager = UserManager.shared
    
    @Binding var isPresented: Bool
    
    // Form State
    @State private var title = ""
    @State private var description = ""
    @State private var category = "Electronics"
    @State private var condition = "Good"
    
    // Donation Toggle
    @State private var isDonation = false
    
    // Image Handling
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showSourceSelection = false
    
    // AI State
    @State private var isAnalyzing = false
    
    // Error & Loading State
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    // Categories & Conditions
    let categories = [
        "Electronics", "Video Games", "Fashion", "Shoes",
        "Books", "Sports", "Home & Garden", "Collectibles", "Other"
    ]
    let conditions = ["New", "Like New", "Good", "Fair", "Poor"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // 1. HERO IMAGE SECTION
                    ZStack {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 300)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .overlay(
                                    Button(action: { showSourceSelection = true }) {
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.system(size: 32))
                                            .foregroundStyle(.white)
                                            .background(Circle().fill(.black.opacity(0.4)))
                                    }
                                    .padding(16),
                                    alignment: .bottomTrailing
                                )
                        } else {
                            Button(action: { showSourceSelection = true }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 0)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(height: 250)
                                    
                                    VStack(spacing: 12) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 50))
                                            .foregroundStyle(.cyan)
                                            .shadow(color: .cyan.opacity(0.3), radius: 10)
                                        
                                        Text("Tap to Add Photo")
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        
                                        Text("AI will auto-fill details")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 4)
                                            .background(Capsule().fill(.ultraThinMaterial))
                                    }
                                }
                            }
                        }
                        
                        // AI Loading Overlay
                        if isAnalyzing {
                            ZStack {
                                Color.black.opacity(0.6)
                                VStack(spacing: 12) {
                                    ProgressView().tint(.white)
                                    Text("Analyzing Image...")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(height: selectedImage == nil ? 250 : 300)
                        }
                    }
                    
                    // 2. INPUT FIELDS
                    VStack(spacing: 20) {
                        
                        Picker("Listing Type", selection: $isDonation) {
                            Text("Trade").tag(false)
                            Text("Donate").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 4)
                        
                        // Title Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TITLE")
                                .font(.caption).bold()
                                .foregroundStyle(.secondary)
                            
                            TextField("e.g. iPhone 13 Pro Max", text: $title)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                        
                        // Description Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DESCRIPTION")
                                .font(.caption).bold()
                                .foregroundStyle(.secondary)
                            
                            TextField("Describe your item...", text: $description, axis: .vertical)
                                .lineLimit(4...8)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                        
                        // Horizontal Selectors (Category & Condition)
                        HStack(spacing: 16) {
                            // Category
                            VStack(alignment: .leading, spacing: 8) {
                                Text("CATEGORY")
                                    .font(.caption).bold()
                                    .foregroundStyle(.secondary)
                                
                                Menu {
                                    ForEach(categories, id: \.self) { cat in
                                        Button(cat) { category = cat }
                                    }
                                } label: {
                                    HStack {
                                        Text(category)
                                            .lineLimit(1)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                                .foregroundStyle(.primary)
                            }
                            
                            // Condition
                            VStack(alignment: .leading, spacing: 8) {
                                Text("CONDITION")
                                    .font(.caption).bold()
                                    .foregroundStyle(.secondary)
                                
                                Menu {
                                    ForEach(conditions, id: \.self) { cond in
                                        Button(cond) { condition = cond }
                                    }
                                } label: {
                                    HStack {
                                        Text(condition)
                                            .lineLimit(1)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                                .foregroundStyle(.primary)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // 3. ACTION BUTTON
                    Button(action: saveItem) {
                        if isSaving {
                            HStack {
                                Text("Posting...")
                                ProgressView().tint(.white)
                            }
                            .font(.headline).bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .foregroundStyle(.white)
                            .cornerRadius(16)
                        } else {
                            Text(isDonation ? "Post Donation" : "Post Listing")
                                .font(.headline).bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isValid ? (isDonation ? Color.green : Color.cyan) : Color.gray.opacity(0.3))
                                .foregroundStyle(.white)
                                .cornerRadius(16)
                                .shadow(color: isValid ? (isDonation ? .green.opacity(0.4) : .cyan.opacity(0.4)) : .clear, radius: 10, y: 5)
                        }
                    }
                    .disabled(!isValid || isSaving)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .principal) {
                    Text(isDonation ? "New Donation" : "New Listing").font(.headline)
                }
            }
            // MARK: - PRESENTATION MODIFIERS
            
            // Source Selection
            .confirmationDialog("Add Photo", isPresented: $showSourceSelection) {
                Button("Camera") { showCamera = true }
                Button("Photo Library") { showPhotoPicker = true }
                Button("Cancel", role: .cancel) { }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(selectedImage: $selectedImage)
                    .ignoresSafeArea()
            }
            // Photo Picker
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
            .onChange(of: selectedItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            self.selectedImage = image
                            analyzeImage()
                        }
                    }
                }
            }
            // Auto-Analyze
            .onChange(of: selectedImage) { _ in
                if title.isEmpty && !isAnalyzing {
                    analyzeImage()
                }
            }
            // Error Alert
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Helpers
    
    var isValid: Bool {
        !title.isEmpty && selectedImage != nil
    }
    
    // MARK: - LOGIC
    
    func analyzeImage() {
        guard selectedImage != nil else { return }
        isAnalyzing = true
        
        Task {
            // Simulate AI Delay
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            await MainActor.run {
                self.isAnalyzing = false
                print("🤖 AI Analysis Complete")
            }
        }
    }
    
    func saveItem() {
        // Ensure we have user and image
        guard let userId = userManager.currentUser?.id else { return }
        guard let inputImage = selectedImage else { return }
        
        let latitude = LocationManager.shared.userLocation?.coordinate.latitude ?? 0.0
        let longitude = LocationManager.shared.userLocation?.coordinate.longitude ?? 0.0
        
        isSaving = true
        
        Task {
            do {
                // Warning Fix: 'inputImage' is now explicitly captured and used
                let imageUrl = try await DatabaseService.shared.uploadImage(inputImage)
                
                let newItem = TradeItem(
                    id: UUID(),
                    ownerId: userId,
                    title: title,
                    description: description,
                    condition: condition,
                    category: category,
                    imageUrl: imageUrl,
                    createdAt: Date(),
                    isDonation: isDonation,
                    distance: 0.0,
                    latitude: latitude,
                    longitude: longitude
                )
                
                try await DatabaseService.shared.createItem(item: newItem)
                
                Haptics.shared.playSuccess()
                await MainActor.run {
                    isSaving = false
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to post: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }
}
