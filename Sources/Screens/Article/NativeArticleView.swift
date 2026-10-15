import SerenesParsing
import Foundation
import SwiftUI

private enum Constants {
    static func tab(_ number: Int) -> String { AppText.localized( "Tab \(number)") }
    static var articleSection: String { AppText.localized( "Article section") }
    static let promotionArrow = "arrow.down"
}

struct NativeArticleView: View {
    let blocks: [ArticlePresentationBlock]
    let assets: [String: Date]
    let onLink: (URL) -> Void
    var embedded = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedTabs: [Int: Int] = [:]

    var body: some View {
        Group {
            if embedded {
                content
            } else {
                ScrollView {
                    content
                        .frame(maxWidth: 1000, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .environment(\.openURL, OpenURLAction { url in onLink(url); return .handled })
    }

    private var content: some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            ForEach(blocks.indices, id: \.self) { index in
                blockView(blocks[index], index: index)
            }
        }
    }

    @ViewBuilder private func blockView(_ block: ArticlePresentationBlock, index: Int) -> some View {
        switch block {
        case .heading(let heading):
            if heading.level <= 2 {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: heading.symbol)
                        .font(.headline)
                        .foregroundStyle(.tint)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    Text(attributed(heading.runs))
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                }
                .padding(.top, 8)
            } else {
                Text(attributed(heading.runs))
                    .font(heading.level == 3 ? .title3.bold() : .headline)
                    .foregroundStyle(.primary)
                    .padding(.top, 8)
            }
        case .paragraph(let runs):
            Text(attributed(runs)).font(.body).lineSpacing(4).textSelection(.enabled)
        case .quote(let runs):
            Text(attributed(runs)).font(.body).italic()
                .padding(.leading, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) { Rectangle().fill(.tint).frame(width: 3) }
        case .list(let ordered, let items):
            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(ordered ? "\(index + 1)." : "•").foregroundStyle(.tint).frame(width: 24, alignment: .trailing)
                        Text(attributed(item)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        case .image(let url, let alt):
            articleImage(url, alt: alt)
        case .table(let table):
            articleTable(table)
        case .tabs(let tabs):
            if !tabs.isEmpty {
                let selected = min(selectedTabs[index] ?? 0, tabs.count - 1)
                VStack(alignment: .leading, spacing: 14) {
                    Picker(Constants.articleSection, selection: Binding(
                        get: { selectedTabs[index] ?? 0 },
                        set: { selectedTabs[index] = $0 }
                    )) {
                        ForEach(tabs.indices, id: \.self) { tabIndex in
                            Text(tabs[tabIndex].title.isEmpty ? Constants.tab(tabIndex + 1) : tabs[tabIndex].title)
                                .tag(tabIndex)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    NativeArticleView(blocks: tabs[selected].blocks, assets: assets,
                                      onLink: onLink, embedded: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        case .rule:
            Divider()
        }
    }

    private func attributed(_ runs: [ArticleRun]) -> AttributedString {
        var result = AttributedString()
        for run in runs {
            var piece = AttributedString(run.text)
            if let url = run.url { piece.link = url; piece.foregroundColor = .accentColor }
            if run.strong { piece.font = .body.bold() }
            if run.italic { piece.font = .body.italic() }
            result += piece
        }
        return result
    }

    private func articleImage(_ url: URL, alt: String, compact: Bool = false) -> some View {
        let canonical = SiteScope.canonical(url)?.absoluteString ?? url.absoluteString
        return ArticleImageView(url: url, assetURL: canonical, alt: alt, compact: compact,
                                fetchedAt: assets[canonical], onLink: onLink)
    }

    @ViewBuilder private func articleTable(_ table: ArticleTablePresentation) -> some View {
        if sizeClass == .compact, let progression = table.progression {
            ClassProgressionArticleView(progression: progression, assets: assets, onLink: onLink)
        } else {
            FrozenArticleTable(rows: table.rows, kind: table.kind, assets: assets, onLink: onLink)
        }
    }
}

private struct ClassProgressionArticleView: View {
    let progression: ArticleClassProgression
    let assets: [String: Date]
    let onLink: (URL) -> Void

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(progression.pairs.enumerated()), id: \.offset) { _, pair in
                VStack(alignment: .leading, spacing: 10) {
                    if let base = pair.base {
                        classInfo(base, title: progression.baseTitle)
                    }
                    if pair.showsArrow {
                        Image(systemName: Constants.promotionArrow)
                            .foregroundStyle(.tint)
                            .frame(maxWidth: .infinity)
                    }
                    if let promoted = pair.promoted {
                        classInfo(promoted, title: progression.promotedTitle)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func classInfo(_ cell: ArticleCell, title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.bold()).foregroundStyle(.secondary)
            if !cell.imageURLs.isEmpty {
                TableCellImages(urls: cell.imageURLs, assets: assets, onLink: onLink)
            }
            if !cell.runs.isEmpty {
                TableCellText(runs: cell.runs, bold: false)
                    .equatable()
            }
        }
    }
}
