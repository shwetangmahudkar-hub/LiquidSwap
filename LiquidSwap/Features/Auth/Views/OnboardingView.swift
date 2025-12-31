import SwiftUI

struct OnboardingView: View {
    @AppStorage("isOnboarding") var isOnboarding: Bool = true
    @ObservedObject var userManager = UserManager.shared
    
    // Navigation State
    @State private var currentPage = 0
    
    // Profile Inputs
    @State private var name = ""
    @State private var selectedImage: UIImage?
    @State private var isShowingImagePicker = false
    
    var body: some View {
        ZStack {
            // Global Background
            LiquidBackground()
            
            VStack(spacing: 0) {
                // --- CAROUSEL CONTENT ---
                TabView(selection: $currentPage) {
                    // Page 1: Intro
                    OnboardingPage(
                        image: "arrow.triangle.2.circlepath",
                        title: "Trade Locally",
                        description: "Swap electronics, fashion, and gear with people nearby. No shipping, no fees."
                    )
                    .tag(0)
                    
                    // Page 2: Safety
                    OnboardingPage(
                        image: "checkmark.shield.fill",
                        title: "Stay Safe",
                        description: "Meet at verified Safe Zones like police stations and coffee shops. We prioritize your safety."
                    )
                    .tag(1)
                    
                    // Page 3: Premium (Beta Unlocked)
                    PremiumOnboardingPage()
                    .tag(2)
                    
                    // Page 4: Profile Setup
                    ProfileSetupPage(
                        name: $name,
                        selectedImage: $selectedImage,
                        showPicker: $isShowingImagePicker
                    )
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentPage)
                
                // --- BOTTOM CONTROLS (iOS 26 UX) ---
                VStack(spacing: 20) {
                    // Page Indicators
                    HStack(spacing: 8) {
                        ForEach(0..<4) { index in
                            Capsule()
                                .fill(currentPage == index ? Color.cyan : Color.white.opacity(0.3))
                                .frame(width: currentPage == index ? 24 : 8, height: 8)
                                .animation(.spring(), value: currentPage)
                        }
                    }
                    
                    // Main Action Button
                    Button(action: handleNext) {
                        Text(currentPage == 3 ? "Start Swapping" : "Next")
                            .font(.headline.bold())
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.cyan)
                            .clipShape(Capsule()) // Modern pill shape
                            .shadow(color: .cyan.opacity(0.5), radius: 10, y: 5)
                    }
                }
                .padding(24)
                .background(.ultraThinMaterial) // slide-up glass effect
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(image: $selectedImage)
        }
    }
    
    // MARK: - Logic
    
    func handleNext() {
        if currentPage < 3 {
            withAnimation { currentPage += 1 }
            Haptics.shared.playLight()
        } else {
            // Finish Onboarding
            Haptics.shared.playSuccess()
            Task {
                await userManager.completeOnboarding(
                    username: name.isEmpty ? "Trader" : name,
                    bio: "Ready to trade!",
                    image: selectedImage
                )
                withAnimation { isOnboarding = false }
            }
        }
    }
}

// MARK: - Subviews

struct OnboardingPage: View {
    let image: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .blur(radius: 20)
                
                Image(systemName: image)
                    .font(.system(size: 80))
                    .foregroundStyle(.cyan.gradient)
                    .shadow(color: .cyan.opacity(0.5), radius: 20)
            }
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            Spacer() // Push content up slightly
        }
    }
}

struct PremiumOnboardingPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Premium Icon
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 140, height: 140)
                    .shadow(color: .orange.opacity(0.6), radius: 30)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 20)
            
            Text("LiquidSwap+")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            
            // Feature List
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "square.stack.3d.up.fill", title: "Multi-Item Trades", desc: "Build bundle deals.")
                FeatureRow(icon: "infinity", title: "Unlimited Inventory", desc: "List more than 20 items.")
                FeatureRow(icon: "checkmark.seal.fill", title: "Verified Badge", desc: "Build instant trust.")
            }
            .padding(.horizontal, 40)
            
            // Beta Note
            Text("🎉 UNLOCKED FOR BETA TESTING")
                .font(.caption).bold()
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green)
                .clipShape(Capsule())
                .padding(.top, 10)
            
            Spacer()
            Spacer()
        }
    }
    
    // Local helper for this view
    struct FeatureRow: View {
        let icon: String
        let title: String
        let desc: String
        
        var body: some View {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.yellow)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}

struct ProfileSetupPage: View {
    @Binding var name: String
    @Binding var selectedImage: UIImage?
    @Binding var showPicker: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 10) {
                Text("Your Profile")
                    .font(.largeTitle).bold()
                    .foregroundStyle(.white)
                Text("How others will see you.")
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            // Image Picker
            Button(action: { showPicker = true }) {
                ZStack {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 140, height: 140)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    } else {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 140, height: 140)
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
                            
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.title)
                                Text("Add Photo")
                                    .font(.caption)
                            }
                            .foregroundStyle(.white)
                        }
                    }
                    
                    // Edit Badge
                    if selectedImage != nil {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title)
                            .foregroundStyle(.cyan)
                            .background(Circle().fill(.white))
                            .offset(x: 50, y: 50)
                    }
                }
            }
            .shadow(color: .black.opacity(0.2), radius: 10)
            
            // Name Field
            TextField("Choose a username", text: $name)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .foregroundStyle(.white)
                .padding(.horizontal, 40)
                .textInputAutocapitalization(.words)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        .padding(.horizontal, 40)
                )
            
            Spacer()
            Spacer()
        }
    }
}

// Simple Image Picker Helper (Retained)
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            parent.dismiss()
        }
    }
}
