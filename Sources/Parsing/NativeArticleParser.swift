import Foundation

// A small, forgiving HTML reader for the archived WordPress article bodies.
// The archive contains unclosed tags, so XMLParser cannot be used here.
final class ArticleNode {
    let tag: String
    let attributes: [String: String]
    var value = ""
    var children: [ArticleNode] = []

    init(_ tag: String, attributes: [String: String] = [:], value: String = "") {
        self.tag = tag
        self.attributes = attributes
        self.value = value
    }

    func descendants(_ name: String) -> [ArticleNode] {
        children.flatMap { child in
            (child.tag == name ? [child] : []) + child.descendants(name)
        }
    }
}

enum NativeArticleParser {
    static func removingObsoletePageTabs(_ blocks: [ArticleBlock]) -> (blocks: [ArticleBlock], changed: Bool) {
        var changed = false
        let cleaned = blocks.compactMap { block -> ArticleBlock? in
            guard case .paragraph(let runs) = block else { return block }
            let text = runs.map(\.text).joined().lowercased()
            let markers = ["page 1", "page 2"]
            let russianMarkers = ["страница 1", "страница 2"]
            guard text.contains("|"),
                  markers.allSatisfy(text.contains) || russianMarkers.allSatisfy(text.contains) else {
                return block
            }
            let firstMarker = text.contains("page 1") ? "page 1" : "страница 1"
            var kept: [ArticleRun] = []
            for var run in runs {
                if let range = run.text.range(of: firstMarker, options: .caseInsensitive) {
                    run.text = String(run.text[..<range.lowerBound])
                    kept.append(run)
                    break
                }
                kept.append(run)
            }
            changed = true
            let prefix = trimmed(kept)
            return prefix.isEmpty ? nil : .paragraph(prefix)
        }
        return (cleaned, changed)
    }

    static func gameNavigation(_ html: String, source: String) -> [GameNavigationSection] {
        guard let sourceURL = URL(string: source) else { return [] }
        let root = tree(html, preserveNestedLists: true)
        let tables = root.descendants("table").compactMap { table -> (String, [ArticleNode])? in
            guard let heading = table.descendants("th").first.map({ runs($0, source: sourceURL).map(\.text).joined() }),
                  !heading.localizedCaseInsensitiveContains("overview") else { return nil }
            let cells = table.descendants("td").filter { !$0.descendants("li").isEmpty }
            return cells.isEmpty ? nil : (heading, cells)
        }
        var sections: [GameNavigationSection] = []
        var title = "General"
        var items: [GameNavigationItem] = []
        var context = ""

        func flush() {
            guard !items.isEmpty else { return }
            sections.append(GameNavigationSection(id: sections.count, title: title, items: items))
            items = []
        }

        func text(_ node: ArticleNode) -> String {
            runs(node, source: sourceURL).map(\.text).joined()
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func item(_ node: ArticleNode, id: Int) -> GameNavigationItem? {
            let itemRuns = trimmed(node.children.filter { $0.tag != "ul" && $0.tag != "ol" }
                .flatMap { runs($0, source: sourceURL) })
            var itemTitle = itemRuns.map(\.text).joined()
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !itemTitle.isEmpty else { return nil }
            var links: [GameNavigationLink] = []
            for run in itemRuns {
                guard let url = run.url else { continue }
                if let last = links.indices.last, links[last].url == url {
                    links[last] = GameNavigationLink(title: links[last].title + run.text, url: url)
                } else if !links.contains(where: { $0.url == url }) {
                    links.append(GameNavigationLink(title: run.text, url: url))
                }
            }
            if itemTitle.allSatisfy({ $0 == "?" }), let only = links.first, links.count == 1 {
                itemTitle = only.url.lastPathComponent
                    .replacingOccurrences(of: "-", with: " ").capitalized
                links[0] = GameNavigationLink(title: itemTitle, url: only.url)
            }
            let children = node.children.filter { $0.tag == "ul" || $0.tag == "ol" }
                .flatMap { $0.children.filter { $0.tag == "li" } }
                .enumerated().compactMap { childIndex, child in item(child, id: childIndex) }
            guard !links.isEmpty || !children.isEmpty || itemTitle.localizedCaseInsensitiveCompare("About the Game") == .orderedSame else {
                return nil
            }
            return GameNavigationItem(id: id, title: itemTitle, links: links.map {
                GameNavigationLink(title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines), url: $0.url)
            }, children: children)
        }

        func visit(_ node: ArticleNode, inList: Bool = false) {
            if node.tag == "li" {
                if let found = item(node, id: items.count) { items.append(found) }
                return
            }
            if node.tag == "img", !inList,
               let label = node.attributes["alt"]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !label.isEmpty, ["Birthright - Hoshido", "Conquest - Nohr", "Revelation", "All Routes"].contains(label) {
                flush()
                context = label
                title = label
                return
            }
            if !inList, node.tag == "u" || (node.tag == "span" &&
               node.attributes["style"]?.lowercased().contains("text-decoration: underline") == true) {
                let heading = text(node)
                if !heading.isEmpty {
                    flush()
                    title = context.isEmpty ? heading : "\(context) · \(heading)"
                }
                return
            }
            for child in node.children { visit(child, inList: inList || node.tag == "ul" || node.tag == "ol") }
        }

        for (tableHeading, cells) in tables {
            for cell in cells {
                flush()
                title = tableHeading.localizedCaseInsensitiveContains("guides and information") ? "General" : tableHeading
                context = ""
                visit(cell)
            }
        }
        flush()
        return sections
    }

}
