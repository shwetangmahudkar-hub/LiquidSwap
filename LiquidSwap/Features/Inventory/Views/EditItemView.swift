import SwiftUI

struct EditItemView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userManager = UserManager.shared
    
    // The item we are editing
    @State var item: TradeItem
    
    @State private var isSaving = false
    @State private var showDeleteAlert = false
    
    // Granular Category List
    let categories = [
        "Electronics", "Video Games", "Fashion", "Shoes",
        "Books", "Sports", "Home & Garden", "Collectibles", "Other"
    ]
    let conditions = ["New", "Like New", "Good", "Fair", "Poor"]
    
    var body: some View {
        ZStack {
            // 1. Global Background
            LiquidBackground()
            
            VStack(spacing: 0) {
                // 2. Custom Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Edit Item")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    // Balance spacer
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 10)
                
                // 3. Main Content
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Image Preview with Glow
                        AsyncImageView(filename: item.imageUrl)
                            .scaledToFill()
                            .frame(width: 160, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 32))
                            .overlay(
                                RoundedRectangle(cornerRadius: 32)
                                    .stroke(LinearGradient(colors: [.white.opacity(0.8), .white.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                            )
                            .shadow(color: .cyan.opacity(0.3), radius: 20, y: 10)
                            .padding(.top, 10)
                        
                        // Input Fields Group
                        VStack(spacing: 20) {
                            GlassTextField(title: "TITLE", text: $item.title)
                            
                            GlassTextField(title: "DESCRIPTION", text: $item.description, isMultiline: true)
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        
                        // Pickers Group
                        VStack(spacing: 0) {
                            CustomPickerRow(title: "Category", selection: $item.category, options: categories)
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            CustomPickerRow(title: "Condition", selection: $item.condition, options: conditions)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        
                        // Delete Button (Danger)
                        Button(action: { showDeleteAlert = true }) {
                            Text("Delete Item")
                                .font(.subheadline.bold())
                                .foregroundStyle(.red.opacity(0.8))
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .padding(.top, 10)
                        
                        Spacer(minLength: 100) // Space for bottom bar
                    }
                    .padding(20)
                }
            }
            
            // 4. Floating Bottom Action Bar (One-Handed Use)
            VStack {
                Spacer()
                
                Button(action: saveChanges) {
                    ZStack {
                        Capsule()
                            .fill(item.title.isEmpty ? Color.white.opacity(0.1) : Color.cyan)
                            .frame(height: 56)
                            .shadow(color: item.title.isEmpty ? .clear : .cyan.opacity(0.5), radius: 15, y: 5)
                        
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Save Changes")
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                        }
                    }
                }
                .disabled(item.title.isEmpty || isSaving)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .background(
                    LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 100)
                )
            }
            .ignoresSafeArea(.keyboard) // Moves up with keyboard
        }
        .navigationBarHidden(true)
        .alert("Delete Item?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { deleteItem() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    // MARK: - Logic (Unchanged)
    
    func saveChanges() {
        Task {
            withAnimation { isSaving = true }
            do {
                try await userManager.updateItem(item)
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                print("Error saving item: \(error)")
                await MainActor.run { isSaving = false }
            }
        }
    }
    
    func deleteItem() {
        Task {
            withAnimation { isSaving = true }
            do {
                try await userManager.deleteItem(item: item)
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                print("Error deleting item: \(error)")
                await MainActor.run { isSaving = false }
            }
        }
    }
}

// MARK: - Subviews

struct GlassTextField: View {
    let title: String
    @Binding var text: String
    var isMultiline: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.6))
                .padding(.leading, 4)
            
            if isMultiline {
                TextField("", text: $text, axis: .vertical)
                    .lineLimit(3...6)
                    .padding()
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(16)
                    .foregroundStyle(.white)
                    .tint(.cyan)
            } else {
                TextField("", text: $text)
                    .padding()
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(16)
                    .foregroundStyle(.white)
                    .tint(.cyan)
            }
        }
    }
}

struct CustomPickerRow: View {
    let title: String
    @Binding var selection: String
    let options: [String]
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            
            Spacer()
            
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) { selection = option }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selection)
                        .bold()
                        .foregroundStyle(.cyan)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.cyan.opacity(0.6))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.cyan.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding()
    }
}
