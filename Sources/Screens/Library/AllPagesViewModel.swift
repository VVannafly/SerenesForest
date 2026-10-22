import Foundation
import Observation
import SwiftData

private enum Constants {
    static let all = "All"
}

@MainActor @Observable
final class AllPagesViewModel {
    var search = ""
    var category = Constants.all
    private(set) var categories = [Constants.all]
    private(set) var pages: [PageListItem] = []
    private(set) var totalCount: Int?
    private(set) var isLoading = false
    private(set) var hasMorePages = false
    private(set) var errorMessage: String?
    private var cursor = PageListCursor()
    private var requestID = UUID()

    func load(in container: ModelContainer) async {
        let id = UUID()
        requestID = id
        pages = []
        totalCount = nil
        hasMorePages = false
        errorMessage = nil
        cursor = PageListCursor()
        let scope = PageListScope.all(category: category)
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        await fetch(in: container, scope: scope, search: query, requestID: id)
        guard requestID == id, !Task.isCancelled else { return }
        if let result = try? await PageListQueryService.metadata(in: container, scope: scope, search: query),
           requestID == id, !Task.isCancelled {
            totalCount = result.count
            categories = result.categories
        }
    }

    func loadMore(in container: ModelContainer) async {
        guard !isLoading, hasMorePages else { return }
        await fetch(in: container, scope: .all(category: category),
                    search: search.trimmingCharacters(in: .whitespacesAndNewlines), requestID: requestID)
    }

    private func fetch(in container: ModelContainer, scope: PageListScope, search: String,
                       requestID id: UUID) async {
        isLoading = true
        defer { if requestID == id { isLoading = false } }
        do {
            let batch = try await PageListQueryService.page(in: container, scope: scope,
                                                            search: search, cursor: cursor)
            guard requestID == id, !Task.isCancelled else { return }
            pages.append(contentsOf: batch.items)
            cursor = batch.cursor
            hasMorePages = batch.hasMore
        } catch {
            if requestID == id, !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }
}
