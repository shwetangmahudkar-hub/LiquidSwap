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
        ZStack {
            // Background
            LiquidBackground()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Text("Get Verified")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Color.clear.frame(width: 30) // Balance
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 30) {
                        
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color.cyan.opacity(0.2))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.cyan)
                                .shadow(color: .cyan.opacity(0.5), radius: 10)
                        }
                        .padding(.top, 20)
                        
                        // Explanation
                        VStack(spacing: 12) {
                            Text("Build Trust instantly.")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            
                            Text("Verified traders get 3x more offers and premium visibility. Upload a valid ID to get your badge.")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 20)
                        }
                        
                        // Form
                        VStack(alignment: .leading, spacing: 20) {
                            // Name Input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("FULL LEGAL NAME")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white.opacity(0.5))
                                
                                TextField("John Doe", text: $fullName)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                    .foregroundStyle(.white)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }
                            
                            // ID Upload
                            VStack(alignment: .leading, spacing: 8) {
                                Text("GOVERNMENT ID")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white.opacity(0.5))
                                
                                PhotosPicker(selection: $selectedItem, matching: .images) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(0.05))
                                            .frame(height: 180)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [10]))
                                                    .foregroundStyle(selectedImage == nil ? Color.white.opacity(0.3) : Color.cyan)
                                            )
                                        
                                        if let image = selectedImage {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(height: 180)
                                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                                .opacity(0.8)
                                            
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.largeTitle)
                                                .foregroundStyle(.white)
                                                .shadow(radius: 5)
                                        } else {
                                            VStack(spacing: 12) {
                                                Image(systemName: "doc.text.viewfinder")
                                                    .font(.system(size: 40))
                                                Text("Tap to upload photo")
                                                    .font(.headline)
                                            }
                                            .foregroundStyle(.white.opacity(0.5))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer(minLength: 40)
                    }
                }
                
                // Bottom Button (iOS 26 Style)
                VStack {
                    if isSuccess {
                        Button(action: { dismiss() }) {
                            Text("Verification Pending")
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.green)
                                .clipShape(Capsule())
                        }
                        .disabled(true)
                    } else {
                        Button(action: submitVerification) {
                            HStack {
                                if isSubmitting {
                                    ProgressView().tint(.black)
                                } else {
                                    Text("Submit for Review")
                                        .font(.headline.bold())
                                        .foregroundStyle(.black)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(canSubmit ? Color.cyan : Color.white.opacity(0.2))
                            .clipShape(Capsule())
                            .shadow(color: canSubmit ? .cyan.opacity(0.5) : .clear, radius: 10, y: 5)
                        }
                        .disabled(!canSubmit || isSubmitting)
                    }
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
            }
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        withAnimation { selectedImage = image }
                    }
                }
            }
        }
    }
    
    // MARK: - Logic
    
    var canSubmit: Bool {
        return !fullName.isEmpty && selectedImage != nil
    }
    
    func submitVerification() {
        isSubmitting = true
        
        Task {
            // Mock Network Delay
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            await userManager.markAsVerified()
            
            await MainActor.run {
                isSubmitting = false
                isSuccess = true
                Haptics.shared.playSuccess()
                
                // Auto dismiss after brief success state
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
    }
}

// Helper shape for iOS 26 bottom sheets
struct UnevenRoundedRectangle: Shape {
    var topLeadingRadius: CGFloat = 0
    var bottomLeadingRadius: CGFloat = 0
    var bottomTrailingRadius: CGFloat = 0
    var topTrailingRadius: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let tl = topLeadingRadius
        let tr = topTrailingRadius
        let bl = bottomLeadingRadius
        let br = bottomTrailingRadius

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)

        return path
    }
}
