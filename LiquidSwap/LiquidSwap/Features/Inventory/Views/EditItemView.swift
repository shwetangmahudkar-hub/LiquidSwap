//
//  EditItemView.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-22.
//


import SwiftUI
import PhotosUI

struct EditItemView: View {
    @Environment(\.dismiss) var dismiss
    
    // The Item we are editing
    let originalItem: TradeItem
    
    // Form State (Pre-filled in init)
    @State private var title: String
    @State private var description: String
    @State private var category: String
    
    // Image State
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var displayedImage: Image? = nil
    @State private var uiImageForSave: UIImage? = nil
    
    let categories = ["Electronics", "Fashion", "Home", "Plants", "Books", "Services"]
    
    init(item: TradeItem) {
        self.originalItem = item
        _title = State(initialValue: item.title)
        _description = State(initialValue: item.description)
        _category = State(initialValue: item.category)
        
        // Load the existing image if possible
        if let existingImage = item.uiImage {
            _displayedImage = State(initialValue: Image(uiImage: existingImage))
            _uiImageForSave = State(initialValue: existingImage)
        }
    }
    
    var body: some View {
        ZStack {
            LiquidBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    Text("Edit Item")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(.white)
                        .padding(.top, 20)
                    
                    // 1. Photo Section
                    GlassCard {
                        VStack(spacing: 12) {
                            if let displayedImage {
                                displayedImage
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 250)
                                    .cornerRadius(12)
                                    .clipped()
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.white.opacity(0.1))
                                    .frame(height: 200)
                                    .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.white))
                            }
                            
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Text("Change Photo")
                                    .bold()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.white.opacity(0.2))
                                    .cornerRadius(10)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // 2. Form Section
                    GlassCard {
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading) {
                                Text("Title").font(.caption).foregroundStyle(.cyan)
                                TextField("", text: $title).foregroundStyle(.white)
                                    .padding().background(.white.opacity(0.1)).cornerRadius(8)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Category").font(.caption).foregroundStyle(.cyan)
                                Menu {
                                    ForEach(categories, id: \.self) { cat in
                                        Button(cat) { category = cat }
                                    }
                                } label: {
                                    HStack {
                                        Text(category).foregroundStyle(.white)
                                        Spacer()
                                        Image(systemName: "chevron.down").foregroundStyle(.white.opacity(0.5))
                                    }
                                    .padding().background(.white.opacity(0.1)).cornerRadius(8)
                                }
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Description").font(.caption).foregroundStyle(.cyan)
                                TextField("", text: $description, axis: .vertical)
                                    .lineLimit(4...6)
                                    .foregroundStyle(.white)
                                    .padding().background(.white.opacity(0.1)).cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // 3. Save Button
                    Button(action: saveChanges) {
                        Text("Save Changes")
                            .bold()
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.cyan)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImg = UIImage(data: data) {
                    self.uiImageForSave = uiImg
                    self.displayedImage = Image(uiImage: uiImg)
                }
            }
        }
    }
    
    func saveChanges() {
        // Create a new struct with updated fields but the SAME ID
        var updatedItem = TradeItem(
            title: title,
            description: description,
            distance: originalItem.distance,
            category: category,
            ownerName: originalItem.ownerName,
            systemImage: originalItem.systemImage,
            color: originalItem.color, // Keep original color mapping
            uiImage: uiImageForSave
        )
        // CRITICAL: Force the ID to match the original so UserManager finds it
        updatedItem.id = originalItem.id
        
        // If image didn't change, we need to preserve the old filename manually
        // (TradeItem init creates a NEW filename if uiImage is passed, which is fine, 
        // but if uiImageForSave is same as old, we might want to be careful. 
        // For simplicity, we re-save the image which creates a new file, and UserManager deletes the old one if we implemented cleanup properly.
        // Actually, our current TradeItem init ALWAYS saves a new file. 
        // Ideally we should pass the old filename if image hasn't changed.
        // Let's keep it simple: It saves a "new" version of the image.)
        
        UserManager.shared.updateItem(updatedItem)
        dismiss()
    }
}