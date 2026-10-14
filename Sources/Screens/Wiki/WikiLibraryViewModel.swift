import Foundation
import Observation
import SwiftUI

private enum Constants { static let all = "All" }

@MainActor @Observable
final class WikiLibraryViewModel {
    var search = ""
    var selectedGroup = Constants.all
    var selectedGame = Constants.all

    func wikiPages(from allPages: [ContentPage]) -> [ContentPage] {
        allPages.filter { $0.category.hasPrefix("Wiki · ") && $0.isDownloaded }
    }

    func groups(from allPages: [ContentPage]) -> [String] {
        [Constants.all] + Set(wikiPages(from: allPages).map { $0.category.replacingOccurrences(of: "Wiki · ", with: "") }).sorted()
    }

    func pages(from allPages: [ContentPage]) -> [ContentPage] {
        wikiPages(from: allPages).filter { page in
            (selectedGroup == Constants.all || page.category == "Wiki · \(selectedGroup)") &&
            (selectedGame == Constants.all || (page.wikiGameSlugs ?? "").contains("|\(selectedGame)|") || page.gameSlug == selectedGame) &&
            AppText.matches(page, query: search)
        }.sorted { lhs, rhs in
            let left = Catalog.games.firstIndex { $0.0 == lhs.gameSlug } ?? Int.max
            let right = Catalog.games.firstIndex { $0.0 == rhs.gameSlug } ?? Int.max
            return left == right ? lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending : left < right
        }
    }

}
