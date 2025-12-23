//
//  AddItemView.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-22.
//


import SwiftUI
import PhotosUI

struct AddItemView: View {
    @Environment(\.dismiss) var dismiss
    
    // Form State
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var category: String = "Electronics"
    
    // Image Picker State
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: Image? = nil
    @State private var uiImageForAnalysis: UIImage? = nil // To pass to AI
    
    // AI State
    @State private var isAnalyzing = false
    @State private var detectedLabels: [String] = []
    @State private var showSafetyAlert = false // To block bad content
    
    let categories = ["Electronics", "Fashion", "Home", "Plants", "Books", "Services"]
    
    var body: some View {
        ZStack {
            LiquidBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    Text("List an Item")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(.white)
                        .padding(.top, 20)
                    
                    // 1. Photo Uploader Section
                    GlassCard {
                        VStack(spacing: 12) {
                            if let selectedImage {
                                ZStack {
                                    selectedImage
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 250)
                                        .cornerRadius(12)
                                        .clipped()
                                    
                                    // AI Loading Indicator
                                    if isAnalyzing {
                                        ZStack {
                                            Color.black.opacity(0.6)
                                            VStack {
                                                ProgressView()
                                                    .tint(.white)
                                                Text("Analyzing...")
                                                    .font(.caption)
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                    }
                                }
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.white.opacity(0.1))
                                    .frame(height: 200)
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 40))
                                                .foregroundStyle(.cyan)
                                            Text("Tap to upload photo")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.7))
                                        }
                                    )
                            }
                            
                            PhotosPicker(
                                selection: $selectedItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Text(selectedImage == nil ? "Select Photo" : "Change Photo")
                                    .bold()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.white.opacity(0.2))
                                    .cornerRadius(10)
                                    .foregroundStyle(.white)
                            }
                            
                            // Debug: Show detected tags (Optional)
                            if !detectedLabels.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(detectedLabels, id: \.self) { label in
                                            Text("#\(label)")
                                                .font(.caption2)
                                                .padding(6)
                                                .background(.white.opacity(0.1))
                                                .cornerRadius(8)
                                                .foregroundStyle(.cyan)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // 2. Details Form
                    GlassCard {
                        VStack(alignment: .leading, spacing: 20) {
                            // Title
                            VStack(alignment: .leading) {
                                Text("Title")
                                    .font(.caption)
                                    .foregroundStyle(.cyan)
                                TextField("", text: $title, prompt: Text("e.g. Vintage Lamp").foregroundStyle(.white.opacity(0.3)))
                                    .foregroundStyle(.white)
                                    .padding()
                                    .background(.white.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            
                            // Category (Auto-Selected by AI)
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Category")
                                        .font(.caption)
                                        .foregroundStyle(.cyan)
                                    Spacer()
                                    if !detectedLabels.isEmpty {
                                        Label("AI Suggested", systemImage: "sparkles")
                                            .font(.caption2)
                                            .foregroundStyle(.yellow)
                                    }
                                }
                                
                                Menu {
                                    ForEach(categories, id: \.self) { cat in
                                        Button(cat) { category = cat }
                                    }
                                } label: {
                                    HStack {
                                        Text(category)
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                    .padding()
                                    .background(.white.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                            
                            // Description
                            VStack(alignment: .leading) {
                                Text("Description")
                                    .font(.caption)
                                    .foregroundStyle(.cyan)
                                TextField("", text: $description, prompt: Text("Describe condition, size, etc.").foregroundStyle(.white.opacity(0.3)), axis: .vertical)
                                    .lineLimit(4...6)
                                    .foregroundStyle(.white)
                                    .padding()
                                    .background(.white.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // 3. Post Button
                    Button(action: {
                        // 1. Create the new item
                        let newItem = TradeItem(
                            title: title.isEmpty ? "Untitled Item" : title,
                            description: description,
                            distance: "0km", // It's yours, so distance is 0
                            category: category,
                            ownerName: UserManager.shared.userName,
                            systemImage: "cube.box.fill", // Fallback
                            color: .cyan, // Default brand color
                            uiImage: uiImageForAnalysis // ATTACH THE REAL PHOTO
                        )
                        
                        // 2. Save to User Manager
                        UserManager.shared.addItem(newItem)
                        
                        // 3. Close
                        dismiss()
                    }) {
                        Text("Post Item")
                            .bold()
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.cyan)
                            .cornerRadius(12)
                            .shadow(color: .cyan.opacity(0.5), radius: 10)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
        // AI LOGIC TRIGGER
        .onChange(of: selectedItem) { newItem in
            Task {
                // 1. Load Image Data
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    
                    selectedImage = Image(uiImage: uiImage)
                    uiImageForAnalysis = uiImage
                    
                    // 2. Start AI Analysis
                    isAnalyzing = true
                    
                    // Run logic in background
                    do {
                        let labels = try await ImageAnalyzer.analyze(image: uiImage)
                        
                        // 3. Safety Check
                        let isSafe = ImageAnalyzer.validateSafety(labels: labels)
                        
                        DispatchQueue.main.async {
                            isAnalyzing = false
                            if isSafe {
                                self.detectedLabels = labels
                                // 4. Auto-Fill Category
                                if let suggestion = ImageAnalyzer.suggestCategory(from: labels) {
                                    withAnimation {
                                        self.category = suggestion
                                    }
                                }
                            } else {
                                // Block the content
                                self.showSafetyAlert = true
                                self.selectedImage = nil // Remove the bad image
                                self.selectedItem = nil
                            }
                        }
                    } catch {
                        print("AI Analysis failed: \(error)")
                        isAnalyzing = false
                    }
                }
            }
        }
        // SAFETY ALERT POPUP
        .alert("Prohibited Content", isPresented: $showSafetyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Our AI detected prohibited content (Weapon, Drug, etc.) in this image. Please upload a safe image.")
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }
}

#Preview {
    AddItemView()
}
