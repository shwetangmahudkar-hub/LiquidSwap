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
            ZStack {
                // 1. Global Background
                LiquidBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Header Spacer
                        Spacer().frame(height: 10)
                        
                        // 2. IMAGE SECTION (Glass Card)
                        imageSection
                            .padding(.horizontal, 20)
                        
                        // 3. LISTING TYPE TOGGLE
                        listingTypeToggle
                            .padding(.horizontal, 20)
                        
                        // 4. FORM FIELDS (Glass Card)
                        formFieldsSection
                            .padding(.horizontal, 20)
                        
                        // 5. CATEGORY & CONDITION (Glass Card)
                        categoryConditionSection
                            .padding(.horizontal, 20)
                        
                        // Bottom padding for button
                        Spacer().frame(height: 100)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(isDonation ? "New Donation" : "New Listing")
                        .appFont(16, weight: .bold)
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            // Bottom Action Button (Easy thumb reach)
            .safeAreaInset(edge: .bottom) {
                bottomActionButton
            }
            // MARK: - Sheets & Dialogs
            .confirmationDialog("Add Photo", isPresented: $showSourceSelection) {
                Button("Take Photo") { showCamera = true }
                Button("Choose from Library") { showPhotoPicker = true }
                if selectedImage != nil {
                    Button("Remove Photo", role: .destructive) {
                        withAnimation { selectedImage = nil }
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(selectedImage: $selectedImage)
                    .ignoresSafeArea()
            }
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
            .onChange(of: selectedImage) { _ in
                if title.isEmpty && !isAnalyzing && selectedImage != nil {
                    analyzeImage()
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Image Section
    
    private var imageSection: some View {
        ZStack {
            if let image = selectedImage {
                // Image Preview
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 280)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .overlay(
                        // Edit Button
                        Button(action: { showSourceSelection = true }) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.3), radius: 5)
                        }
                        .padding(16),
                        alignment: .bottomTrailing
                    )
                    .contextMenu {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Take New Photo", systemImage: "camera")
                        }
                        
                        Button {
                            showPhotoPicker = true
                        } label: {
                            Label("Choose from Library", systemImage: "photo.on.rectangle")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            withAnimation { selectedImage = nil }
                        } label: {
                            Label("Remove Photo", systemImage: "trash")
                        }
                    }
            } else {
                // Empty State - Add Photo
                Button(action: { showSourceSelection = true }) {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.cyan.opacity(0.15))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "camera.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.cyan)
                        }
                        
                        VStack(spacing: 6) {
                            Text("Add Photo")
                                .appFont(18, weight: .bold)
                                .foregroundStyle(.white)
                            
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12))
                                Text("AI will auto-fill details")
                                    .appFont(12)
                            }
                            .foregroundStyle(.cyan.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.cyan.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .foregroundStyle(.cyan.opacity(0.3))
                    )
                }
                .buttonStyle(.plain)
            }
            
            // AI Loading Overlay
            if isAnalyzing {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.black.opacity(0.7))
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.cyan)
                            .scaleEffect(1.3)
                        
                        Text("Analyzing Image...")
                            .appFont(14, weight: .bold)
                            .foregroundStyle(.white)
                    }
                }
                .frame(height: selectedImage == nil ? 220 : 280)
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 15, y: 8)
    }
    
    // MARK: - Listing Type Toggle
    
    private var listingTypeToggle: some View {
        HStack(spacing: 12) {
            // Trade Button
            Button(action: { withAnimation { isDonation = false } }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .bold))
                    Text("Trade")
                        .appFont(14, weight: .bold)
                }
                .foregroundStyle(isDonation ? .white.opacity(0.6) : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isDonation ? Color.white.opacity(0.1) : Color.cyan)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(isDonation ? 0.1 : 0), lineWidth: 1)
                )
            }
            
            // Donate Button
            Button(action: { withAnimation { isDonation = true } }) {
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Donate")
                        .appFont(14, weight: .bold)
                }
                .foregroundStyle(isDonation ? .black : .white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isDonation ? Color.green : Color.white.opacity(0.1))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(isDonation ? 0 : 0.1), lineWidth: 1)
                )
            }
        }
        .padding(4)
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Form Fields Section
    
    private var formFieldsSection: some View {
        VStack(spacing: 20) {
            // Title Input
            GlassFormField(
                label: "TITLE",
                placeholder: "e.g. iPhone 13 Pro Max",
                text: $title
            )
            
            // Description Input
            GlassFormField(
                label: "DESCRIPTION",
                placeholder: "Describe your item...",
                text: $description,
                isMultiline: true
            )
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }
    
    // MARK: - Category & Condition Section
    
    private var categoryConditionSection: some View {
        HStack(spacing: 12) {
            // Category Picker
            GlassPickerField(
                label: "CATEGORY",
                selection: category,
                options: categories,
                icon: "square.grid.2x2"
            ) { selected in
                category = selected
            }
            
            // Condition Picker
            GlassPickerField(
                label: "CONDITION",
                selection: condition,
                options: conditions,
                icon: "star.fill"
            ) { selected in
                condition = selected
            }
        }
    }
    
    // MARK: - Bottom Action Button
    
    private var bottomActionButton: some View {
        VStack(spacing: 0) {
            Button(action: saveItem) {
                HStack(spacing: 10) {
                    if isSaving {
                        ProgressView()
                            .tint(isDonation ? .black : .black)
                        Text("Posting...")
                            .appFont(16, weight: .bold)
                    } else {
                        Image(systemName: isDonation ? "gift.fill" : "plus.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text(isDonation ? "Post Donation" : "Post Listing")
                            .appFont(16, weight: .bold)
                    }
                }
                .foregroundStyle(isValid ? .black : .white.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Group {
                        if isValid {
                            isDonation ? Color.green : Color.cyan
                        } else {
                            Color.white.opacity(0.1)
                        }
                    }
                )
                .cornerRadius(20)
                .shadow(color: isValid ? (isDonation ? .green.opacity(0.4) : .cyan.opacity(0.4)) : .clear, radius: 15, y: 5)
            }
            .disabled(!isValid || isSaving)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.white.opacity(0.1)),
            alignment: .top
        )
    }
    
    // MARK: - Helpers
    
    var isValid: Bool {
        !title.isEmpty && selectedImage != nil
    }
    
    // MARK: - Logic
    
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
        guard let userId = userManager.currentUser?.id else { return }
        guard let inputImage = selectedImage else { return }
        
        let latitude = LocationManager.shared.userLocation?.coordinate.latitude ?? 0.0
        let longitude = LocationManager.shared.userLocation?.coordinate.longitude ?? 0.0
        
        isSaving = true
        Haptics.shared.playLight()
        
        Task {
            do {
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
                    Haptics.shared.playError()
                }
            }
        }
    }
}

// MARK: - Glass Form Field Component

struct GlassFormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isMultiline: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .appFont(10, weight: .bold)
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1)
            
            if isMultiline {
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(3...6)
                    .appFont(16)
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            } else {
                TextField(placeholder, text: $text)
                    .appFont(16)
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Glass Picker Field Component

struct GlassPickerField: View {
    let label: String
    let selection: String
    let options: [String]
    let icon: String
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .appFont(10, weight: .bold)
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1)
            
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(action: { onSelect(option) }) {
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
