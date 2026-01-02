import SwiftUI

// Extract cache to non-generic class to avoid "Static stored properties not supported in generic types"
fileprivate class ImageCache {
    static let shared = NSCache<NSURL, UIImage>()
}

struct CachedAsyncImage: View {
    let url: URL
    let scale: CGFloat
    let transaction: Transaction
    
    @State private var phase: AsyncImagePhase = .empty
    
    init(url: URL, scale: CGFloat = 1.0, transaction: Transaction = Transaction()) {
        self.url = url
        self.scale = scale
        self.transaction = transaction
    }
    
    var body: some View {
        Group {
            if let image = phase.image {
                image
                    .resizable()
            } else if phase.error != nil {
                Color.gray.opacity(0.3) // Error placeholder
            } else {
                ProgressView() // Loading placeholder
            }
        }
        .onAppear(perform: load)
    }
    
    private func load() {
        // 1. Check Memory Cache
        if let cached = ImageCache.shared.object(forKey: url as NSURL) {
            self.phase = .success(Image(uiImage: cached))
            return
        }
        
        // 2. Fetch
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                if let data = data, let uiImage = UIImage(data: data) {
                    ImageCache.shared.setObject(uiImage, forKey: url as NSURL)
                    withAnimation(transaction.animation) {
                        self.phase = .success(Image(uiImage: uiImage))
                    }
                } else {
                    self.phase = .failure(error ?? URLError(.unknown))
                }
            }
        }.resume()
    }
}
