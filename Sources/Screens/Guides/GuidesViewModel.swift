import Foundation
import Observation
import SwiftUI

@MainActor @Observable
final class GuidesViewModel {
    private static let pageSize = 25
    private static let gameTitles = Dictionary(uniqueKeysWithValues: Catalog.games.map { ($0.0, $0.1) })
    private static let gameOrder = Dictionary(uniqueKeysWithValues:
        Catalog.games.reversed().enumerated().map { ($0.element.0, $0.offset) })
    private static let topicOrder = ["General", "Characters", "Classes", "Inventory", "Chapters", "Maps", "Scripts", "Miscellaneous"]

    var search = ""
    var expandedGames: Set<String> = []
    var expandedTopics: Set<String> = []
    var collapsedSearchGames: Set<String> = []
    var collapsedSearchTopics: Set<String> = []
    private var visiblePageCounts: [String: Int] = [:]

    func visiblePages(in topic: GuideTopic, id: String) -> ArraySlice<ContentPage> {
        topic.pages.prefix(visiblePageCounts[id] ?? Self.pageSize)
    }

    func hasMorePages(in topic: GuideTopic, id: String) -> Bool {
        (visiblePageCounts[id] ?? Self.pageSize) < topic.pages.count
    }

    func showMorePages(id: String) {
        visiblePageCounts[id, default: Self.pageSize] += Self.pageSize
    }

    func topicSymbol(_ title: String) -> String {
        if title == "Chapters" || title == "Maps" { return "map.fill" }
        return GameSection.style(for: title).symbol
    }

    func isGameExpanded(_ slug: String) -> Bool {
        search.isEmpty ? expandedGames.contains(slug) : !collapsedSearchGames.contains(slug)
    }

    func setGameExpanded(_ expanded: Bool, slug: String) {
        if search.isEmpty {
            if expanded { expandedGames.insert(slug) } else { expandedGames.remove(slug) }
        } else {
            if expanded { collapsedSearchGames.remove(slug) } else { collapsedSearchGames.insert(slug) }
        }
    }

    func isTopicExpanded(_ id: String) -> Bool {
        search.isEmpty ? expandedTopics.contains(id) : !collapsedSearchTopics.contains(id)
    }

    func setTopicExpanded(_ expanded: Bool, id: String) {
        if search.isEmpty {
            if expanded { expandedTopics.insert(id) } else { expandedTopics.remove(id) }
        } else {
            if expanded { collapsedSearchTopics.remove(id) } else { collapsedSearchTopics.insert(id) }
        }
    }

    func resetSearchExpansion() {
        collapsedSearchGames.removeAll()
        collapsedSearchTopics.removeAll()
        visiblePageCounts.removeAll()
    }

    func pageCount(in games: [GuideGame]) -> Int {
        games.reduce(0) { $0 + $1.count }
    }

    func games(from allGuides: [ContentPage]) -> [GuideGame] {
        let filtered = allGuides.filter { AppText.matches($0, query: search) }
        let byGame = Dictionary(grouping: filtered) { $0.gameSlug ?? "other" }
        return byGame.map { slug, pages in
            let byTopic = Dictionary(grouping: pages) { topic(for: $0, slug: slug) }
            let topics = byTopic.map { title, pages in
                GuideTopic(title: title, pages: pages.sorted {
                    if $0.isDownloaded != $1.isDownloaded { return $0.isDownloaded }
                    return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                })
            }.sorted { left, right in
                let a = Self.topicOrder.firstIndex(of: left.title) ?? Int.max
                let b = Self.topicOrder.firstIndex(of: right.title) ?? Int.max
                return a == b ? left.title.localizedStandardCompare(right.title) == .orderedAscending : a < b
            }
            return GuideGame(slug: slug, title: Self.gameTitles[slug] ?? slug.replacingOccurrences(of: "-", with: " ").capitalized,
                             topics: topics)
        }.sorted { left, right in
            let a = Self.gameOrder[left.slug] ?? Int.max
            let b = Self.gameOrder[right.slug] ?? Int.max
            return a == b ? left.title < right.title : a < b
        }
    }

    func topic(for page: ContentPage, slug: String) -> String {
        let parts = URL(string: page.url)?.pathComponents.filter { $0 != "/" } ?? []
        guard let index = parts.firstIndex(of: slug) else {
            let title = page.title.lowercased()
            if title.contains("script") || title.contains("conversation") || title.contains("dialogue") { return "Scripts" }
            if title.contains("chapter") || title.contains("prologue") || title.contains("side stor") ||
                title.contains("story mode") || title.contains("history mode") || title.contains("requests:") { return "Chapters" }
            if title.contains("character") || title.contains("recruitment") { return "Characters" }
            if title.contains("class") || title.contains("growth rate") || title.contains("skill") ||
                title.contains("abilit") { return "Classes" }
            if ["weapon", "item", "sword", "lance", "axe", "bow", "tome", "gauntlet", "carnage", "accessor"]
                .contains(where: title.contains) { return "Inventory" }
            if title.contains("map") { return "Maps" }
            return "General"
        }
        guard parts.count > index + 2 else { return "General" }
        let name = parts[index + 1].lowercased()
        switch name {
        case "general": return "General"
        case "characters", "character": return "Characters"
        case "classes", "class": return "Classes"
        case "inventory", "items", "weapons": return "Inventory"
        case "chapters", "chapter": return "Chapters"
        case "maps", "map": return "Maps"
        case "scripts", "script", "game-scripts": return "Scripts"
        case "miscellaneous", "misc": return "Miscellaneous"
        default: return name.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }

}
