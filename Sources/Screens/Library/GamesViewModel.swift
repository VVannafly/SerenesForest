import Foundation
import Observation
import SwiftUI

private enum Constants { static let all = "All" }

@MainActor @Observable
final class GamesViewModel {
    enum SortOrder: String, CaseIterable {
        case title = "Title"
        case releaseNewest = "Newest first"
        case releaseOldest = "Oldest first"
        case status = "Status"
    }

    private static let releaseDates: [String: Int] = [
        "shadow-dragon-and-blade-of-light": 19900420, "gaiden": 19920314,
        "mystery-of-the-emblem": 19940121, "genealogy-of-the-holy-war": 19960514,
        "thracia-776": 19990901, "binding-blade": 20020329,
        "blazing-sword": 20030425, "the-sacred-stones": 20041007,
        "path-of-radiance": 20050420, "radiant-dawn": 20070222,
        "shadow-dragon": 20080807, "light-and-shadow": 20100715,
        "awakening": 20120419, "fire-emblem-fates": 20150625,
        "tokyo-mirage-sessions": 20151226,
        "fire-emblem-heroes": 20170202, "fire-emblem-echoes-shadows-valentia": 20170420,
        "fire-emblem-warriors": 20170928, "three-houses": 20190726,
        "warriors-three-hopes": 20220624, "engage": 20230120,
        "fortunes-weave": 20260917
    ]

    var search = ""
    var platform = Constants.all
    var status = Constants.all
    var sortOrder: SortOrder = .releaseNewest

    func releaseYear(for game: Game) -> Int? { Self.releaseDates[game.slug].map { $0 / 10000 } }

    func overviews(for games: [Game], pages: [ContentPage]) -> [String: GameOverview] {
        GameOverview.indexed(for: games, pages: pages)
    }

    func platforms(for games: [Game]) -> [String] { [Constants.all] + Set(games.map(\.platform)).sorted() }
    func filtered(games: [Game], favoritesOnly: Bool) -> [Game] {
        games.filter { game in
            (!favoritesOnly || game.isFavorite) &&
            (platform == Constants.all || game.platform == platform) &&
            (status == Constants.all || GameProgress(status: game.status).rawValue == status) &&
            (search.isEmpty || game.title.localizedCaseInsensitiveContains(search))
        }.sorted { lhs, rhs in
            switch sortOrder {
            case .title:
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            case .releaseNewest, .releaseOldest:
                let left = Self.releaseDates[lhs.slug] ?? 0
                let right = Self.releaseDates[rhs.slug] ?? 0
                return left == right ? lhs.title < rhs.title :
                    (sortOrder == .releaseNewest ? left > right : left < right)
            case .status:
                let left = GameProgress.allCases.firstIndex(of: GameProgress(status: lhs.status)) ?? 0
                let right = GameProgress.allCases.firstIndex(of: GameProgress(status: rhs.status)) ?? 0
                return left == right ? lhs.title < rhs.title : left < right
            }
        }
    }

}
