import SwiftUI

struct AsyncImageView: View {
    let filename: String? // This is the full URL string (e.g. "https://supabase.../avatar.jpg")
    
    @State private var image: Image?
    @State private var isLoading = true
    @State private var hasError = false
    
    var body: some View {
        ZStack {
            if let image = image {
                image
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.animation(.easeOut(duration: 0.2))) // Smooth Fade In
            } else if hasError {
                ZStack {
                    Color.gray.opacity(0.2)
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.gray)
                }
            } else {
                ZStack {
                    Color.gray.opacity(0.1) // Placeholder background
                    ProgressView()
                        .tint(.gray)
                }
            }
        }
        // ✨ MAGIC: Trigger the aggressive caching logic when view appears
        .task(id: filename) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        // 1. Validation
        guard let urlString = filename, let url = URL(string: urlString) else {
            isLoading = false
            return // Keep empty/placeholder if no valid URL
        }
        
        // 2. Identify the unique local filename
        // We use the last part of the URL as the unique key (e.g., "user_123_avatar.jpg")
        let localFilename = url.lastPathComponent
        
        // 3. CHECK DISK (Aggressive Cache)
        if let localImage = DiskManager.loadImage(named: localFilename) {
            // Found on disk! Load immediately.
            await MainActor.run {
                self.image = Image(uiImage: localImage)
                self.isLoading = false
            }
            // print("📱 Loaded from Disk: \(localFilename)") // Debug log
            return
        }
        
        // 4. NETWORK DOWNLOAD (Only if not on disk)
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let uiImage = UIImage(data: data) {
                // 5. SAVE TO DISK (For next time)
                _ = DiskManager.saveImage(image: uiImage, name: localFilename)
                
                await MainActor.run {
                    self.image = Image(uiImage: uiImage)
                    self.isLoading = false
                }
                // print("☁️ Downloaded & Saved: \(localFilename)") // Debug log
            } else {
                await MainActor.run { hasError = true; isLoading = false }
            }
        } catch {
            print("❌ Image Download Error: \(error.localizedDescription)")
            await MainActor.run { hasError = true; isLoading = false }
        }
    }
}
