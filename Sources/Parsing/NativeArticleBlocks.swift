import Foundation

private enum Constants {
    static let baseClass = "Base class"
    static let promotedClass = "Promoted class"
}

extension NativeArticleParser {
    static func appendBlocks(from node: ArticleNode, source: URL, to blocks: inout [ArticleBlock]) {
        if ["script", "style", "noscript", "svg", "nav"].contains(node.tag) { return }
        if node.attributes["class"]?.split(separator: " ").contains("wiki-tabs") == true {
            let tabs = node.children.filter { $0.attributes["class"]?.split(separator: " ").contains("wiki-tab") == true }
                .compactMap { panel -> ArticleTab? in
                    var content: [ArticleBlock] = []
                    appendBlocks(from: panel, source: source, to: &content)
                    guard !content.isEmpty else { return nil }
                    return ArticleTab(title: panel.attributes["data-title"] ?? "", blocks: content)
                }
            if tabs.count > 1 {
                blocks.append(.tabs(tabs))
            } else if let tab = tabs.first {
                if !tab.title.isEmpty {
                    blocks.append(.heading(4, [ArticleRun(text: tab.title, url: nil)]))
                }
                blocks.append(contentsOf: tab.blocks)
            }
            return
        }
        if let heading = Int(node.tag.dropFirst()), node.tag.first == "h", (1...6).contains(heading) {
            let text = trimmed(runs(node, source: source))
            if !text.isEmpty { blocks.append(.heading(heading, text)) }
            appendContainedImages(from: node, source: source, to: &blocks)
            return
        }
        switch node.tag {
        case "table":
            if let classes = ClassesParserFactory.parse(node, source: source) {
                blocks.append(classes)
                return
            }
            if let nested = sideBySideTables(node) {
                for table in nested { appendBlocks(from: table, source: source, to: &blocks) }
                return
            }
            let rows = tableRows(node, source: source)
            if !rows.isEmpty { blocks.append(.table(expandedRows(rows))) }
            var included: [URL: Int] = [:]
            for url in rows.flatMap({ $0 }).flatMap(\.imageURLs) { included[url, default: 0] += 1 }
            for image in node.descendants("img") {
                guard let url = imageURL(image, source: source) else { continue }
                if included[url, default: 0] > 0 { included[url, default: 0] -= 1 }
                else { blocks.append(.image(url, image.attributes["alt"] ?? "")) }
            }
            return
        case "ul", "ol":
            let items = node.children.filter { $0.tag == "li" }.map { trimmed(runs($0, source: source)) }.filter { !$0.isEmpty }
            if !items.isEmpty { blocks.append(.list(node.tag == "ol", items)) }
            appendContainedImages(from: node, source: source, to: &blocks)
            return
        case "blockquote":
            let text = trimmed(runs(node, source: source))
            if !text.isEmpty { blocks.append(.quote(text)) }
            appendContainedImages(from: node, source: source, to: &blocks)
            return
        case "hr": blocks.append(.rule); return
        case "img":
            if let url = imageURL(node, source: source) {
                blocks.append(.image(url, node.attributes["alt"] ?? ""))
            }
            return
        default: break
        }

        var pending: [ArticleNode] = []
        func flush() {
            let text = trimmed(pending.flatMap { runs($0, source: source) })
            if !text.isEmpty { blocks.append(.paragraph(text)) }
            pending.removeAll()
        }
        for child in node.children {
            if blockTags.contains(child.tag) || child.tag == "img" || !child.descendants("img").isEmpty {
                flush()
                appendBlocks(from: child, source: source, to: &blocks)
            } else {
                pending.append(child)
            }
        }
        flush()
    }

    static func appendContainedImages(from node: ArticleNode, source: URL, to blocks: inout [ArticleBlock]) {
        for image in node.descendants("img") {
            if let url = imageURL(image, source: source) {
                blocks.append(.image(url, image.attributes["alt"] ?? ""))
            }
        }
    }

    static func tableRows(_ table: ArticleNode, source: URL) -> [[ArticleCell]] {
        if let progression = progressionRows(table, source: source) { return progression }
        func cell(_ node: ArticleNode) -> ArticleCell {
            ArticleCell(runs: trimmed(runs(node, source: source)), imageURLs: node.descendants("img").compactMap { imageURL($0, source: source) }, header: node.tag == "th", span: min(max(Int(node.attributes["colspan"] ?? "1") ?? 1, 1), 30), rowSpan: min(max(Int(node.attributes["rowspan"] ?? "1") ?? 1, 1), 100))
        }
        var rows: [[ArticleCell]] = []
        var orphanCells: [ArticleCell] = []
        var columnCount = 4
        func flushOrphans() {
            var row: [ArticleCell] = []
            var columns = 0
            for item in orphanCells {
                if columns > 0 && columns + item.span > columnCount {
                    rows.append(row)
                    row = []
                    columns = 0
                }
                row.append(item)
                columns += item.span
                if columns >= columnCount {
                    rows.append(row)
                    row = []
                    columns = 0
                }
            }
            if !row.isEmpty { rows.append(row) }
            orphanCells.removeAll()
        }
        func visit(_ node: ArticleNode) {
            for child in node.children {
                if child.tag == "tr" {
                    flushOrphans()
                    let row = child.children.filter { ["td", "th"].contains($0.tag) }.map(cell)
                    if !row.isEmpty {
                        rows.append(row)
                        columnCount = max(row.reduce(0) { $0 + $1.span }, 1)
                    }
                } else if ["td", "th"].contains(child.tag) {
                    orphanCells.append(cell(child))
                } else if child.tag != "table" {
                    visit(child)
                }
            }
        }
        visit(table)
        flushOrphans()
        return rows
    }

