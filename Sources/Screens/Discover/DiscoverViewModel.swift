import Foundation
import Observation
import SerenesParsing

@MainActor @Observable
final class DiscoverViewModel {
    private static let newsLimit = 3
    private static let featuredGameLimit = 8

    func availableGames(from games: [Game]) -> [Game] {
        games.filter { !$0.sourceURL.contains("/wiki/") }
    }

    func featuredGames(from games: [Game]) -> [Game] {
        Array(games.suffix(Self.featuredGameLimit).reversed())
    }

    func latestNews(from pages: [ContentPage]) -> [ContentPage] {
        let dated = pages.filter { $0.category == "News" && $0.isDownloaded && $0.url != SiteScope.home }
            .map { ($0, ContentPageMapper.newsDate($0)) }
        return Array(dated.sorted { $0.1 > $1.1 }.prefix(Self.newsLimit).map(\.0))
    }

    func downloadedArticleCount(in pages: [ContentPage]) -> Int {
        pages.filter(\.isDownloaded).count
    }

    func overviews(for games: [Game], pages: [ContentPage]) -> [String: GameOverview] {
        GameOverview.indexed(for: games, pages: pages)
    }

    func saveAllImages(using sync: ContentSync) async {
        await sync.saveAllImages()
    }
}
