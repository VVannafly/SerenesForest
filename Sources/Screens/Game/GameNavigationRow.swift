import SwiftUI
import SerenesNavigation
import SwiftData

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
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let destination = viewModel.destination(for: item, pages: pages, context: modelContext)
        Group {
            if let route = viewModel.route(for: destination, item: item, pages: pages) {
                NavigationLink(value: route) { row(for: destination) }
                    .buttonStyle(.plain)
            } else if case .external(let url) = destination {
                Button { openURL(url) } label: { row(for: destination) }
                    .buttonStyle(.plain)
            } else {
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
