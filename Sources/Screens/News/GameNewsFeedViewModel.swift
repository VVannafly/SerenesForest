import Foundation
import Observation
import SwiftUI

@MainActor @Observable
final class GameNewsFeedViewModel {
    let gameSlug: String
    let categoryURL: URL

    var search = ""
    var isLoading = false
    var errorMessage: String?
    var nextPage: Int
    var hasMore: Bool

    init(gameSlug: String, categoryURL: URL) {
        self.gameSlug = gameSlug
        self.categoryURL = categoryURL
        let defaults = UserDefaults.standard
        nextPage = max(defaults.integer(forKey: "SerenesForest.gameNewsPages.\(gameSlug)"), 1) + 1
        hasMore = defaults.object(forKey: "SerenesForest.gameNewsHasMore.\(gameSlug)") as? Bool ?? true
    }

    func pages(from news: [ContentPage]) -> [ContentPage] {
        let dated = news.filter { page in
            (page.newsGameSlugs ?? "").split(separator: "|").contains(Substring(gameSlug)) &&
            AppText.matches(page, query: search)
        }.map { ($0, $0.newsPublishedAt ?? ContentPageMapper.newsDate($0)) }
        return dated.sorted { left, right in
            left.1 == right.1 ? left.0.title < right.0.title : left.1 > right.1
        }.map(\.0)
    }


    func load(pageNumber: Int, force: Bool = false, sync: ContentSync) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            hasMore = try await sync.syncGameNews(gameSlug: gameSlug, categoryURL: categoryURL,
                                                  pageNumber: pageNumber, force: force)
            if pageNumber > 1 { nextPage = pageNumber + 1 }
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }}
