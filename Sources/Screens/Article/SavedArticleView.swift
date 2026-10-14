import SwiftUI

private enum Constants {
    static var openSourcePage: String { AppText.localized( "Open source page") }
}

struct SavedArticleView: View {
    let title: String
    let category: String
    let tint: Color
    let blocks: [ArticlePresentationBlock]
    let assets: [String: Date]
    let onSource: () -> Void
    let onLink: (URL) -> Void
    private let controlHeight: CGFloat = 32

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Text(title)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                HStack(spacing: 8) {
                    Text(category.uppercased())
                        .font(.caption2.bold())
                        .tracking(0.5)
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 8)
                        .frame(height: controlHeight)
                        .background(tint.opacity(0.12), in: Capsule())
                    Button(action: onSource) {
                        Image(systemName: "safari")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: controlHeight, height: controlHeight)
                            .background(tint.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Constants.openSourcePage)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: 1000, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(tint.opacity(0.07))
            Divider()
            NativeArticleView(blocks: blocks, assets: assets, onLink: onLink)
        }
    }
}
