import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userManager = UserManager.shared
    
    // Profile State
    @State private var name: String = ""
    @State private var bio: String = ""
    @State private var location: String = ""
    
    // Image State
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var displayedImage: Image? = nil
    @State private var uiImageForSave: UIImage? = nil
    
    var body: some View {
        ZStack {
            LiquidBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    Text("Edit Profile")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(.white)
                        .padding(.top, 20)
                    
                    // 1. Identity Section (Avatar & Name)
                    GlassCard {
                        VStack(spacing: 16) {
                            // Avatar
                            ZStack {
                                if let displayedImage {
                                    displayedImage
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(.cyan, lineWidth: 2))
                                } else {
                                    Circle()
                                        .fill(.white.opacity(0.1))
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.largeTitle)
                                                .foregroundStyle(.white.opacity(0.5))
                                        )
                                }
                                
                                // Camera Icon Overlay
                                PhotosPicker(selection: $selectedItem, matching: .images) {
                                    Circle()
                                        .fill(.cyan)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.caption)
                                                .foregroundStyle(.black)
                                        )
                                }
                                .offset(x: 35, y: 35)
                            }
                            
                            // Name Field
                            VStack(alignment: .leading) {
                                Text("Display Name")
                                    .font(.caption)
                                    .foregroundStyle(.cyan)
                                TextField("Your Name", text: $name)
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(.white.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            
                            // Bio Field
                            VStack(alignment: .leading) {
                                Text("Bio")
                                    .font(.caption)
                                    .foregroundStyle(.cyan)
                                TextField("Tell us about yourself...", text: $bio)
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(.white.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            
                            // Location Field
                            VStack(alignment: .leading) {
                                Text("Location / Neighborhood")
                                    .font(.caption)
                                    .foregroundStyle(.cyan)
                                TextField("e.g. Downtown", text: $location)
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(.white.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // 2. ISO Preferences Section
                    GlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("In Search Of (ISO)")
                                .font(.headline)
                                .foregroundStyle(.cyan)
                            
                            Text("Select categories to prioritize in your feed.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                            
                            FlowLayout(spacing: 10) {
                                ForEach(userManager.allCategories, id: \.self) { category in
                                    Button(action: {
                                        userManager.toggleISO(category)
                                    }) {
                                        Text(category)
                                            .font(.subheadline)
                                            .bold()
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                userManager.isoCategories.contains(category)
                                                ? Color.cyan
                                                : Color.white.opacity(0.1)
                                            )
                                            .foregroundStyle(
                                                userManager.isoCategories.contains(category)
                                                ? Color.black
                                                : Color.white
                                            )
                                            .cornerRadius(20)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // 3. Save Button
                    Button(action: saveProfile) {
                        Text("Save Profile")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.cyan)
                            .cornerRadius(12)
                            .foregroundStyle(.black)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            // Load existing data
            name = userManager.userName
            bio = userManager.userBio
            location = userManager.userLocation
            if let img = userManager.userProfileImage {
                displayedImage = Image(uiImage: img)
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
        .navigationBarBackButtonHidden(true)
    }
    
    func saveProfile() {
        userManager.updateProfile(
            name: name,
            bio: bio,
            location: location,
            image: uiImageForSave
        )
        dismiss()
    }
}

// Helper: FlowLayout (Same as before)
struct FlowLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.last?.maxY ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        for row in rows {
            for element in row.elements {
                element.subview.place(at: CGPoint(x: bounds.minX + element.frame.minX, y: bounds.minY + element.frame.minY), proposal: proposal)
            }
        }
    }
    
    struct Row {
        var elements: [Element] = []
        var maxY: CGFloat = 0
    }
    
    struct Element {
        var subview: LayoutSubview
        var frame: CGRect
    }
    
    func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row()
        var x: CGFloat = 0
        var y: CGFloat = 0
        let maxWidth = proposal.width ?? 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && !currentRow.elements.isEmpty {
                y = currentRow.maxY + spacing
                rows.append(currentRow)
                currentRow = Row()
                x = 0
            }
            let frame = CGRect(origin: CGPoint(x: x, y: y), size: size)
            currentRow.elements.append(Element(subview: subview, frame: frame))
            currentRow.maxY = max(currentRow.maxY, frame.maxY)
            x += size.width + spacing
        }
        if !currentRow.elements.isEmpty {
            rows.append(currentRow)
        }
        return rows
    }
}

#Preview {
    EditProfileView()
}
