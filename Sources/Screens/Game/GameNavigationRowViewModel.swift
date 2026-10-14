import Foundation

private enum Constants {
    static let newsFeed = "News Feed"
    static let siteHost = "serenesforest.net"
    static let categoryPath = "/category/"
    static let officialArtwork = "official artwork"
    static let aboutTheGame = "About the Game"
    static let gameCategory = "Game"
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
    func destination(for item: GameNavigationItem, pages: [ContentPage]) -> GameNavigationDestination {
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
            let page = pages.first { $0.url == target }
            let prefix = target.hasSuffix("/") ? target : target + "/"
            let hasChildren = pages.contains { $0.url != target && $0.url.hasPrefix(prefix) }
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
