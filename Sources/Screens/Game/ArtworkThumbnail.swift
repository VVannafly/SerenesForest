import SwiftUI

struct ArtworkThumbnail: View {
    let asset: ContentAsset
    @Environment(\.modelContext) private var context
    @Environment(\.imageLoadingPaused) private var imageLoadingPaused
    @State private var image: CGImage?
    @State private var loadedKey: String?

    private var imageKey: String { "\(asset.url)|\(asset.fetchedAt?.timeIntervalSinceReferenceDate ?? 0)" }

    var body: some View {
        Group {
            if let image, loadedKey == imageKey {
                Image(decorative: image, scale: 1).resizable().scaledToFill()
            } else {
                Image(systemName: "photo").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .task(id: "\(imageKey)|\(imageLoadingPaused)") {
            guard !imageLoadingPaused, loadedKey != imageKey else { return }
            let loaded: CGImage?
            if let fetchedAt = asset.fetchedAt {
                loaded = await ImageLoadingService.shared.assetImage(
                    assetURL: asset.url, fetchedAt: fetchedAt, maxPixelSize: 240, container: context.container)
            } else {
                loaded = await ImageLoadingService.shared.missingAssetImage(
                    assetURL: asset.url, maxPixelSize: 240, container: context.container)
            }
            if !Task.isCancelled, let loaded {
                image = loaded
                loadedKey = imageKey
            }
        }
    }
}
