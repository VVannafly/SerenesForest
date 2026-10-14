import Foundation
import Observation
import SwiftUI

private enum Constants {
    static let gameCategory = "Game"
}

struct SavedPageEntry: Identifiable {
    let page: ContentPage
    let game: Game?
    var id: String { page.url }
}

@MainActor @Observable
final class SavedPagesViewModel {
    var search = ""

    func entries(savedPages: [ContentPage], games: [Game]) -> [SavedPageEntry] {
        var gamesBySlug: [String: Game] = [:]
        var gamesByURL: [String: Game] = [:]
        for game in games {
            if gamesBySlug[game.slug] == nil { gamesBySlug[game.slug] = game }
            if gamesByURL[game.sourceURL] == nil { gamesByURL[game.sourceURL] = game }
        }
        return savedPages.filter { page in
            AppText.matches(page, query: search) ||
                (page.gameSlug.flatMap { slug in
                    gamesBySlug[slug]?.title.localizedCaseInsensitiveContains(search)
                } ?? false)
        }.map { page in
            SavedPageEntry(page: page,
                           game: page.category == Constants.gameCategory ? gamesByURL[page.url] : nil)
        }
    }

}
