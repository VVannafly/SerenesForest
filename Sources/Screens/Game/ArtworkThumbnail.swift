import SwiftUI

struct ArtworkThumbnail: View {
    let asset: ContentAsset
    @Environment(\.modelContext) private var context
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1).resizable().scaledToFill()
            } else {
                Image(systemName: "photo").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .task(id: asset.fetchedAt) {
            guard let fetchedAt = asset.fetchedAt else { return }
            image = await LocalImageLoader.shared.assetImage(
                assetURL: asset.url, fetchedAt: fetchedAt, maxPixelSize: 240, container: context.container)
        }
    }
}
