import Foundation
import Observation
import SwiftUI

@MainActor @Observable
final class MediaViewModel {
    var search = ""

    func mediaPages(from pages: [ContentPage]) -> [ContentPage] {
        pages.filter { $0.category == "Media" && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)) }
            .sorted {
                if $0.isDownloaded != $1.isDownloaded { return $0.isDownloaded }
                return $0.title < $1.title
            }
    }
    func mediaAssets(from assets: [ContentAsset]) -> [ContentAsset] {
        assets.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
            .sorted {
                if ($0.fetchedAt != nil) != ($1.fetchedAt != nil) { return $0.fetchedAt != nil }
                return $0.title < $1.title
            }
    }

}
