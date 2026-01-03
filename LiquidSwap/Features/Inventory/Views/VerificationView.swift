import SwiftUI
import PhotosUI

struct VerificationView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userManager = UserManager.shared
    
    // Form State
    @State private var fullName = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
    // Process State
    @State private var isSubmitting = false
    @State private var isSuccess = false
    
    var body: some View {
        ZStack(alignment: .top) {
            // 1. Global Background
            LiquidBackground().ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 2. Minimalist Title (No "X" Button)
                Text("Get Verified")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.top, 24) // Clean spacing from top edge
                    .padding(.bottom, 20)
                
                // 3. Main Content
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Hero Icon (Centered & Compact)
                        ZStack {
                            Circle()
                                .fill(Color.cyan.opacity(0.1))
                                .frame(width: 80, height: 80)
                                .overlay(Circle().stroke(Color.cyan.opacity(0.3), lineWidth: 1))
                            
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.cyan)
                                .shadow(color: .cyan.opacity(0.5), radius: 10)
                        }
                        
                        // Value Proposition
                        VStack(spacing: 8) {
                            Text("Build Trust & Credibility")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                            
                            Text("Verified users get 3x more trades and exclusive access to premium drops.")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                        }
                        
                        // Form Fields
                        VStack(spacing: 16) {
                            // Name Input
                            VStack(alignment: .leading, spacing: 6) {
                                Text("FULL LEGAL NAME")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .padding(.leading, 4)
                                
                                HStack {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(.cyan)
                                    TextField("John Doe", text: $fullName)
                                        .foregroundStyle(.white)
                                        .tint(.cyan)
                                }
                                .padding(14)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                            
                            // ID Upload
                            VStack(alignment: .leading, spacing: 6) {
                                Text("GOVERNMENT ID")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .padding(.leading, 4)
                                
                                PhotosPicker(selection: $selectedItem, matching: .images) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(0.05))
                                            .frame(height: 130)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                                                    .foregroundStyle(selectedImage == nil ? Color.white.opacity(0.3) : Color.cyan)
                                            )
                                        
                                        if let image = selectedImage {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(height: 130)
                                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .stroke(Color.cyan, lineWidth: 1)
                                                )
                                        } else {
                                            VStack(spacing: 8) {
                                                Image(systemName: "doc.viewfinder.fill")
                                                    .font(.system(size: 28))
                                                    .foregroundStyle(.white.opacity(0.8))
                                                Text("Tap to upload photo")
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.5))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 100) // Ensures scroll space so button doesn't block content
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            
            // 4. Floating Action Button (Pinned to Bottom)
            VStack {
                Spacer()
                Button(action: submitVerification) {
                    ZStack {
                        if isSubmitting {
                            ProgressView().tint(.black)
                        } else {
                            Text(isSuccess ? "Request Sent" : "Submit Request")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(isSuccess ? .white : .black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(isSuccess ? Color.green : (isValid ? Color.cyan : Color.white.opacity(0.1)))
                    .clipShape(Capsule())
                    .shadow(color: isValid ? .cyan.opacity(0.3) : .clear, radius: 10, y: 5)
                }
                .disabled(!isValid || isSubmitting || isSuccess)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .ignoresSafeArea(.keyboard)
        }
        // This enables the little grey "drag bar" at the top automatically
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run { selectedImage = image }
                }
            }
        }
    }
    
    // MARK: - Logic
    
    var isValid: Bool {
        !fullName.isEmpty && selectedImage != nil
    }
    
    func submitVerification() {
        Haptics.shared.playMedium()
        isSubmitting = true
        
        // Simulate API Processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSubmitting = false
            isSuccess = true
            Haptics.shared.playSuccess()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                dismiss()
            }
        }
    }
}
