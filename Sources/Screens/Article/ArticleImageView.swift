import Foundation
import SwiftUI

private enum Constants {
    static var articleImage: String { AppText.localized( "Article image") }
    static var openImage: String { AppText.localized( "Open image") }
}

struct ArticleImageView: View {
    let url: URL
    let assetURL: String
    let alt: String
    let compact: Bool
    let fetchedAt: Date?
    let onLink: (URL) -> Void
    var thumbnailSize: CGFloat? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.imageLoadingPaused) private var imageLoadingPaused
    @State private var image: CGImage?
    @State private var loadedKey: String?

    private var imageKey: String {
        "\(assetURL)|\(fetchedAt?.timeIntervalSinceReferenceDate ?? 0)|\(thumbnailSize ?? -1)|\(compact)"
    }

    var body: some View {
        let displaySize: CGFloat? = thumbnailSize ?? (compact ? 28 : nil)
        Button { onLink(url) } label: {
            if let image, loadedKey == imageKey {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(width: displaySize, height: displaySize)
                    .frame(maxWidth: displaySize ?? min(CGFloat(image.width), 900), alignment: .leading)
                    .accessibilityLabel(alt.isEmpty ? Constants.articleImage : alt)
            } else {
                Image(systemName: "photo")
                    .frame(width: displaySize, height: displaySize ?? 80)
                    .frame(maxWidth: displaySize ?? .infinity)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel(alt.isEmpty ? Constants.openImage : alt)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: displaySize ?? .infinity, alignment: .leading)
        .task(id: "\(imageKey)|\(imageLoadingPaused)") {
            guard !imageLoadingPaused, loadedKey != imageKey else { return }
            let container = modelContext.container
            let maxPixelSize = thumbnailSize.map { Int($0 * 3) } ?? (compact ? 84 : 1800)
            let thumbnail: CGImage?
            if let fetchedAt {
                thumbnail = await ImageLoadingService.shared.assetImage(
                    assetURL: assetURL, fetchedAt: fetchedAt, maxPixelSize: maxPixelSize, container: container
                )
            } else {
                thumbnail = await ImageLoadingService.shared.missingAssetImage(
                    assetURL: assetURL, maxPixelSize: maxPixelSize, container: container
                )
            }
            if !Task.isCancelled, let thumbnail {
                image = thumbnail
                loadedKey = imageKey
            }
        }
    }
}
