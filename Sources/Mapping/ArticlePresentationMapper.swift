import Foundation

private enum Constants {
    static let characters = ["character", "unit", "hero"]
    static let classes = ["class", "skill"]
    static let inventory = ["weapon", "item", "shop"]
    static let chapters = ["chapter", "map"]
    static let supports = ["support", "conversation"]
    static let stories = ["script", "story"]
    static let charactersSymbol = "person.2.fill"
    static let classesSymbol = "shield.lefthalf.filled"
    static let inventorySymbol = "bag.fill"
    static let chaptersSymbol = "map.fill"
    static let supportsSymbol = "bubble.left.and.bubble.right.fill"
    static let storiesSymbol = "text.book.closed.fill"
    static let fallbackSymbol = "bookmark.fill"
}

enum ArticlePresentationMapper {
    static func map(_ blocks: [ArticleBlock]) -> [ArticlePresentationBlock] {
        blocks.map { block in
            switch block {
            case .heading(let level, let runs):
                .heading(ArticleHeadingPresentation(level: level, runs: runs, symbol: headingSymbol(runs)))
            case .paragraph(let runs): .paragraph(runs)
            case .list(let ordered, let items): .list(ordered, items)
            case .image(let url, let alt): .image(url, alt)
            case .table(let rows): .table(table(rows))
            case .fatesClasses(let guide): .fatesClasses(guide)
            case .classScheme(let scheme): .classScheme(scheme)
            case .tabs(let tabs): .tabs(tabs.map { ArticleTabPresentation(title: $0.title, blocks: map($0.blocks)) })
            case .quote(let runs): .quote(runs)
            case .rule: .rule
            }
        }
    }

    private static func headingSymbol(_ runs: [ArticleRun]) -> String {
        let title = runs.map(\.text).joined().lowercased()
        if Constants.characters.contains(where: title.contains) { return Constants.charactersSymbol }
        if Constants.classes.contains(where: title.contains) { return Constants.classesSymbol }
        if Constants.inventory.contains(where: title.contains) { return Constants.inventorySymbol }
        if Constants.chapters.contains(where: title.contains) { return Constants.chaptersSymbol }
        if Constants.supports.contains(where: title.contains) { return Constants.supportsSymbol }
        if Constants.stories.contains(where: title.contains) { return Constants.storiesSymbol }
        return Constants.fallbackSymbol
    }

    private static func tableKind(_ rows: [[ArticleCell]]) -> ArticleTableKind {
        guard rows.count > 1, rows[0].count == 3,
              rows[0][0].header, rows[0][2].header,
              rows[0][1].runs.isEmpty,
              rows.dropFirst().contains(where: { $0.count == 3 && !$0[1].imageURLs.isEmpty })
        else { return .standard }
        return .classProgression
    }

    private static func table(_ sourceRows: [[ArticleCell]]) -> ArticleTablePresentation {
        let kind = tableKind(sourceRows)
        let rows = normalizedRows(sourceRows)
        let progression: ArticleClassProgression?
        if kind == .classProgression, let titles = rows.first, titles.count == 3 {
            let pairs = rows.dropFirst().compactMap { row -> ArticleClassPair? in
                guard row.count == 3 else { return nil }
                let base = row[0].runs.isEmpty && row[0].imageURLs.isEmpty ? nil : row[0]
                let promoted = row[2].runs.isEmpty && row[2].imageURLs.isEmpty ? nil : row[2]
                return ArticleClassPair(base: base, promoted: promoted,
                                        showsArrow: !row[0].runs.isEmpty && !row[2].runs.isEmpty)
            }
            progression = ArticleClassProgression(baseTitle: titles[0].runs.map(\.text).joined(),
                                                  promotedTitle: titles[2].runs.map(\.text).joined(), pairs: pairs)
        } else {
            progression = nil
        }
        return ArticleTablePresentation(rows: rows, kind: kind, progression: progression)
    }

    // Older cached rows may repeat rowspan content. Keep the first occurrence only.
    private static func normalizedRows(_ rows: [[ArticleCell]]) -> [[ArticleCell]] {
        var remaining: [Int: Int] = [:]
        let normalized = rows.map { sourceRow in
            var next = remaining.compactMapValues { $0 > 1 ? $0 - 1 : nil }
            var column = 0
            let result = sourceRow.map { sourceCell -> ArticleCell in
                var cell = sourceCell
                if remaining[column] != nil {
                    cell.runs = []
                    cell.imageURLs = []
                }
                if sourceCell.rowSpan > 1 { next[column] = sourceCell.rowSpan - 1 }
                column += sourceCell.span
                return cell
            }
            remaining = next
            return result
        }
        let nonempty = normalized.filter { row in
            row.contains { !$0.runs.isEmpty || !$0.imageURLs.isEmpty }
        }
        return nonempty.isEmpty ? Array(normalized.prefix(1)) : nonempty
    }
}
