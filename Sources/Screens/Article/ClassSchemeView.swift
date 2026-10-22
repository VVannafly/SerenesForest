import SwiftUI

private enum Constants {
    static let arrow = "arrow.down"
    static var upgradeItem: String { AppText.localized("Upgrade item") }
    static var otherPromotedClasses: String { AppText.localized("Other promoted classes") }
    static let artworkSize: CGFloat = 58
}

struct ClassSchemeView: View {
    let viewModel: ClassSchemeViewModel
    let onLink: (URL) -> Void

    init(scheme: ClassScheme, assets: [String: Date], onLink: @escaping (URL) -> Void) {
        viewModel = ClassSchemeViewModel(scheme: scheme, assets: assets)
        self.onLink = onLink
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 460), spacing: 12)], spacing: 12) {
            ForEach(viewModel.scheme.roots.indices, id: \.self) { index in
                branch(viewModel.scheme.roots[index], depth: 0)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
            if !viewModel.scheme.unassignedEntries.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(Constants.otherPromotedClasses).font(.headline)
                    ForEach(viewModel.scheme.unassignedEntries, id: \.name) { item in
                        entry(item)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func branch(_ branch: ClassSchemeBranch, depth: Int) -> AnyView {
        AnyView(VStack(alignment: .leading, spacing: 8) {
            if let title = viewModel.title(at: depth) {
                Text(title).font(.caption.bold()).foregroundStyle(.secondary)
            }
            entry(branch.entry)
            if let upgrade = branch.upgrade {
                HStack(alignment: .top, spacing: 8) {
                    Text(Constants.upgradeItem).font(.caption.bold()).foregroundStyle(.secondary)
                    TableCellText(runs: upgrade.runs, bold: false)
                    if !viewModel.availableIcons(upgrade.imageURLs).isEmpty {
                        TableCellImages(urls: viewModel.availableIcons(upgrade.imageURLs),
                                        assets: viewModel.assets, onLink: onLink)
                    }
                }
            }
            ForEach(branch.children.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: Constants.arrow)
                        .font(.caption.bold()).foregroundStyle(.tint)
                    self.branch(branch.children[index], depth: depth + 1)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            }
        })
    }

    private func entry(_ item: FatesClassEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let artworkURL = item.artworkURL {
                ArticleImageView(url: artworkURL, assetURL: viewModel.assetKey(for: artworkURL),
                                 alt: item.name, compact: false,
                                 fetchedAt: viewModel.fetchedAt(for: artworkURL),
                                 onLink: onLink, thumbnailSize: Constants.artworkSize)
            }
            VStack(alignment: .leading, spacing: 5) {
                TableCellText(runs: item.runs, bold: false).equatable()
                if !viewModel.availableIcons(item.iconURLs).isEmpty {
                    TableCellImages(urls: viewModel.availableIcons(item.iconURLs),
                                    assets: viewModel.assets, onLink: onLink)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
