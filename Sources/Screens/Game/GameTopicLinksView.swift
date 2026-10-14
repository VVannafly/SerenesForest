import SwiftUI

private enum Constants {
    static let linksCount = (english: "links", russian: ("ссылка", "ссылки", "ссылок"))
}

struct GameTopicLinksView: View {
    let item: GameNavigationItem
    let pages: [ContentPage]
    let tint: Color
    @Environment(\.navigationTranslations) private var navigationTranslations
    @SceneStorage private var storedScrollAnchor: String

    init(item: GameNavigationItem, pages: [ContentPage], tint: Color) {
        self.item = item
        self.pages = pages
        self.tint = tint
        _storedScrollAnchor = SceneStorage(wrappedValue: "", "SerenesForest.topicLinks.\(pages.first?.gameSlug ?? "").\(item.title)")
    }

    private var scrollAnchor: Binding<String?> {
        Binding(get: { storedScrollAnchor.isEmpty ? nil : storedScrollAnchor },
                set: { storedScrollAnchor = $0 ?? "" })
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                sectionSubtitle(AppText.count(item.links.count, english: Constants.linksCount.english, russian: Constants.linksCount.russian))
                ForEach(Array(item.links.enumerated()), id: \.offset) { index, link in
                    GameNavigationRow(item: GameNavigationItem(id: index,
                        title: link.title.isEmpty ? link.url.absoluteString : link.title,
                        links: [link]), pages: pages, tint: tint)
                        .id("link-\(index)")
                }
            }
            .scrollTargetLayout()
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .scrollPosition(id: scrollAnchor)
        .navigationTitle(navigationTranslations[item.title] ?? item.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
