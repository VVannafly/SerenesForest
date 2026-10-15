import SwiftUI
import Observation
import SwiftData

private enum Constants {
    static let articlesCount = (english: "articles", russian: ("статья", "статьи", "статей"))
    static var fireEmblemWiki: String { AppText.localized( "Fire Emblem Wiki") }
    static var topic: String { AppText.localized( "Topic") }
    static var game: String { AppText.localized( "Game") }
    static var all: String { AppText.localized( "All") }
    static var searchWikiArticles: String { AppText.localized( "Search wiki articles") }
}

struct WikiLibraryView: View {
    @State var viewModel = WikiLibraryViewModel()
    @Query(filter: #Predicate<ContentPage> { $0.category.starts(with: "Wiki · ") }) private var allPages: [ContentPage]
    @SceneStorage("SerenesForest.wikiScroll") private var scrollAnchor: String?

    private var wikiPages: [ContentPage] { viewModel.wikiPages(from: allPages) }
    private var groups: [String] { viewModel.groups(from: allPages) }
    private var pages: [ContentPage] { viewModel.pages(from: allPages) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                sectionHeading(Constants.fireEmblemWiki, subtitle: AppText.count(wikiPages.count, english: Constants.articlesCount.english, russian: Constants.articlesCount.russian))
                HStack(spacing: 10) {
                    Picker(Constants.topic, selection: $viewModel.selectedGroup) {
                        ForEach(groups, id: \.self) { Text(LocalizedStringKey($0)).tag($0) }
                    }
                    Picker(Constants.game, selection: $viewModel.selectedGame) {
                        Text(Constants.all).tag("All")
                        ForEach(Catalog.games, id: \.0) { game in
                            Text(game.1).tag(game.0)
                        }
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 520)
                ForEach(pages) { page in
                    NavigationLink { PageDetailView(page: page) } label: { PageRow(page: page) }
                        .buttonStyle(.plain)
                        .id(page.url)
                }
                if pages.isEmpty {
                    ContentUnavailableView.search(text: viewModel.search)
                }
            }
            .scrollTargetLayout()
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .scrollPosition(id: $scrollAnchor)
        .searchable(text: $viewModel.search, prompt: Constants.searchWikiArticles)
        .navigationTitle(Constants.fireEmblemWiki)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
