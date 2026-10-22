import Foundation
import Observation
import SwiftData

@MainActor @Observable
final class NewsViewModel {
    var search = ""
    private(set) var pages: [PageListItem] = []
    private(set) var hasMorePages = false
    private(set) var isLoading = true
    private(set) var errorMessage: String?
    private var cursor = PageListCursor()
    private var requestID = UUID()

    func load(in container: ModelContainer) async {
        let id = UUID()
        requestID = id
        pages = []
        hasMorePages = false
        errorMessage = nil
        cursor = PageListCursor()
        await fetch(in: container, requestID: id)
    }

    func loadMore(in container: ModelContainer) async {
        guard !isLoading, hasMorePages else { return }
        await fetch(in: container, requestID: requestID)
    }

    private func fetch(in container: ModelContainer, requestID id: UUID) async {
        isLoading = true
        defer { if requestID == id { isLoading = false } }
        do {
            let batch = try await PageListQueryService.page(in: container, scope: .news,
                search: search.trimmingCharacters(in: .whitespacesAndNewlines), cursor: cursor)
            guard requestID == id, !Task.isCancelled else { return }
            pages.append(contentsOf: batch.items)
            cursor = batch.cursor
            hasMorePages = batch.hasMore
        } catch {
            if requestID == id, !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }
}
