import Foundation

struct GameLinkChild: Identifiable {
    let title: String
    let url: URL
    let page: ContentPage?
    let hasDescendants: Bool
    var id: String { url.absoluteString }
}

struct GameLinkContent {
    let page: ContentPage?
    let children: [GameLinkChild]
}

@MainActor
struct GameLinkViewModel {
    func content(url: URL, pages: [ContentPage]) -> GameLinkContent {
        let source = url.absoluteString
        let prefix = source.hasSuffix("/") ? source : source + "/"
        var byURL: [String: ContentPage] = [:]
        var descendants: [String: Bool] = [:]
        for page in pages {
            if byURL[page.url] == nil { byURL[page.url] = page }
            guard page.url.hasPrefix(prefix) else { continue }
            let remainder = page.url.dropFirst(prefix.count)
            guard let component = remainder.split(separator: "/").first else { continue }
            let childURL = prefix + component + "/"
            descendants[childURL, default: false] = descendants[childURL, default: false] || page.url != childURL
        }
        let children = descendants.compactMap { path, hasDescendants -> GameLinkChild? in
            guard let childURL = URL(string: path) else { return nil }
            let page = byURL[path]
            let title = page.map(AppText.title) ?? String(childURL.lastPathComponent)
                .replacingOccurrences(of: "-", with: " ").capitalized
            return GameLinkChild(title: title, url: childURL, page: page, hasDescendants: hasDescendants)
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        return GameLinkContent(page: byURL[source], children: children)
    }
}
