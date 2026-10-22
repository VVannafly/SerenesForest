import Foundation
import Observation
import SwiftUI
import SwiftData
@preconcurrency import Translation

private enum Constants {
    static let fatesSlug = "fire-emblem-fates"
    static let wikiPrefix = "Wiki · "
    static let wikiChapters = "Wiki · Chapters"
    static let wikiActs = "Wiki · Acts"
    static let wikiSeries = "Wiki · Series"
    static let wikiMechanics = "Wiki · Mechanics"
    static let mechanicsGames: Set<String> = ["awakening", "shadow-dragon", "light-and-shadow"]
    static let general = "General"
}

@MainActor @Observable
final class GameDetailViewModel {
    var sections: [GameNavigationSection] = []
    var navigationTranslations: [String: String] = [:]
    var navigationTranslationAttempted = false
    var guideWidth: CGFloat = 0
    var selectedFatesRoute: FatesRoute = .birthright
    var expandedWikiGroups: Set<String> = []

    func hasRoutes(for game: Game) -> Bool { game.slug == Constants.fatesSlug }

    func homePage(for game: Game, pages: [ContentPage]) -> ContentPage? {
        pages.first { $0.url == game.sourceURL }
    }

    func overview(for game: Game, pages: [ContentPage]) -> GameOverview? {
        GameOverview(page: homePage(for: game, pages: pages))
    }

    func wikiSections(pages: [ContentPage], memberships: [WikiGamePage], gameSlug: String) -> [WikiGuideSection] {
        var unique: [String: ContentPage] = [:]
        for page in pages where page.category.hasPrefix(Constants.wikiPrefix) && page.isDownloaded {
            unique[page.url] = page
        }
        var links: [String: WikiGamePage] = [:]
        for membership in memberships {
            guard let page = membership.page else { continue }
            links[page.url] = membership
            if page.category.hasPrefix(Constants.wikiPrefix), page.isDownloaded { unique[page.url] = page }
        }
        let grouped = Dictionary(grouping: unique.values) { page in
            page.category == Constants.wikiSeries && Constants.mechanicsGames.contains(gameSlug)
                ? Constants.wikiMechanics : page.category
        }
        return grouped.keys.sorted().map { title in
            let entries = (grouped[title] ?? []).map { page in
                WikiGuideEntry(page: page, position: links[page.url]?.chapterPosition,
                               label: links[page.url]?.chapterLabel)
            }.sorted { left, right in
                if title == Constants.wikiChapters || title == Constants.wikiActs {
                    let a = left.position ?? Int.max
                    let b = right.position ?? Int.max
                    if a != b { return a < b }
                }
                return left.page.title.localizedStandardCompare(right.page.title) == .orderedAscending
            }
            return WikiGuideSection(title: title, entries: entries)
        }
    }

    func wikiArticleCount(in sections: [WikiGuideSection]) -> Int {
        sections.reduce(0) { $0 + $1.entries.count }
    }

    func visibleSections(gameSlug: String) -> [GameNavigationSection] {
        gameSlug == Constants.fatesSlug ? sections.filter { selectedFatesRoute.includes($0.title) } : sections
    }

    var sectionColumnCount: Int { guideWidth >= 600 ? 3 : 2 }

    func sectionRows(gameSlug: String) -> [[GameNavigationSection]] {
        let visible = visibleSections(gameSlug: gameSlug)
        return stride(from: 0, to: visible.count, by: sectionColumnCount).map {
            Array(visible[$0..<min($0 + sectionColumnCount, visible.count)])
        }
    }

    func expandedSection(in row: [GameNavigationSection], id: Int) -> GameNavigationSection? {
        row.first { $0.id == id }
    }

    private static func combiningFatesGeneral(_ sections: [GameNavigationSection]) -> [GameNavigationSection] {
        let general = sections.filter { $0.title == Constants.general }
        guard general.count > 1 else { return sections }
        let items = general.flatMap(\.items).enumerated().map { index, item in
            GameNavigationItem(id: index, title: item.title, links: item.links, children: item.children)
        }
        var keptGeneral = false
        return sections.compactMap { section in
            guard section.title == Constants.general else { return section }
            guard !keptGeneral else { return nil }
            keptGeneral = true
            return GameNavigationSection(id: section.id, title: section.title, items: items)
        }
    }

    var navigationSourceTexts: [String] {
        var titles = Set<String>()
        func collect(_ item: GameNavigationItem) {
            titles.insert(item.title)
            item.links.forEach { titles.insert($0.title) }
            item.children.forEach(collect)
        }
        for section in sections {
            titles.insert(section.title)
            section.items.forEach(collect)
        }
        return titles.filter { !$0.isEmpty && !$0.hasPrefix("http") &&
            $0.rangeOfCharacter(from: .letters) != nil }.sorted()
    }

    func loadNavigation(home: ContentPage, gameSlug: String, language: String) async {
        sections = []
        navigationTranslationAttempted = false
        let html = home.html
        let source = home.url
        let parsed = await Task.detached(priority: .userInitiated) {
            NativeArticleParser.gameNavigation(html, source: source)
        }.value
        guard !Task.isCancelled else { return }
        sections = gameSlug == Constants.fatesSlug ? Self.combiningFatesGeneral(parsed) : parsed
        restoreNavigation(home: home, language: language)
    }

    func restoreNavigation(home: ContentPage?, language: String) {
        if language == "ru", let data = home?.russianNavigation {
            navigationTranslations = (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        } else {
            navigationTranslations = [:]
        }
    }

    func translateNavigation(
        using session: TranslationSession,
        home: ContentPage?,
        context: ModelContext,
        language: String
    ) async {
        guard let home,
              !navigationTranslationAttempted, language == "ru" else { return }
        navigationTranslationAttempted = true
        let texts = navigationSourceTexts
        var translated = navigationTranslations
        let missing = texts.filter { translated[$0] == nil }
        do {
            for start in stride(from: 0, to: missing.count, by: 32) {
                try Task.checkCancellation()
                let chunk = Array(missing[start..<min(start + 32, missing.count)])
                // The framework's Request is a value type without Sendable annotation.
                // This batch is passed once and never mutated concurrently.
                nonisolated(unsafe) let requests = chunk.enumerated().map { index, value in
                    TranslationSession.Request(sourceText: value, clientIdentifier: String(index))
                }
                for response in try await session.translations(from: requests) {
                    let source = response.clientIdentifier.flatMap(Int.init)
                        .flatMap { chunk.indices.contains($0) ? chunk[$0] : nil } ?? response.sourceText
                    translated[source] = response.targetText
                }
                home.russianNavigation = try JSONEncoder().encode(translated)
                try context.save()
                navigationTranslations = translated
            }
        } catch {
            // Saved translations remain visible if a later batch fails.
        }
    }

}
