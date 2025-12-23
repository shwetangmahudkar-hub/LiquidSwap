import SwiftUI

struct AsyncImageView: View {
    let filename: String? // Changed to Optional URL String
    
    var body: some View {
        if let filename = filename, let url = URL(string: filename) {
            // Use SwiftUI's built-in AsyncImage for Cloud URLs
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Color.gray.opacity(0.2)
                        ProgressView()
                    }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    ZStack {
                        Color.gray.opacity(0.2)
                        Image(systemName: "exclamationmark.triangle")
                    }
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            // Placeholder for missing URL
            ZStack {
                Color.gray.opacity(0.2)
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }
}
