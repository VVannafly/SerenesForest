import SerenesParsing
import SwiftUI

private enum Constants {
    static var otherPromotedClasses: String { AppText.localized("Other promoted classes") }
    static let promotionSymbol = "arrow.down"
    static let artworkSize: CGFloat = 68
}

struct FatesClassesView: View {
    let viewModel: FatesClassesViewModel
    let onLink: (URL) -> Void

    init(guide: FatesClassGuide, assets: [String: Date], onLink: @escaping (URL) -> Void) {
        viewModel = FatesClassesViewModel(guide: guide, assets: assets)
        self.onLink = onLink
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 460), spacing: 12)], spacing: 12) {
            ForEach(viewModel.guide.groups.indices, id: \.self) { index in
                group(viewModel.guide.groups[index])
            }
            if !viewModel.guide.unassignedPromotions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(Constants.otherPromotedClasses).font(.headline)
                    ForEach(viewModel.guide.unassignedPromotions, id: \.name) { entry in
                        entryView(entry)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func group(_ group: FatesClassGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.baseTitle)
                .font(.caption.bold()).foregroundStyle(.secondary)
            entryView(group.base)
            if !group.promotions.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: Constants.promotionSymbol)
                    Text(viewModel.promotedTitle)
                }
                .font(.caption.bold())
                .foregroundStyle(.tint)
                .padding(.top, 2)
                ForEach(group.promotions, id: \.name) { entry in
                    entryView(entry)
                        .padding(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func entryView(_ entry: FatesClassEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let artworkURL = entry.artworkURL {
                let canonical = viewModel.assetKey(for: artworkURL)
                ArticleImageView(url: artworkURL, assetURL: canonical, alt: entry.name,
                                 compact: false, fetchedAt: viewModel.fetchedAt(for: artworkURL), onLink: onLink,
                                 thumbnailSize: Constants.artworkSize)
            }
            VStack(alignment: .leading, spacing: 6) {
                TableCellText(runs: entry.runs, bold: false)
                    .equatable()
                if !entry.iconURLs.isEmpty {
                    TableCellImages(urls: entry.iconURLs, assets: viewModel.assets, onLink: onLink)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
