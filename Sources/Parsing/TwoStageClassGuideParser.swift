import Foundation

private enum Constants {
    static let baseClass = "Base class"
    static let promotedClass = "Promoted class"
    static let spacer = "spacer"
    static let space = "space"
}

enum TwoStageClassGuideParser {
    static func parse(_ node: ArticleNode, source: URL,
                      relationships: [String: [String]]) -> FatesClassGuide? {
        guard let columns = layoutColumns(in: node),
              let baseTable = columns[0].descendants("table").first,
              let promotedTable = columns[2].descendants("table").first else { return nil }
        let bases = classes(in: baseTable, source: source)
        let promoted = classes(in: promotedTable, source: source)
        guard !bases.isEmpty, !promoted.isEmpty else { return nil }
        let byName = Dictionary(promoted.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        var used = Set<String>()
        let groups = bases.map { entry in
            let targets = (relationships[entry.name] ?? []).compactMap { name -> FatesClassEntry? in
                guard let target = byName[name] else { return nil }
                used.insert(name)
                return target
            }
            return FatesClassGroup(base: entry, promotions: targets)
        }
        return FatesClassGuide(
            baseTitle: heading(in: baseTable, source: source, fallback: Constants.baseClass),
            promotedTitle: heading(in: promotedTable, source: source, fallback: Constants.promotedClass),
            groups: groups,
            unassignedPromotions: promoted.filter { !used.contains($0.name) },
            consumedImageURLs: node.descendants("img").compactMap { NativeArticleParser.imageURL($0, source: source) }
        )
    }

    private static func layoutColumns(in table: ArticleNode) -> [ArticleNode]? {
        let rows = table.children.flatMap { $0.tag == "tbody" ? $0.children : [$0] }
            .filter { $0.tag == "tr" }
        guard rows.count == 1 else { return nil }
        let columns = rows[0].children.filter { $0.tag == "td" || $0.tag == "th" }
        guard columns.count == 3, columns[1].descendants("table").isEmpty else { return nil }
        return columns
    }

    private static func heading(in table: ArticleNode, source: URL, fallback: String) -> [ArticleRun] {
        guard let header = table.descendants("th").first else {
            return [ArticleRun(text: fallback, url: nil)]
        }
        let runs = NativeArticleParser.trimmed(NativeArticleParser.runs(header, source: source))
        return runs.isEmpty ? [ArticleRun(text: fallback, url: nil)] : runs
    }

    private static func classes(in table: ArticleNode, source: URL) -> [FatesClassEntry] {
        table.descendants("tr").compactMap { row in
            let cells = row.children.filter { $0.tag == "td" }
            guard cells.count >= 2, let details = cells.last,
                  let strong = details.descendants("strong").first else { return nil }
            let name = NativeArticleParser.trimmed(NativeArticleParser.runs(strong, source: source))
                .map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let artwork = cells[0].descendants("img")
                .compactMap { NativeArticleParser.imageURL($0, source: source) }
                .first { url in
                    let filename = url.lastPathComponent.lowercased()
                    return !filename.hasPrefix(Constants.spacer) && !filename.hasPrefix(Constants.space)
                }
            return FatesClassEntry(name: name,
                                   runs: NativeArticleParser.trimmed(NativeArticleParser.runs(details, source: source)),
                                   artworkURL: artwork,
                                   iconURLs: details.descendants("img").compactMap {
                                       NativeArticleParser.imageURL($0, source: source)
                                   })
        }
    }
}
