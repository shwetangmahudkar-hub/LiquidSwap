import SwiftUI

struct AsyncImageView: View {
    let item: TradeItem
    
    @State private var image: UIImage? = nil
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.white.opacity(0.1)
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: item.systemImage)
                            .resizable()
                            .scaledToFit()
                            .padding(20)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
        }
        .task {
            if image == nil {
                await loadImage()
            }
        }
    }
    
    private func loadImage() async {
        if let filename = item.imageFilename {
            let loadedImage = DiskManager.shared.loadImage(filename: filename)
            await MainActor.run {
                withAnimation {
                    self.image = loadedImage
                    self.isLoading = false
                }
            }
        } else {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
