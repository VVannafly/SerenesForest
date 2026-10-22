import Foundation
import Observation
import SerenesNavigation
import SwiftUI
import SwiftData

private enum Constants {
    static let general = "General"
    static let media = "Media"
}

@MainActor @Observable
final class RootViewModel {
    var selected: Destination = .discover

    func page(at url: String, in context: ModelContext) -> ContentPage? {
        try? context.fetch(FetchDescriptor<ContentPage>(
            predicate: #Predicate { $0.url == url })).first
    }

    func game(slug: String, in context: ModelContext) -> Game? {
        try? context.fetch(FetchDescriptor<Game>(
            predicate: #Predicate { $0.slug == slug })).first
    }

    func pages(gameSlug: String, in context: ModelContext) -> [ContentPage] {
        let game = (try? context.fetch(FetchDescriptor<ContentPage>(
            predicate: #Predicate { $0.gameSlug == gameSlug }))) ?? []
        let general = Constants.general
        let shared = (try? context.fetch(FetchDescriptor<ContentPage>(
            predicate: #Predicate { $0.category == general }))) ?? []
        let media = Constants.media
        let galleries = (try? context.fetch(FetchDescriptor<ContentPage>(
            predicate: #Predicate { $0.category == media }))) ?? []
        return game + shared + galleries
    }

    func asset(at url: String, in context: ModelContext) -> ContentAsset? {
        try? context.fetch(FetchDescriptor<ContentAsset>(
            predicate: #Predicate { $0.url == url })).first
    }

    func item(from data: Data) -> GameNavigationItem? {
        try? JSONDecoder().decode(GameNavigationItem.self, from: data)
    }
}
