import Foundation
import Observation
import SwiftData

private enum Constants {
    static let pageSize = 50
}

struct MediaAsset: Identifiable, Sendable {
    let url: String
    let title: String
    let mimeType: String?

    var id: String { url }
}

@MainActor @Observable
final class MediaViewModel {
    var search = ""
    private(set) var assets: [MediaAsset] = []
    private(set) var totalAssetCount = 0
    private(set) var isLoadingAssets = false
    private(set) var visiblePageCount = Constants.pageSize
    private var requestID = UUID()

    func mediaPages(from pages: [ContentPage]) -> [ContentPage] {
        pages.filter { $0.category == "Media" && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)) }
            .sorted {
                if $0.isDownloaded != $1.isDownloaded { return $0.isDownloaded }
                return $0.title < $1.title
            }
    }

    func visiblePages(from pages: [ContentPage]) -> ArraySlice<ContentPage> {
        pages.prefix(visiblePageCount)
    }

    func hasMorePages(in pages: [ContentPage]) -> Bool { visiblePageCount < pages.count }
    func showMorePages() { visiblePageCount += Constants.pageSize }
    var hasMoreAssets: Bool { assets.count < totalAssetCount }

    func loadAssets(in container: ModelContainer) async {
        visiblePageCount = Constants.pageSize
        assets = []
        totalAssetCount = 0
        await fetchAssets(in: container, offset: 0)
    }

    func loadMoreAssets(in container: ModelContainer) async {
        guard !isLoadingAssets, hasMoreAssets else { return }
        await fetchAssets(in: container, offset: assets.count)
    }

    private func fetchAssets(in container: ModelContainer, offset: Int) async {
        let id = UUID()
        requestID = id
        isLoadingAssets = true
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let fetchTask = Task.detached(priority: .userInitiated) { () -> (Int, [MediaAsset])? in
            let context = ModelContext(container)
            let predicate: Predicate<ContentAsset>? = query.isEmpty ? nil :
                #Predicate<ContentAsset> { $0.title.localizedStandardContains(query) }
            let countDescriptor = FetchDescriptor<ContentAsset>(predicate: predicate)
            guard let count = try? context.fetchCount(countDescriptor), !Task.isCancelled else { return nil }
            var descriptor = FetchDescriptor<ContentAsset>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.fetchedAt, order: .reverse), SortDescriptor(\.title)]
            )
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = Constants.pageSize
            guard let models = try? context.fetch(descriptor), !Task.isCancelled else { return nil }
            return (count, models.map {
                MediaAsset(url: $0.url, title: $0.title, mimeType: $0.mimeType)
            })
        }
        let result = await withTaskCancellationHandler {
            await fetchTask.value
        } onCancel: {
            fetchTask.cancel()
        }
        guard requestID == id else { return }
        isLoadingAssets = false
        guard !Task.isCancelled, let (count, page) = result else { return }
        totalAssetCount = count
        if offset == 0 { assets = page }
        else { assets.append(contentsOf: page) }
    }
}
