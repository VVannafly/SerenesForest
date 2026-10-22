import Foundation
import SerenesNavigation
import SwiftData

private enum Constants {
    static let newsFeed = "News Feed"
    static let siteHost = "serenesforest.net"
    static let categoryPath = "/category/"
    static let officialArtwork = "official artwork"
    static let aboutTheGame = "About the Game"
    static let gameCategory = "Game"
    static let galleryChildPath = "/nggallery/"
}

enum GameNavigationDestination {
    case about(ContentPage)
    case topicItems
    case newsFeed(slug: String, url: URL)
    case article(ContentPage)
    case artwork(URL)
    case external(URL)
    case section(URL)
    case topicLinks
    case none

    var isExternal: Bool {
        if case .external = self { return true }
        return false
    }

    var isNavigable: Bool {
        if case .none = self { return false }
        return true
    }
}

@MainActor
struct GameNavigationRowViewModel {
    func route(for destination: GameNavigationDestination, item: GameNavigationItem,
               pages: [ContentPage]) -> PageRoute? {
        let slug = pages.first?.gameSlug ?? ""
        switch destination {
        case .about(let page): return .gameAbout(page.url)
        case .topicItems:
            guard let data = try? JSONEncoder().encode(item) else { return nil }
            return .topicItems(data, slug)
        case .newsFeed(let slug, let url): return .newsFeed(slug: slug, url: url.absoluteString)
        case .article(let page): return .article(page.url)
        case .artwork(let url): return .artwork(title: item.title, url: url.absoluteString)
        case .section(let url):
            return .gameLink(title: item.title, url: url.absoluteString, slug: slug)
        case .topicLinks:
            guard let data = try? JSONEncoder().encode(item) else { return nil }
            return .topicLinks(data, slug)
        case .external, .none: return nil
        }
    }

    func destination(for item: GameNavigationItem, pages: [ContentPage],
                     context: ModelContext) -> GameNavigationDestination {
        if item.links.isEmpty, item.children.isEmpty,
           item.title.localizedCaseInsensitiveCompare(Constants.aboutTheGame) == .orderedSame,
           let home = pages.first(where: { $0.category == Constants.gameCategory }) {
            return .about(home)
        }
        if !item.children.isEmpty { return .topicItems }
        if item.links.count == 1, let link = item.links.first {
            let target = link.url.absoluteString
            if item.title.localizedCaseInsensitiveCompare(Constants.newsFeed) == .orderedSame,
               link.url.host == Constants.siteHost, link.url.path.hasPrefix(Constants.categoryPath),
               let slug = pages.compactMap(\.gameSlug).first {
                return .newsFeed(slug: slug, url: link.url)
            }
            let saved = pages.first { $0.url == target }
            let page = saved ?? (link.url.host == Constants.siteHost
                ? (try? context.fetch(FetchDescriptor<ContentPage>(
                    predicate: #Predicate { $0.url == target })).first) : nil)
            let prefix = target.hasSuffix("/") ? target : target + "/"
            let hasChildren = pages.contains {
                $0.url != target && $0.url.hasPrefix(prefix) &&
                !$0.url.dropFirst(prefix.count).hasPrefix(Constants.galleryChildPath.dropFirst())
            }
            if let page, !hasChildren { return .article(page) }
            if !hasChildren && item.title.localizedCaseInsensitiveContains(Constants.officialArtwork) {
                return .artwork(link.url)
            }
            return hasChildren ? .section(link.url) : .external(link.url)
        }
        if !item.links.isEmpty { return .topicLinks }
        return .none
    }
}
