import SwiftUI

private enum Constants {
    static var noLinkedPage: String { AppText.localized("No linked page") }
    static var opensInBrowser: String { AppText.localized("Opens in browser") }
    static var open: String { AppText.localized("Open") }
}

struct GameNavigationRow: View {
    private let viewModel = GameNavigationRowViewModel()
    let item: GameNavigationItem
    let pages: [ContentPage]
    var tint: Color = Palette.accent
    @Environment(\.navigationTranslations) private var navigationTranslations
    @Environment(\.openURL) private var openURL

    var body: some View {
        let destination = viewModel.destination(for: item, pages: pages)
        Group {
            switch destination {
            case .about(let page):
                NavigationLink { GameAboutView(page: page) } label: { row(for: destination) }
                    .buttonStyle(.plain)
            case .topicItems:
                NavigationLink { GameTopicItemsView(item: item, pages: pages, tint: tint) } label: { row(for: destination) }
                    .buttonStyle(.plain)
            case .newsFeed(let slug, let url):
                NavigationLink { GameNewsFeedView(gameSlug: slug, categoryURL: url) } label: { row(for: destination) }
                    .buttonStyle(.plain)
            case .article(let page):
                NavigationLink { PageDetailView(page: page) } label: { row(for: destination) }
                    .buttonStyle(.plain)
            case .artwork(let url):
                NavigationLink { GameArtworkView(title: item.title, sourceURL: url) } label: { row(for: destination) }
                    .buttonStyle(.plain)
            case .external(let url):
                Button { openURL(url) } label: { row(for: destination) }
                    .buttonStyle(.plain)
            case .section(let url):
                NavigationLink { GameLinkView(title: item.title, url: url, pages: pages, tint: tint) } label: { row(for: destination) }
                    .buttonStyle(.plain)
            case .topicLinks:
                NavigationLink { GameTopicLinksView(item: item, pages: pages, tint: tint) } label: { row(for: destination) }
                    .buttonStyle(.plain)
            case .none:
                row(for: destination)
                    .accessibilityHint(Constants.noLinkedPage)
            }
        }
    }

    private func row(for destination: GameNavigationDestination) -> some View {
        HStack(spacing: 13) {
            ContentIcon(title: item.title, size: 36, tint: tint)
            Text(LocalizedStringKey(navigationTranslations[item.title] ?? item.title))
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if destination.isNavigable {
                Image(systemName: destination.isExternal ? "safari" : "chevron.right")
                    .font(destination.isExternal ? .caption2 : .caption.bold())
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel(destination.isExternal ? Constants.opensInBrowser : Constants.open)
            }
        }
        .padding(10)
        .background(tint.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
    }
}
