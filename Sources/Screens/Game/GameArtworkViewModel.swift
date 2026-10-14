import Foundation

private enum Constants {
    static let imageMimePrefix = "image/"
    static let galleryPath = "/gallery/"
}

@MainActor
struct GameArtworkViewModel {
    func artwork(from assets: [ContentAsset], sourceURL: URL) -> [ContentAsset] {
        let galleryPrefix = Constants.galleryPath + sourceURL.lastPathComponent
        return assets.filter { asset in
            asset.fetchedAt != nil && asset.mimeType?.hasPrefix(Constants.imageMimePrefix) == true &&
            (asset.url.localizedCaseInsensitiveContains(galleryPrefix) ||
             asset.sourcePageURL == sourceURL.absoluteString)
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
}
