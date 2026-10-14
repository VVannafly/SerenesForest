import SwiftUI

private enum Constants {
    static let subtopicsCount = (english: "subtopics", russian: ("подтема", "подтемы", "подтем"))
    static var openSourcePage: String { AppText.localized( "Open source page") }
    static let parentAnchor = "parent"
}

struct GameLinkView: View {
    private let viewModel = GameLinkViewModel()
    let title: String
    let url: URL
    let pages: [ContentPage]
    let tint: Color
    @Environment(\.navigationTranslations) private var navigationTranslations
    @Environment(\.openURL) private var openURL
    @SceneStorage private var storedScrollAnchor: String

    init(title: String, url: URL, pages: [ContentPage], tint: Color) {
        self.title = title
        self.url = url
        self.pages = pages
        self.tint = tint
        _storedScrollAnchor = SceneStorage(wrappedValue: "", "SerenesForest.gameLink.\(url.absoluteString)")
    }

    private var scrollAnchor: Binding<String?> {
        Binding(get: { storedScrollAnchor.isEmpty ? nil : storedScrollAnchor },
                set: { storedScrollAnchor = $0 ?? "" })
    }

    var body: some View {
        let content = viewModel.content(url: url, pages: pages)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                sectionSubtitle(AppText.count(content.children.count, english: Constants.subtopicsCount.english, russian: Constants.subtopicsCount.russian))
                if let page = content.page {
                    NavigationLink { PageDetailView(page: page) } label: { PageRow(page: page) }
                        .buttonStyle(.plain)
                        .id(Constants.parentAnchor)
                } else {
                    Button { openURL(url) } label: {
                        Label(Constants.openSourcePage, systemImage: "safari")
                    }
                    .buttonStyle(.bordered)
                }
                ForEach(content.children) { child in
                    Group {
                        if let page = child.page, !child.hasDescendants {
                            NavigationLink { PageDetailView(page: page) } label: { PageRow(page: page) }
                                .buttonStyle(.plain)
                        } else {
                            NavigationLink { GameLinkView(title: child.title, url: child.url, pages: pages, tint: tint) } label: {
                                HStack(spacing: 13) {
                                    ContentIcon(title: child.title, size: 36, tint: tint)
                                    Text(navigationTranslations[child.title] ?? child.title).font(.body.weight(.medium))
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
                                }
                                .padding(14)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .id(child.url.absoluteString)
                }
            }
            .scrollTargetLayout()
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .scrollPosition(id: scrollAnchor)
        .navigationTitle(navigationTranslations[title] ?? title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
