import Foundation

private enum Constants {
    static let introductionPath = "the-sacred-stones/classes/introduction"
    static let traineesPath = "the-sacred-stones/classes/introduction/trainees"
    static let superTraineesPath = "the-sacred-stones/miscellaneous/super-trainees"
    static let path = "Path"
    static let upgrade = "Upgrade item"
    static let className = "Class"
    static let dash = "–"
}

enum SacredStonesClassSchemeParser {
    private struct PlacedCell {
        let node: ArticleNode
        let column: Int
        let start: Int
        let end: Int

    }

    static func accepts(_ source: URL) -> Bool {
        let path = source.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return [Constants.introductionPath, Constants.traineesPath, Constants.superTraineesPath].contains(path)
    }

    static func parse(_ table: ArticleNode, source: URL) -> ClassScheme? {
        guard accepts(source) else { return nil }
        let rows = table.children.flatMap { $0.tag == "tbody" ? $0.children : [$0] }
            .filter { $0.tag == "tr" }
        guard !rows.isEmpty else { return nil }
        let headers = rows[0].children.filter { $0.tag == "th" }
        let isSuperTrainees = source.path.contains(Constants.superTraineesPath)
        let stageColumns: [Int]
        let stageTitles: [String]
        let upgradeColumn: Int?
        let dataRows: [ArticleNode]
        if isSuperTrainees {
            guard rows.count == 1, rows[0].children.filter({ $0.tag == "td" }).count == 5 else { return nil }
            stageColumns = [0, 2, 4]
            stageTitles = ["", "", ""]
            upgradeColumn = nil
            dataRows = rows
        } else {
            guard headers.count >= 4 else { return nil }
            let titles = headers.map { text($0, source: source) }
            guard titles.contains(where: { $0.caseInsensitiveCompare(Constants.path) == .orderedSame }) else { return nil }
            stageColumns = titles.indices.filter { titles[$0].localizedCaseInsensitiveContains(Constants.className) }
            guard (2...3).contains(stageColumns.count) else { return nil }
            stageTitles = stageColumns.map { titles[$0] }
            upgradeColumn = titles.firstIndex { $0.localizedCaseInsensitiveContains(Constants.upgrade) }
            dataRows = Array(rows.dropFirst())
        }
        let placed = place(dataRows)
        let stages = stageColumns.map { column in
            placed.filter { $0.column == column && entry($0.node, source: source) != nil }
        }
        guard stages.count >= 2, !stages[0].isEmpty, !stages[1].isEmpty else { return nil }
        let upgrades = upgradeColumn.map { column in placed.filter { $0.column == column } } ?? []
        func branch(_ cell: PlacedCell, stage: Int, start: Int, end: Int) -> ClassSchemeBranch {
            let item = entry(cell.node, source: source)!
            let children = stage + 1 < stages.count
                ? stages[stage + 1].filter { $0.start < end && start < $0.end }.map {
                    branch($0, stage: stage + 1, start: max(start, $0.start), end: min(end, $0.end))
                }
                : []
            let upgrade = children.isEmpty ? upgrades.first(where: { $0.start < end && start < $0.end }).flatMap {
                parsedUpgrade($0.node, source: source)
            } : nil
            return ClassSchemeBranch(entry: item, upgrade: upgrade, children: children)
        }
        return ClassScheme(stageTitles: stageTitles,
                           roots: stages[0].map { branch($0, stage: 0, start: $0.start, end: $0.end) },
                           consumedImageURLs: table.descendants("img").compactMap {
                               NativeArticleParser.imageURL($0, source: source)
                           })
    }

    private static func place(_ rows: [ArticleNode]) -> [PlacedCell] {
        var occupiedUntil: [Int: Int] = [:]
        var result: [PlacedCell] = []
        for (rowIndex, row) in rows.enumerated() {
            var column = 0
            for cell in row.children where cell.tag == "td" || cell.tag == "th" {
                while occupiedUntil[column, default: 0] > rowIndex { column += 1 }
                let width = max(Int(cell.attributes["colspan"] ?? "1") ?? 1, 1)
                let height = max(Int(cell.attributes["rowspan"] ?? "1") ?? 1, 1)
                result.append(PlacedCell(node: cell, column: column, start: rowIndex, end: rowIndex + height))
                for offset in 0..<width { occupiedUntil[column + offset] = rowIndex + height }
                column += width
            }
        }
        return result
    }

    private static func text(_ node: ArticleNode, source: URL) -> String {
        NativeArticleParser.trimmed(NativeArticleParser.runs(node, source: source))
            .map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func entry(_ node: ArticleNode, source: URL) -> FatesClassEntry? {
        let runs = NativeArticleParser.trimmed(NativeArticleParser.runs(node, source: source))
        let name = runs.map(\.text).joined().components(separatedBy: .newlines).first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty, name != Constants.dash else { return nil }
        let images = node.descendants("img").compactMap { NativeArticleParser.imageURL($0, source: source) }
        return FatesClassEntry(name: name, runs: runs, artworkURL: images.first,
                               iconURLs: Array(images.dropFirst()))
    }

    private static func parsedUpgrade(_ node: ArticleNode, source: URL) -> ClassSchemeUpgrade? {
        let runs = NativeArticleParser.trimmed(NativeArticleParser.runs(node, source: source))
        let images = node.descendants("img").compactMap { NativeArticleParser.imageURL($0, source: source) }
        return runs.isEmpty && images.isEmpty ? nil : ClassSchemeUpgrade(runs: runs, imageURLs: images)
    }
}
