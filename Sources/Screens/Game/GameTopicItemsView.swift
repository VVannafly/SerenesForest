import SwiftUI

private enum Constants {
    static let subtopicsCount = (english: "subtopics", russian: ("подтема", "подтемы", "подтем"))
}

struct GameTopicItemsView: View {
    let item: GameNavigationItem
    let pages: [ContentPage]
    let tint: Color
    @Environment(\.navigationTranslations) private var navigationTranslations
    @SceneStorage private var storedScrollAnchor: String

    init(item: GameNavigationItem, pages: [ContentPage], tint: Color) {
        self.item = item
        self.pages = pages
        self.tint = tint
        _storedScrollAnchor = SceneStorage(wrappedValue: "", "SerenesForest.topicItems.\(pages.first?.gameSlug ?? "").\(item.title)")
    }

    private var scrollAnchor: Binding<String?> {
        Binding(get: { storedScrollAnchor.isEmpty ? nil : storedScrollAnchor },
                set: { storedScrollAnchor = $0 ?? "" })
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                sectionSubtitle(AppText.count(item.children.count, english: Constants.subtopicsCount.english, russian: Constants.subtopicsCount.russian))
                if !item.links.isEmpty {
                    GameNavigationRow(item: GameNavigationItem(id: 0, title: item.title, links: item.links), pages: pages, tint: tint)
                        .id("parent")
                }
                ForEach(item.children) { child in
                    GameNavigationRow(item: child, pages: pages, tint: tint)
                        .id("child-\(child.id)")
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
