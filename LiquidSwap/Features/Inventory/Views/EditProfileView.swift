import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userManager = UserManager.shared
    
    // Form State
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var location: String = ""
    @State private var isoCategories: [String] = [] // New State
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
    let allCategories = ["Electronics", "Fashion", "Home & Garden", "Sports", "Books", "Other"]
    
    var body: some View {
        NavigationStack {
            Form {
                ProfileImageSection(
                    selectedItem: $selectedItem,
                    selectedImage: $selectedImage,
                    currentAvatar: userManager.currentUser?.avatarUrl
                )
                
                ProfileDetailsSection(username: $username, bio: $bio, location: $location)
                
                // NEW: ISO Selection Section
                Section(header: Text("In Search Of (ISO)")) {
                    Text("Select the categories you are interested in trading for.")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(allCategories, id: \.self) { cat in
                                TogglePill(title: cat, isSelected: isoCategories.contains(cat)) {
                                    toggleCategory(cat)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let user = userManager.currentUser {
                    username = user.username
                    bio = user.bio
                    location = user.location
                    isoCategories = user.isoCategories
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                    }
                }
            }
        }
    }
    
    func toggleCategory(_ cat: String) {
        if isoCategories.contains(cat) {
            isoCategories.removeAll { $0 == cat }
        } else {
            isoCategories.append(cat)
        }
    }
    
    func saveProfile() {
        Task {
            await userManager.updateProfile(
                username: username,
                bio: bio,
                location: location,
                isoCategories: isoCategories
            )
            
            if let newImage = selectedImage {
                await userManager.updateAvatar(image: newImage)
            }
            
            dismiss()
        }
    }
    
    // Helper Pill for Selection
    struct TogglePill: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.caption).bold()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isSelected ? Color.cyan : Color.gray.opacity(0.2))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .cornerRadius(20)
            }
            .buttonStyle(.plain)
        }
    }
    
    struct ProfileImageSection: View {
        @Binding var selectedItem: PhotosPickerItem?
        @Binding var selectedImage: UIImage?
        let currentAvatar: String?
        
        var body: some View {
            Section {
                HStack {
                    Spacer()
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        ZStack {
                            if let image = selectedImage {
                                Image(uiImage: image).resizable().scaledToFill().frame(width: 120, height: 120).clipShape(Circle())
                            } else if let urlString = currentAvatar {
                                AsyncImageView(filename: urlString).clipShape(Circle()).frame(width: 120, height: 120)
                            } else {
                                Image(systemName: "person.circle.fill").resizable().foregroundStyle(.gray).frame(width: 120, height: 120)
                            }
                            VStack {
                                Spacer()
                                Text("Edit").font(.caption).bold().foregroundStyle(.white).padding(.vertical, 4).frame(maxWidth: .infinity).background(Color.black.opacity(0.6))
                            }
                        }
                        .frame(width: 120, height: 120).clipShape(Circle())
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
    }
    
    struct ProfileDetailsSection: View {
        @Binding var username: String
        @Binding var bio: String
        @Binding var location: String
        
        var body: some View {
            Section("Public Info") {
                TextField("Username", text: $username).textInputAutocapitalization(.never)
                TextField("Location", text: $location)
                TextField("Bio", text: $bio, axis: .vertical).lineLimit(3...6)
            }
        }
    }
}
