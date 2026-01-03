import SwiftUI
import PhotosUI
import CoreLocation

struct AddItemView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userManager = UserManager.shared
    
    // Binding to control presentation from parent
    @Binding var isPresented: Bool
    
    // Form State
    @State private var title = ""
    @State private var description = ""
    @State private var category = "Electronics"
    @State private var condition = "Good"
    @State private var estimatedValue = "" // Price Input
    
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
    
    // Data Sources
    let categories = [
        "Electronics", "Video Games", "Fashion", "Shoes",
        "Books", "Sports", "Home & Garden", "Collectibles", "Other"
    ]
    let conditions = ["New", "Like New", "Good", "Fair", "Poor"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. Global Background
                LiquidBackground().ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Header Spacer
                        Spacer().frame(height: 20)
                        
                        // 2. Image Picker Section
                        imageSection
                        
                        // 3. AI Analysis Button (Premium Feature)
                        if userManager.isPremium {
                            aiAnalyzeButton
                        }
                        
                        // 4. Form Fields
                        VStack(spacing: 20) {
                            LocalGlassTextField(icon: "tag.fill", placeholder: "Item Title (e.g., AirPods Pro)", text: $title)
                            
                            LocalGlassTextEditor(icon: "text.alignleft", placeholder: "Describe your item...", text: $description)
                            
                            // Category & Condition
                            HStack(spacing: 12) {
                                LocalGlassPicker(icon: "square.grid.2x2.fill", title: "Category", selection: $category, options: categories)
                                LocalGlassPicker(icon: "star.fill", title: "Condition", selection: $condition, options: conditions)
                            }
                            
                            // Value / Donation Section
                            HStack(spacing: 16) {
                                Toggle(isOn: $isDonation) {
                                    HStack {
                                        Image(systemName: "gift.fill")
                                            .foregroundStyle(.pink)
                                        Text("Donation")
                                            .appFont(16, weight: .medium)
                                            .foregroundStyle(.white)
                                    }
                                }
                                .toggleStyle(SwitchToggleStyle(tint: .pink))
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                
                                if !isDonation {
                                    LocalGlassTextField(icon: "dollarsign.circle.fill", placeholder: "Value", text: $estimatedValue)
                                        .keyboardType(.decimalPad)
                                        .frame(width: 120)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer().frame(height: 100)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                
                // 5. Floating Save Button
                VStack {
                    Spacer()
                    Button(action: saveItem) {
                        ZStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Text("Post Item")
                                    .appFont(18, weight: .bold)
                                    .foregroundStyle(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.cyan)
                        .clipShape(Capsule())
                        .shadow(color: .cyan.opacity(0.5), radius: 20, x: 0, y: 10)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                    }
                    .disabled(title.isEmpty || selectedImage == nil || isSaving)
                    .opacity((title.isEmpty || selectedImage == nil) ? 0.5 : 1.0)
                }
                
                // Error Overlay
                if let error = errorMessage {
                    VStack {
                        Text(error)
                            .appFont(14, weight: .bold)
                            .foregroundStyle(.white)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(10)
                            .padding(.top, 60)
                        Spacer()
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            errorMessage = nil
                        }
                    }
                }
            }
            .navigationTitle("New Listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            // Image Source Sheet
            .confirmationDialog("Select Photo", isPresented: $showSourceSelection) {
                Button("Camera") { showCamera = true }
                Button("Photo Library") { showPhotoPicker = true }
                Button("Cancel", role: .cancel) { }
            }
            // Sheets
            .sheet(isPresented: $showCamera) {
                CameraPicker(selectedImage: $selectedImage)
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
            .onChange(of: selectedItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run { self.selectedImage = image }
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    var imageSection: some View {
        Button(action: { showSourceSelection = true }) {
            ZStack {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    // Edit Badge
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "pencil.circle.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .shadow(radius: 5)
                                .padding(12)
                        }
                        Spacer()
                    }
                } else {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.black.opacity(0.3))
                        .frame(height: 250)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [10]))
                                .foregroundStyle(Color.white.opacity(0.3))
                        )
                    
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.cyan)
                        
                        Text("Add Photo")
                            .appFont(16, weight: .bold)
                            .foregroundStyle(.white)
                        
                        Text("Tap to select")
                            .appFont(14)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal)
            .shadow(color: .black.opacity(0.2), radius: 15, y: 10)
        }
    }
    
    var aiAnalyzeButton: some View {
        Button(action: analyzeImage) {
            HStack(spacing: 8) {
                if isAnalyzing {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(isAnalyzing ? "Analyzing..." : "Auto-Fill with AI")
            }
            .appFont(14, weight: .bold)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(Capsule())
            .shadow(color: .purple.opacity(0.5), radius: 10, x: 0, y: 5)
        }
        .disabled(selectedImage == nil || isAnalyzing)
        .opacity(selectedImage == nil ? 0.0 : 1.0)
        .animation(.spring(), value: selectedImage)
    }
    
    // MARK: - Actions
    
    func analyzeImage() {
        // ✨ Placeholder for future AI integration
        // Requires ImageAnalyzer to have a shared singleton
        guard selectedImage != nil else { return }
        isAnalyzing = true
        
        // Simulating analysis delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isAnalyzing = false
            title = "Detected Item"
            category = "Electronics"
            Haptics.shared.playSuccess()
        }
    }
    
    func saveItem() {
        guard let image = selectedImage else { return }
        guard let user = userManager.currentUser else { return }
        guard let location = LocationManager.shared.userLocation?.coordinate else {
            errorMessage = "Please enable location to post."
            return
        }
        
        isSaving = true
        Haptics.shared.playMedium()
        
        Task {
            do {
                // 1. Upload Image
                let imageUrl = try await DatabaseService.shared.uploadImage(image)
                
                // 2. Prepare Data
                // If Donation, price is nil or 0. If not, parse the text.
                let finalPrice: Double? = isDonation ? nil : Double(estimatedValue)
                
                // 3. Init TradeItem with the new fields
                let newItem = TradeItem(
                    id: UUID(),
                    ownerId: user.id,
                    title: title,
                    description: description.isEmpty ? "No description provided." : description,
                    condition: condition, // Passed correctly
                    category: category,
                    imageUrl: imageUrl,
                    createdAt: Date(),
                    price: finalPrice,    // Passed correctly
                    isDonation: isDonation,
                    distance: 0.0,        // UI default
                    latitude: location.latitude,
                    longitude: location.longitude,
                    
                    // Owner info (Optimistic update for UI, not saved to DB items table)
                    ownerRating: 0.0,
                    ownerReviewCount: 0,
                    ownerUsername: user.username,
                    ownerIsVerified: user.isVerified,
                    ownerTradeCount: 0,
                    ownerIsPremium: user.isPremium
                )
                
                // 4. Save to DB
                try await DatabaseService.shared.createItem(item: newItem)
                
                await MainActor.run {
                    isSaving = false
                    Haptics.shared.playSuccess()
                    dismiss()
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to post item: \(error.localizedDescription)"
                    Haptics.shared.playError()
                }
            }
        }
    }
    
    // MARK: - Reusable Glass Components (Locally Scoped)
    
    struct LocalGlassTextField: View {
        let icon: String
        let placeholder: String
        @Binding var text: String
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(.cyan)
                    .frame(width: 24)
                
                TextField(placeholder, text: $text)
                    .placeholder(when: text.isEmpty) {
                        Text(placeholder).foregroundStyle(.white.opacity(0.4))
                    }
                    .foregroundStyle(.white)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
    }
    
    struct LocalGlassTextEditor: View {
        let icon: String
        let placeholder: String
        @Binding var text: String
        
        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(.cyan)
                    .frame(width: 24)
                    .padding(.top, 4)
                
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.top, 8)
                    }
                    
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(.white)
                        .frame(height: 100)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
    }
    
    struct LocalGlassPicker: View {
        let icon: String
        let title: String
        @Binding var selection: String
        let options: [String]
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1)
                
                Menu {
                    ForEach(options, id: \.self) { option in
                        Button(action: { selection = option }) {
                            HStack {
                                Text(option)
                                if option == selection {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .foregroundStyle(.cyan)
                        
                        Text(selection)
                            .appFont(14, weight: .medium)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(14)
                    .background(.ultraThinMaterial)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
