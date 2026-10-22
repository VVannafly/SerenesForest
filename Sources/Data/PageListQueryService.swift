import Foundation
import SwiftData

private enum Constants {
    static let all = "All"
    static let news = "News"
    static let home = "https://serenesforest.net/"
    static let wikiPrefix = "Wiki · "
    static let pageSize = 50
}

struct PageListItem: Identifiable, Sendable {
    let url: String
    let title: String
    let russianTitle: String?
    let category: String
    let gameSlug: String?
    let newsPublishedAt: Date?
    let fetchedAt: Date?

    var id: String { url }

    var publishedAt: Date? {
        guard category == Constants.news else { return nil }
        if let newsPublishedAt { return newsPublishedAt }
        let parts = URL(string: url)?.pathComponents ?? []
        if parts.count >= 4,
           let year = Int(parts[1]), let month = Int(parts[2]), let day = Int(parts[3]) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? fetchedAt
        }
        return fetchedAt
    }
}

enum PageListScope: Sendable {
    case all(category: String)
    case wiki(group: String, game: String)
    case news
}

struct PageListCursor: Sendable {
    var downloaded = 0
    var remaining = 0
    var downloadedExhausted = false
}

struct PageListBatch: Sendable {
    let items: [PageListItem]
    let cursor: PageListCursor
    let hasMore: Bool
}

struct PageListMetadata: Sendable {
    let count: Int
    let categories: [String]
}

