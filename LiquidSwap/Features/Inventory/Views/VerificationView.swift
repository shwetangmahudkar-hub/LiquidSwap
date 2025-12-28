import SwiftUI

struct VerificationView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userManager = UserManager.shared
    
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var isAnalyzing = false
    @State private var isSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Use our shared background
                LiquidBackground()
                
                VStack(spacing: 30) {
                    // --- HEADER ---
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 70))
                            .foregroundStyle(.cyan)
                            .shadow(radius: 10)
                        
                        Text("Get Verified")
                            .font(.largeTitle).bold()
                            .foregroundStyle(.white)
                        
                        Text("To verify you are a real person, please take a selfie holding up **three fingers**.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)
                    
                    // --- PHOTO AREA ---
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 250, height: 300)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.2), lineWidth: 1))
                        
                        if let image = capturedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 250, height: 300)
                                .cornerRadius(20)
                                .clipped()
                        } else {
                            VStack {
                                Image(systemName: "camera.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("Tap 'Take Photo'")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        
                        if isAnalyzing {
                            ZStack {
                                Color.black.opacity(0.6).cornerRadius(20)
                                VStack {
                                    ProgressView().tint(.white)
                                    Text("Verifying...")
                                        .font(.caption).bold()
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(width: 250, height: 300)
                        }
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption).bold()
                    }
                    
                    Spacer()
                    
                    // --- ACTIONS ---
                    if !isSuccess {
                        // 1. Take Photo Button
                        Button(action: { showCamera = true }) {
                            Text(capturedImage == nil ? "Take Photo" : "Retake Photo")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // 2. Submit Button (Only appears after photo taken)
                        if capturedImage != nil {
                            Button(action: verifyPhoto) {
                                Text("Submit for Verification")
                                    .bold()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.cyan)
                                    .foregroundStyle(.black)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .disabled(isAnalyzing)
                        }
                    } else {
                        // 3. Success State
                        Button(action: { dismiss() }) {
                            Text("You are Verified! (Done)")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(selectedImage: $capturedImage)
                    .ignoresSafeArea()
            }
        }
    }
    
    // MARK: - Logic
    
    func verifyPhoto() {
        isAnalyzing = true
        errorMessage = nil
        
        // Simulate Network/AI Analysis Delay (2 seconds)
        // In a production app, this would upload the image to an endpoint for analysis.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            Task {
                await userManager.markAsVerified()
                
                await MainActor.run {
                    self.isAnalyzing = false
                    self.isSuccess = true
                    Haptics.shared.playSuccess()
                }
            }
        }
    }
}