    private static func sideBySideTables(_ table: ArticleNode) -> [ArticleNode]? {
        let rows = table.children.flatMap { $0.tag == "tbody" ? $0.children : [$0] }
            .filter { $0.tag == "tr" }
        guard rows.count == 1 else { return nil }
        let columns = rows[0].children.filter { $0.tag == "td" || $0.tag == "th" }
        guard columns.count == 2 else { return nil }
        let nested = columns.compactMap { $0.descendants("table").first }
        return nested.count == 2 ? nested : nil
    }

    // Class guides place two real tables inside a three-column layout table.
    // Keep corresponding base and promoted classes on the same row.
    private static func progressionRows(_ table: ArticleNode, source: URL) -> [[ArticleCell]]? {
        let outerRows = table.children.flatMap { $0.tag == "tbody" ? $0.children : [$0] }
            .filter { $0.tag == "tr" }
        guard outerRows.count == 1 else { return nil }
        let columns = outerRows[0].children.filter { $0.tag == "td" || $0.tag == "th" }
        guard columns.count == 3,
              let baseTable = columns[0].descendants("table").first,
              let promotedTable = columns[2].descendants("table").first,
              columns[1].descendants("table").isEmpty else { return nil }

        let base = tableRows(baseTable, source: source)
        let promoted = tableRows(promotedTable, source: source)
        guard !base.isEmpty, !promoted.isEmpty else { return nil }
        let arrows = columns[1].descendants("img").compactMap { imageURL($0, source: source) }
        func combined(_ cells: [ArticleCell]?) -> ArticleCell {
            ArticleCell(runs: cells?.flatMap(\.runs) ?? [],
                        imageURLs: cells?.flatMap(\.imageURLs) ?? [],
                        header: cells?.allSatisfy(\.header) ?? false,
                        span: 1, rowSpan: 1)
        }
        let baseHasHeader = base[0].allSatisfy(\.header)
        let promotedHasHeader = promoted[0].allSatisfy(\.header)
        let baseClasses = Array(base.dropFirst(baseHasHeader ? 1 : 0))
        let promotedClasses = Array(promoted.dropFirst(promotedHasHeader ? 1 : 0))
        func header(_ title: String, from cells: [ArticleCell]?) -> ArticleCell {
            let original = combined(cells)
            return ArticleCell(runs: original.runs.isEmpty ? [ArticleRun(text: title, url: nil)] : original.runs,
                               imageURLs: [], header: true, span: 1, rowSpan: 1)
        }
        let headings = [header(Constants.baseClass, from: baseHasHeader ? base[0] : nil),
                        ArticleCell(runs: [], imageURLs: [], header: true, span: 1, rowSpan: 1),
                        header(Constants.promotedClass, from: promotedHasHeader ? promoted[0] : nil)]
        let classRows = (0..<max(baseClasses.count, promotedClasses.count)).map { index in
            let arrow = index < arrows.count ? [arrows[index]] : []
            return [combined(baseClasses.indices.contains(index) ? baseClasses[index] : nil),
                    ArticleCell(runs: [], imageURLs: arrow, header: false, span: 1, rowSpan: 1),
                    combined(promotedClasses.indices.contains(index) ? promotedClasses[index] : nil)]
        }
        return [headings] + classRows
    }

    // Preserve the space covered by a rowspan without repeating its text or image.
    static func expandedRows(_ rows: [[ArticleCell]]) -> [[ArticleCell]] {
        var carrying: [Int: (cell: ArticleCell, remaining: Int)] = [:]
        var result: [[ArticleCell]] = []
        for sourceRow in rows {
            var next: [Int: (cell: ArticleCell, remaining: Int)] = [:]
            var row: [ArticleCell] = []
            var column = 0
            func appendCarriedCell() -> Bool {
                guard let carried = carrying[column] else { return false }
                row.append(ArticleCell(runs: [], imageURLs: [], header: false,
                                       span: carried.cell.span, rowSpan: 1))
                if carried.remaining > 1 { next[column] = (carried.cell, carried.remaining - 1) }
                column += carried.cell.span
                return true
            }
            for cell in sourceRow {
                while appendCarriedCell() {}
                row.append(cell)
                if cell.rowSpan > 1 { next[column] = (cell, cell.rowSpan - 1) }
                column += cell.span
            }
            while let last = carrying.keys.max(), column <= last {
                if !appendCarriedCell() {
                    row.append(ArticleCell(runs: [], imageURLs: [], header: false, span: 1, rowSpan: 1))
                    column += 1
                }
            }
            result.append(row)
            carrying = next
        }
        return result
    }
}
