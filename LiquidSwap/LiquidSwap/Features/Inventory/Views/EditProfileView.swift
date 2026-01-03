import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userManager = UserManager.shared
    
    // Form State
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var location: String = ""
    @State private var isoCategories: [String] = []
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showVerification = false
    @State private var isSaving = false
    
    // Categories
    let allCategories = [
        "Electronics", "Video Games", "Fashion", "Shoes",
        "Books", "Sports", "Home & Garden", "Collectibles", "Other"
    ]
    
    var body: some View {
        // 🛠️ FIX: Capture MainActor-isolated property here to use safely in closures
        let currentAvatarUrl = userManager.currentUser?.avatarUrl
        
        ZStack {
            // 1. Global Background
            LiquidBackground()
            
            VStack(spacing: 0) {
                // 2. Custom Header
                HStack {
                    Button("Cancel") { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    Text("Edit Profile")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 80, height: 44)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                
                // 3. Main Content
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Avatar Editor
                        VStack(spacing: 12) {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                ZStack {
                                    if let image = selectedImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 130, height: 130)
                                            .clipShape(Circle())
                                    } else if let urlString = currentAvatarUrl { // 🛠️ FIX: Use captured variable
                                        AsyncImageView(filename: urlString)
                                            .scaledToFill()
                                            .frame(width: 130, height: 130)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .foregroundStyle(.gray)
                                            .frame(width: 130, height: 130)
                                    }
                                    
                                    VStack {
                                        Spacer()
                                        Text("EDIT")
                                            .font(.system(size: 10, weight: .black))
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 6)
                                            .background(Color.black.opacity(0.6))
                                    }
                                }
                                .frame(width: 130, height: 130)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(LinearGradient(colors: [.cyan.opacity(0.8), .purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
                                )
                                .shadow(color: .cyan.opacity(0.4), radius: 20)
                            }
                            
                            Text("Tap to change avatar")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(.top, 10)
                        
                        // Details Form
                        VStack(spacing: 20) {
                            GlassTextField(title: "USERNAME", text: $username)
                            GlassTextField(title: "LOCATION", text: $location)
                            GlassTextField(title: "BIO", text: $bio, isMultiline: true)
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        
                        // Verification Section
                        Button(action: { showVerification = true }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("TRUST & SAFETY")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white.opacity(0.5))
                                    
                                    HStack {
                                        Image(systemName: userManager.currentUser?.isVerified == true ? "checkmark.seal.fill" : "shield")
                                            .foregroundStyle(.cyan)
                                            .font(.title3)
                                        
                                        Text(userManager.currentUser?.isVerified == true ? "Verified Trader" : "Get Verified")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        
                        // ✨ NEW: Feature Preview (Dev Toggle)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.yellow)
                                Text("FEATURE PREVIEW")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Early Access Mode")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    
                                    Text(userManager.isPremium ? "Status: Unlocked" : "Status: Standard")
                                        .font(.caption)
                                        .foregroundStyle(userManager.isPremium ? .yellow : .white.opacity(0.5))
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: { userManager.isPremium },
                                    set: { _ in userManager.debugTogglePremium() }
                                ))
                                .labelsHidden()
                                .tint(.yellow)
                            }
                            
                            Text("Toggle this to test Early Access features like AI Auto-Fill and Unlimited Listings.")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.4))
                                .padding(.top, 4)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                        
                        // ISO Categories
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.cyan)
                                Text("IN SEARCH OF (ISO)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .padding(.horizontal, 4)
                            
                            Text("Select categories you want to trade for.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.horizontal, 4)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(allCategories, id: \.self) { cat in
                                        Button(action: { toggleCategory(cat) }) {
                                            Text(cat)
                                                .font(.system(size: 13, weight: .semibold))
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .background(
                                                    isoCategories.contains(cat) ?
                                                    Color.cyan : Color.white.opacity(0.05)
                                                )
                                                .foregroundStyle(.white)
                                                .clipShape(Capsule())
                                                .overlay(
                                                    Capsule()
                                                        .stroke(isoCategories.contains(cat) ? Color.cyan : Color.white.opacity(0.2), lineWidth: 1)
                                                )
                                                .shadow(color: isoCategories.contains(cat) ? .cyan.opacity(0.3) : .clear, radius: 8)
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 10)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        
                        Spacer(minLength: 120) // Space for bottom bar
                    }
                    .padding(20)
                }
            }
            
            // 4. Floating Bottom Action Bar
            VStack {
                Spacer()
                Button(action: saveProfile) {
                    ZStack {
                        Capsule()
                            .fill(username.isEmpty ? Color.white.opacity(0.1) : Color.cyan)
                            .frame(height: 56)
                            .shadow(color: username.isEmpty ? .clear : .cyan.opacity(0.5), radius: 15, y: 5)
                        
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Save Profile")
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                        }
                    }
                }
                .disabled(username.isEmpty || isSaving)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .background(
                    LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 100)
                )
            }
            .ignoresSafeArea(.keyboard)
        }
        .onAppear {
            if let user = userManager.currentUser {
                username = user.username
                bio = user.bio
                location = user.location
                isoCategories = user.isoCategories
            }
        }
        .sheet(isPresented: $showVerification) {
            VerificationView()
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        selectedImage = uiImage
                    }
                }
            }
        }
    }
    
    // MARK: - Logic
    
    func toggleCategory(_ cat: String) {
        if isoCategories.contains(cat) {
            isoCategories.removeAll { $0 == cat }
        } else {
            isoCategories.append(cat)
        }
        Haptics.shared.playLight()
    }
    
    func saveProfile() {
        isSaving = true
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
            
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                isSaving = false
                Haptics.shared.playSuccess()
                dismiss()
            }
        }
    }
}
