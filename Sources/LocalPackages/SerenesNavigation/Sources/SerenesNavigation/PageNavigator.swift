import Foundation
import Observation

public enum PageRoute: Hashable, Codable {
    case article(String)
    case game(String)
    case gameAbout(String)
    case gameLink(title: String, url: String, slug: String)
    case topicItems(Data, String)
    case topicLinks(Data, String)
    case newsFeed(slug: String, url: String)
    case artwork(title: String, url: String)
    case asset(String)
    case menu(String)
}

@MainActor @Observable
public final class PageNavigator {
    public var path: [PageRoute] = []

    public init() {}

    public func openArticle(_ url: String) {
        path.append(.article(url))
    }

    public func open(_ route: PageRoute) {
        path.append(route)
    }

    public func returnToAncestor(_ route: PageRoute) {
        if let index = path.lastIndex(where: { $0.isSameDestination(as: route) }) {
            path.removeLast(path.count - index - 1)
        } else {
            if let slug = route.gameSlug,
               let gameIndex = path.lastIndex(where: { $0.isSameDestination(as: .game(slug)) }) {
                path.removeLast(path.count - gameIndex - 1)
            } else if !path.isEmpty {
                path.removeLast()
            }
            path.append(route)
        }
    }
}

private extension PageRoute {
    var gameSlug: String? {
        switch self {
        case .game(let slug), .gameLink(_, _, let slug): slug
        default: nil
        }
    }

    func isSameDestination(as other: PageRoute) -> Bool {
        switch (self, other) {
        case let (.gameLink(_, lhsURL, lhsSlug), .gameLink(_, rhsURL, rhsSlug)):
            lhsURL == rhsURL && lhsSlug == rhsSlug
        default:
            self == other
        }
    }
}
