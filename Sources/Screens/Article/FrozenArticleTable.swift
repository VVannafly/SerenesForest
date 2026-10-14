import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct TableRowsKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct FrozenArticleTable: View {
    let rows: [[ArticleCell]]
    let kind: ArticleTableKind
    let assets: [String: Date]
    let onLink: (URL) -> Void
    private let naturalColumnWidths: [CGFloat]
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var horizontalOffset: CGFloat = 0
    @State private var headerHeight: CGFloat = 42
    @State private var headerY: CGFloat = 0

    init(rows: [[ArticleCell]], kind: ArticleTableKind, assets: [String: Date], onLink: @escaping (URL) -> Void) {
        self.rows = rows
        self.kind = kind
        self.assets = assets
        self.onLink = onLink
        self.naturalColumnWidths = Self.measureColumns(in: self.rows)
    }

    private var count: Int { max(rows.map { $0.reduce(0) { $0 + $1.span } }.max() ?? 1, 1) }
    private var isClassProgression: Bool { kind == .classProgression }
    private var columnWidths: [CGFloat] {
        if isClassProgression {
            return sizeClass == .compact ? [240, 44, 260] : [300, 52, 340]
        }
        return naturalColumnWidths.enumerated().map { index, width in
            min(width, index == 0
                ? (sizeClass == .compact ? 180 : 260)
                : (sizeClass == .compact ? 240 : 340))
        }
    }
    private var firstColumnWidth: CGFloat { columnWidths[0] }
    private var tableWidth: CGFloat { columnWidths.reduce(0, +) }
    private var isLong: Bool { rows.count > 24 }
    private var headerRowIndex: Int {
        rows.count > 1 && rows[0].count == 1 && rows[0][0].span >= count ? 1 : 0
    }

    private static func measureColumns(in rows: [[ArticleCell]]) -> [CGFloat] {
        #if os(iOS)
        let regularFont = UIFont.preferredFont(forTextStyle: .caption1)
        let boldFont = UIFont.boldSystemFont(ofSize: regularFont.pointSize)
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        let strongFont = UIFont.boldSystemFont(ofSize: bodyFont.pointSize)
        let italicFont = UIFont.italicSystemFont(ofSize: bodyFont.pointSize)
        #else
        let regularFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let boldFont = NSFont.boldSystemFont(ofSize: regularFont.pointSize)
        let bodyFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let strongFont = NSFont.boldSystemFont(ofSize: bodyFont.pointSize)
        let italicFont = NSFont.systemFont(ofSize: bodyFont.pointSize, weight: .regular)
        #endif
        let count = max(rows.map { $0.reduce(0) { $0 + $1.span } }.max() ?? 1, 1)
        var widths = Array(repeating: CGFloat(64), count: count)
        widths[0] = 72
        func contentWidth(_ cell: ArticleCell, rowIndex: Int) -> CGFloat {
            let textWidth = cell.runs.reduce(CGFloat.zero) { width, run in
                let font = run.italic ? italicFont :
                    run.strong ? strongFont :
                    (cell.header || rowIndex == 0 ? boldFont : regularFont)
                return width + (run.text as NSString).size(withAttributes: [.font: font]).width
            }
            let imageCount = min(cell.imageURLs.count, 3)
            let imagesWidth = CGFloat(imageCount * 28 + max(imageCount - 1, 0) * 4)
            let overflowWidth: CGFloat = cell.imageURLs.count > 3 ? 34 : 0
            let gap: CGFloat = !cell.runs.isEmpty && imageCount > 0 ? 5 : 0
            return ceil(textWidth + imagesWidth + overflowWidth + gap + 20)
        }
        for (index, row) in rows.enumerated() {
            var logicalColumn = 0
            for cell in row {
                if cell.span == 1, logicalColumn < count {
                    widths[logicalColumn] = max(widths[logicalColumn], contentWidth(cell, rowIndex: index))
                }
                logicalColumn += cell.span
            }
        }
        return widths
    }

    private func width(startingAt column: Int, spanning span: Int) -> CGFloat {
        columnWidths[column..<min(column + span, count)].reduce(0, +)
    }

    var body: some View {
        ScrollView(isLong ? [.horizontal, .vertical] : .horizontal) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(rows.indices, id: \.self) { index in
                    tableRow(rows[index], index: index)
                        .background(GeometryReader { geometry in
                            Color.clear.preference(key: TableRowsKey.self,
                                value: [index: geometry.frame(in: .named("articleTable"))])
                        })
                }
            }
            .frame(width: tableWidth, alignment: .leading)
        }
        .coordinateSpace(name: "articleTable")
        .onPreferenceChange(TableRowsKey.self) { frames in
            if let x = frames.values.first?.minX, abs(x - horizontalOffset) > 0.5 {
                horizontalOffset = x
            }
            if let header = frames[headerRowIndex] {
                if abs(header.height - headerHeight) > 0.5 { headerHeight = header.height }
                let y = max(header.minY, 0)
                if abs(y - headerY) > 0.5 { headerY = y }
            }
        }
        .overlay(alignment: .topLeading) {
            if isLong, rows.indices.contains(headerRowIndex) {
                tableRow(rows[headerRowIndex], index: headerRowIndex)
                    .frame(width: tableWidth, alignment: .leading)
                    .background(Color.accentColor.opacity(0.15))
                    .background(.background)
                    .offset(x: horizontalOffset)
                    .offset(y: headerY)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topLeading) {
            if isLong, rows.indices.contains(headerRowIndex),
               let corner = rows[headerRowIndex].first, corner.span == 1 {
                tableCell(corner, rowIndex: headerRowIndex)
                    .frame(width: firstColumnWidth, height: headerHeight, alignment: .topLeading)
                    .background(Color.accentColor.opacity(0.15))
                    .background(.background)
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 1)
                    }
                    .offset(y: headerY)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: isLong ? 500 : nil)
        .scrollIndicators(.visible)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(0.12)) }
    }

    private func tableRow(_ row: [ArticleCell], index: Int) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(row.indices, id: \.self) { column in
                // Keep the original cell in the layout so its text determines the row height.
                let conceal = column == 0 && row[column].span == 1
                let logicalColumn = row[..<column].reduce(0) { $0 + $1.span }
                tableCell(row[column], rowIndex: index, loadsImages: !conceal)
                    .frame(width: width(startingAt: logicalColumn, spanning: row[column].span), alignment: .topLeading)
                    .opacity(conceal ? 0 : 1)
                    .allowsHitTesting(!conceal)
            }
            let remaining = count - row.reduce(0) { $0 + $1.span }
            if remaining > 0 {
                Color.clear.frame(width: width(startingAt: count - remaining, spanning: remaining), height: 1)
            }
        }
        .background(index == 0 ? Color.accentColor.opacity(0.15) :
                    index.isMultiple(of: 2) ? Color.primary.opacity(0.035) : Color.clear)
        .overlay(alignment: .topLeading) {
            GeometryReader { geometry in
                ForEach(columnBoundaries(in: row), id: \.self) { offset in
                    Rectangle().fill(Color.primary.opacity(0.12))
                        .frame(width: 1, height: geometry.size.height)
                        .offset(x: offset - 0.5)
                }
            }
            .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.primary.opacity(0.10)).frame(height: 1)
        }
        .overlay(alignment: .topLeading) {
            if (!isLong || index != headerRowIndex), let firstCell = row.first, firstCell.span == 1 {
                GeometryReader { geometry in
                    tableCell(firstCell, rowIndex: index)
                        .frame(width: firstColumnWidth, height: geometry.size.height, alignment: .topLeading)
                        .background(index == 0 ? Color.accentColor.opacity(0.15) :
                                    index.isMultiple(of: 2) ? Color.primary.opacity(0.035) : Color.clear)
                        .background(.background)
                        .overlay(alignment: .trailing) {
                            Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 1)
                        }
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Color.primary.opacity(0.10)).frame(height: 1)
                        }
                        .offset(x: -horizontalOffset)
                }
                .allowsHitTesting(false)
            }
        }
    }

    private func columnBoundaries(in row: [ArticleCell]) -> [CGFloat] {
        var column = 0
        return row.dropLast().map { cell in
            column += cell.span
            return width(startingAt: 0, spanning: column)
        }
    }

    private func tableCell(_ cell: ArticleCell, rowIndex: Int, loadsImages: Bool = true) -> some View {
        Group {
            if isClassProgression && rowIndex > 0 && !cell.runs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    if !cell.imageURLs.isEmpty {
                        if loadsImages {
                            TableCellImages(urls: cell.imageURLs, assets: assets, onLink: onLink)
                        } else {
                            Color.clear.frame(width: imagePlaceholderWidth(for: cell.imageURLs.count), height: 28)
                        }
                    }
                    TableCellText(runs: cell.runs, bold: false)
                        .equatable()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(alignment: .center, spacing: 5) {
                    if !cell.imageURLs.isEmpty {
                        if loadsImages {
                            TableCellImages(urls: cell.imageURLs, assets: assets, onLink: onLink)
                        } else {
                            Color.clear.frame(width: imagePlaceholderWidth(for: cell.imageURLs.count), height: 28)
                        }
                    }
                    if !cell.runs.isEmpty {
                        TableCellText(runs: cell.runs, bold: cell.header || rowIndex == 0)
                            .equatable()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
    }

    private func imagePlaceholderWidth(for imageCount: Int) -> CGFloat {
        let visibleCount = min(imageCount, 3)
        let imageWidth = visibleCount * 28
        let spacing = max(visibleCount - 1, 0) * 4
        let overflow = imageCount > 3 ? 34 : 0
        return CGFloat(imageWidth + spacing + overflow)
    }

}
