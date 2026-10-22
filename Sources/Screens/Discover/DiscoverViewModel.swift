import Foundation
import Observation
import SerenesParsing
import SwiftData

@MainActor @Observable
final class DiscoverViewModel {
    private static let newsLimit = 3
    private(set) var downloadedArticleCount = 0

    func availableGames(from games: [Game]) -> [Game] {
        games.filter { !$0.sourceURL.contains("/wiki/") }
    }

    func recentGames(from games: [Game], stored: String) -> [Game] {
        let recent = RecentGamesHistory.games(from: games, stored: stored)
        let recentSlugs = Set(recent.map(\.slug))
        let featured = games.suffix(RecentGamesHistory.limit).reversed()
            .filter { !recentSlugs.contains($0.slug) }
        return Array((recent + featured).prefix(RecentGamesHistory.limit))
    }

    func latestNews(from pages: [ContentPage]) -> [ContentPage] {
        let dated = pages.filter { $0.category == "News" && $0.isDownloaded && $0.url != SiteScope.home }
            .map { ($0, ContentPageMapper.newsDate($0)) }
        return Array(dated.sorted { $0.1 > $1.1 }.prefix(Self.newsLimit).map(\.0))
    }

    func refreshArticleCount(in context: ModelContext) {
        let descriptor = FetchDescriptor<ContentPage>(predicate: #Predicate { $0.isDownloaded == true })
        if let count = try? context.fetchCount(descriptor) { downloadedArticleCount = count }
    }

    func overviews(for games: [Game], pages: [ContentPage]) -> [String: GameOverview] {
        GameOverview.indexed(for: games, pages: pages)
    }

    func saveAllImages(using sync: ContentSync) async {
        await sync.saveAllImages()
    }
}
