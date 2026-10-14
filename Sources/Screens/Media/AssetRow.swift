import SwiftUI

struct AssetRow: View {
    let asset: ContentAsset
    private let viewModel: AssetRowViewModel

    init(asset: ContentAsset) {
        self.asset = asset
        viewModel = AssetRowViewModel(asset: asset)
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: viewModel.symbol)
                .foregroundStyle(Palette.accent)
                .frame(width: 42, height: 42)
                .background(Palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.title).font(.headline).lineLimit(2)
                Text(LocalizedStringKey(viewModel.kind))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
