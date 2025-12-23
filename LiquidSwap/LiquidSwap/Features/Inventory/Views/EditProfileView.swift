import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userManager = UserManager.shared
    
    // Form State
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var location: String = ""
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
    var body: some View {
        NavigationStack {
            Form {
                // FIXED: Handle optional currentUser and use 'avatarUrl'
                ProfileImageSection(
                    selectedItem: $selectedItem,
                    selectedImage: $selectedImage,
                    currentAvatar: userManager.currentUser?.avatarUrl
                )
                
                ProfileDetailsSection(username: $username, bio: $bio, location: $location)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // FIXED: Safely unwrap optional user data with default values
                if let user = userManager.currentUser {
                    username = user.username
                    bio = user.bio
                    location = user.location
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
            // FIXED: iOS 17 syntax for onChange (attached correctly to NavigationStack)
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
    
    func saveProfile() {
        // 1. Update Text Data
        userManager.updateProfile(username: username, bio: bio, location: location)
        
        // 2. Update Image if changed
        if let newImage = selectedImage {
            userManager.updateAvatar(image: newImage)
        }
        
        dismiss()
    }
}

// MARK: - SUBVIEWS

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
                            // New selected image
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } else if let urlString = currentAvatar {
                            // FIXED: Use AsyncImageView for the cloud URL
                            AsyncImageView(filename: urlString)
                                .clipShape(Circle())
                                .frame(width: 120, height: 120)
                                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        } else {
                            // Placeholder
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundStyle(.gray)
                                .frame(width: 120, height: 120)
                        }
                        
                        // Edit Overlay
                        VStack {
                            Spacer()
                            Text("Edit")
                                .font(.caption)
                                .bold()
                                .foregroundStyle(.white)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity)
                                .background(Color.black.opacity(0.6))
                        }
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
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
            TextField("Username", text: $username)
                .textInputAutocapitalization(.never)
            
            TextField("Location", text: $location)
            
            TextField("Bio", text: $bio, axis: .vertical)
                .lineLimit(3...6)
        }
    }
}

#Preview {
    EditProfileView()
}