enum PageListQueryService {
    static func page(in container: ModelContainer, scope: PageListScope, search: String,
                     cursor: PageListCursor) async throws -> PageListBatch {
        let task = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let context = ModelContext(container)
            var next = cursor
            var items: [PageListItem] = []
            if !next.downloadedExhausted {
                let downloaded = try fetch(in: context, scope: scope, search: search,
                                           downloaded: true, offset: next.downloaded,
                                           limit: Constants.pageSize + 1)
                try Task.checkCancellation()
                let taken = Array(downloaded.prefix(Constants.pageSize))
                items = taken
                next.downloaded += taken.count
                if downloaded.count > Constants.pageSize {
                    return PageListBatch(items: items, cursor: next, hasMore: true)
                }
                next.downloadedExhausted = true
            }
            if case .wiki = scope {
                return PageListBatch(items: items, cursor: next, hasMore: false)
            }
            let available = Constants.pageSize - items.count
            let remaining = try fetch(in: context, scope: scope, search: search,
                                      downloaded: false, offset: next.remaining,
                                      limit: available + 1)
            try Task.checkCancellation()
            let taken = Array(remaining.prefix(available))
            items.append(contentsOf: taken)
            next.remaining += taken.count
            return PageListBatch(items: items, cursor: next, hasMore: remaining.count > available)
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    static func metadata(in container: ModelContainer, scope: PageListScope,
                         search: String) async throws -> PageListMetadata {
        let task = Task.detached(priority: .utility) {
            try Task.checkCancellation()
            let context = ModelContext(container)
            let count = try context.fetchCount(FetchDescriptor<ContentPage>(
                predicate: predicate(scope: scope, search: search, downloaded: nil)))
            try Task.checkCancellation()
            let categories: [String]
            switch scope {
            case .all:
                var descriptor = FetchDescriptor<ContentPage>()
                descriptor.propertiesToFetch = [\.category]
                categories = [Constants.all] + Set(try context.fetch(descriptor).map(\.category)).sorted()
            case .wiki:
                let prefix = Constants.wikiPrefix
                var descriptor = FetchDescriptor<ContentPage>(predicate: #Predicate {
                    $0.isDownloaded && $0.category.starts(with: prefix)
                })
                descriptor.propertiesToFetch = [\.category]
                categories = [Constants.all] + Set(try context.fetch(descriptor).map {
                    $0.category.replacingOccurrences(of: prefix, with: "")
                }).sorted()
            case .news:
                categories = []
            }
            try Task.checkCancellation()
            return PageListMetadata(count: count, categories: categories)
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private static func fetch(in context: ModelContext, scope: PageListScope, search: String,
                              downloaded: Bool, offset: Int, limit: Int) throws -> [PageListItem] {
        let sort: [SortDescriptor<ContentPage>]
        switch scope {
        case .news: sort = [SortDescriptor(\.url, order: .reverse)]
        case .all, .wiki: sort = [SortDescriptor(\.title), SortDescriptor(\.url)]
        }
        var descriptor = FetchDescriptor<ContentPage>(
            predicate: predicate(scope: scope, search: search, downloaded: downloaded), sortBy: sort)
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        descriptor.propertiesToFetch = [\.url, \.title, \.russianTitle, \.category,
                                        \.gameSlug, \.newsPublishedAt, \.fetchedAt]
        return try context.fetch(descriptor).map {
            PageListItem(url: $0.url, title: $0.title, russianTitle: $0.russianTitle,
                         category: $0.category, gameSlug: $0.gameSlug,
                         newsPublishedAt: $0.newsPublishedAt, fetchedAt: $0.fetchedAt)
        }
    }

    private static func predicate(scope: PageListScope, search: String,
                                  downloaded: Bool?) -> Predicate<ContentPage> {
        let includeBoth = downloaded == nil
        let isDownloaded = downloaded ?? false
        switch scope {
        case .all(let category):
            let allCategories = category == Constants.all
            if search.isEmpty {
                return #Predicate { page in
                    (includeBoth || page.isDownloaded == isDownloaded) &&
                    (allCategories || page.category == category)
                }
            }
            return #Predicate { page in
                (includeBoth || page.isDownloaded == isDownloaded) &&
                (allCategories || page.category == category) &&
                (page.title.localizedStandardContains(search) ||
                 page.plainText.localizedStandardContains(search) ||
                 page.russianTitle?.localizedStandardContains(search) == true ||
                 page.russianPlainText?.localizedStandardContains(search) == true)
            }
        case .wiki(let group, let game):
            let prefix = Constants.wikiPrefix
            let allGroups = group == Constants.all
            let category = prefix + group
            let allGames = game == Constants.all
            let gameMarker = "|\(game)|"
            if search.isEmpty {
                return #Predicate { page in
                    page.isDownloaded && page.category.starts(with: prefix) &&
                    (allGroups || page.category == category) &&
                    (allGames || page.wikiGameSlugs?.contains(gameMarker) == true || page.gameSlug == game)
                }
            }
            if allGames {
                return #Predicate { page in
                    page.isDownloaded && page.category.starts(with: prefix) &&
                    (allGroups || page.category == category) &&
                    (page.title.localizedStandardContains(search) ||
                     page.plainText.localizedStandardContains(search) ||
                     page.russianTitle?.localizedStandardContains(search) == true ||
                     page.russianPlainText?.localizedStandardContains(search) == true)
                }
            }
            if allGroups {
                return #Predicate { page in
                    page.isDownloaded && page.category.starts(with: prefix) &&
                    (page.wikiGameSlugs?.contains(gameMarker) == true || page.gameSlug == game) &&
                    (page.title.localizedStandardContains(search) ||
                     page.plainText.localizedStandardContains(search))
                }
            }
            return #Predicate { page in
                page.isDownloaded && page.category == category &&
                (page.wikiGameSlugs?.contains(gameMarker) == true || page.gameSlug == game) &&
                (page.title.localizedStandardContains(search) ||
                 page.plainText.localizedStandardContains(search))
            }
        case .news:
            let news = Constants.news
            let home = Constants.home
            if search.isEmpty {
                return #Predicate { page in
                    page.category == news && page.url != home &&
                    (includeBoth || page.isDownloaded == isDownloaded)
                }
            }
            return #Predicate { page in
                page.category == news && page.url != home &&
                (includeBoth || page.isDownloaded == isDownloaded) &&
                (page.title.localizedStandardContains(search) ||
                 page.plainText.localizedStandardContains(search) ||
                 page.russianTitle?.localizedStandardContains(search) == true)
            }
        }
    }
}
