import SwiftUI

private enum Constants {
    static func status(_ value: String) -> String { AppText.localized( "My status: \(value)") }
    static var myStatus: String { AppText.localized( "My status") }
    static var checkGameUpdates: String { AppText.localized( "Check game updates") }
    static var sourcePage: String { AppText.localized( "Source page") }
}

extension GameDetailView {
    var gameHero: some View {
        VStack(alignment: .leading, spacing: 0) {
            CachedBundleImage(name: game.slug, mode: .fit, maxPixelSize: 1200)
                .aspectRatio(2.1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(Palette.accent.opacity(0.12))
            VStack(alignment: .leading, spacing: 17) {
                HStack(alignment: .center, spacing: 12) {
                    Text(game.platform.uppercased())
                        .font(.caption.bold())
                        .tracking(0.8)
                        .foregroundStyle(theme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 12)
                        .frame(height: HeaderLayout.controlHeight)
                        .background(theme.accent.opacity(0.11), in: Capsule())
                    Spacer(minLength: 0)
                    Button { game.isFavorite.toggle() } label: {
                        Image(systemName: game.isFavorite ? "heart.fill" : "heart")
                            .font(.title3)
                            .foregroundStyle(game.isFavorite ? .pink : .secondary)
                            .frame(width: HeaderLayout.controlHeight, height: HeaderLayout.controlHeight)
                            .background(.quaternary.opacity(0.5), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(game.isFavorite ? "Remove favorite" : "Add favorite")
                }
                Text(game.title)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Text(Constants.myStatus)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    statusMenu
                }
                if let overview {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text(overview.tagline)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.accent)
                        Text(overview.story)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                gameActions
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(.primary.opacity(0.07)) }
    }

    @ViewBuilder var gameActions: some View {
        if viewModel.guideWidth >= 520 {
            HStack(spacing: 10) {
                checkUpdatesButton
                sourcePageButton
            }
        } else {
            VStack(spacing: 10) {
                checkUpdatesButton
                sourcePageButton
            }
        }
    }

    var checkUpdatesButton: some View {
        Button { Task { await sync.sync(gameSlug: game.slug) } } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise")
                Text(Constants.checkGameUpdates).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(GameActionButtonStyle(tint: theme.accent))
        .frame(maxWidth: .infinity)
        .disabled(sync.isSyncing)
    }

    var sourcePageButton: some View {
        Button { if let url = URL(string: game.sourceURL) { openURL(url) } } label: {
            HStack(spacing: 8) {
                Image(systemName: "safari").font(.caption)
                Text(Constants.sourcePage).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(GameActionButtonStyle(tint: theme.accent))
        .frame(maxWidth: .infinity)
    }

    var statusMenu: some View {
        Menu {
            ForEach(GameProgress.allCases) { option in
                Button {
                    game.status = option.rawValue
                } label: {
                    Label(LocalizedStringKey(option.rawValue), systemImage: option.symbol)
                    if progress == option { Image(systemName: "checkmark") }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: progress.symbol)
                Text(LocalizedStringKey(progress.rawValue)).lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.bold())
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(progress.tint)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(progress.tint.opacity(0.12), in: Capsule())
        }
        .accessibilityLabel(Constants.status(progress.rawValue))
    }


}
