import Foundation
import Observation
import SwiftUI

@MainActor @Observable
final class PageDetailViewModel {
    private(set) var articleBlocks: [ArticleBlock]?
    private(set) var presentationBlocks: [ArticlePresentationBlock]?
    var translationAttempted = false
    var translatedTitle: String?
    var translationProgress: String?
    var translationError: String?
    var articleAssets: [String: Date] = [:]
    var imageURLs: [String] = []
    var linkedPage: ContentPage?
    var showLinkedPage = false
    var linkedAsset: ContentAsset?
    var externalLink: URL?
    var showExternalLinkPrompt = false
    var trailTarget: ArticleTrailTarget?

    func showArticle(_ blocks: [ArticleBlock]?) {
        articleBlocks = blocks
        presentationBlocks = blocks.map(ArticlePresentationMapper.map)
    }

    func articleTint(for page: ContentPage) -> Color {
        page.gameSlug.map { GameTheme.forGame($0).accent } ?? Palette.accent
    }

    func gameShortTitle(for page: ContentPage) -> String? {
        guard let slug = page.gameSlug else { return nil }
        return Catalog.games.first(where: { $0.0 == slug })?.1
            ?? slug.replacingOccurrences(of: "-", with: " ").capitalized
    }

    func articleTrail(for page: ContentPage, translations: [String: String]) -> [ArticleTrailTarget] {
        guard let slug = page.gameSlug, let source = URL(string: page.url) else { return [] }
        var trail = [ArticleTrailTarget(id: "game:\(slug)", title: gameShortTitle(for: page) ?? slug, url: nil)]
        let parts = source.pathComponents.filter { $0 != "/" }
        guard let gameIndex = parts.firstIndex(of: slug), parts.count > gameIndex + 1,
              let host = source.host else { return trail }
        var path = Array(parts.prefix(gameIndex + 1))
        for part in parts.dropFirst(gameIndex + 1).dropLast() {
            path.append(part)
            guard let url = URL(string: "\(source.scheme ?? "https")://\(host)/\(path.joined(separator: "/"))/") else { continue }
            let title = part.replacingOccurrences(of: "-", with: " ").capitalized
            trail.append(ArticleTrailTarget(id: url.absoluteString,
                                            title: translations[title] ?? title,
                                            url: url))
        }
        return trail
    }

    func trailLabel(for page: ContentPage, translations: [String: String]) -> String {
        (articleTrail(for: page, translations: translations).dropFirst().map(\.title)
            + [translatedTitle ?? page.title]).joined(separator: " › ")
    }
}
