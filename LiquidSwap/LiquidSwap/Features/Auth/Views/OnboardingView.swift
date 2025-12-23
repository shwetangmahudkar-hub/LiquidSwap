import SwiftUI

struct OnboardingView: View {
    @AppStorage("isOnboarding") var isOnboarding: Bool = true
    @ObservedObject var userManager = UserManager.shared
    
    @State private var name = ""
    @State private var selectedImage: UIImage?
    @State private var isShowingImagePicker = false
    
    var body: some View {
        ZStack {
            // Background
            LiquidBackground()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Title
                VStack(spacing: 10) {
                    Text("Welcome to Liquid Swap")
                        .font(.largeTitle)
                        .bold()
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                    
                    Text("Let's set up your profile.")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                // Profile Image Picker
                Button(action: {
                    isShowingImagePicker = true
                }) {
                    ZStack {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 4))
                        } else {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.title)
                                        .foregroundStyle(.white)
                                )
                                .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 2))
                        }
                    }
                }
                .shadow(radius: 10)
                
                // Name Input
                TextField("Enter your username", text: $name)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 40)
                    .textInputAutocapitalization(.words)
                
                Spacer()
                
                // Finish Button
                Button(action: {
                    // FIXED: Updated call to match new UserManager signature
                    userManager.completeOnboarding(
                        username: name.isEmpty ? "Trader" : name,
                        bio: "Ready to trade!", // Default bio since this view doesn't ask for one
                        image: selectedImage
                    )
                    isOnboarding = false
                }) {
                    Text("Start Swapping")
                        .font(.headline)
                        .bold()
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.cyan)
                        .cornerRadius(15)
                        .shadow(color: .cyan.opacity(0.5), radius: 10)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(image: $selectedImage)
        }
    }
}

// Simple Image Picker Helper
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

#Preview {
    OnboardingView()
}
