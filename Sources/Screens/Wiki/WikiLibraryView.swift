import SwiftUI
import SerenesNavigation
import Observation
import SwiftData

private enum Constants {
    static let articlesCount = (english: "articles", russian: ("статья", "статьи", "статей"))
    static var fireEmblemWiki: String { AppText.localized( "Fire Emblem Wiki") }
    static var topic: String { AppText.localized( "Topic") }
    static var game: String { AppText.localized( "Game") }
    static var all: String { AppText.localized( "All") }
    static var searchWikiArticles: String { AppText.localized( "Search wiki articles") }
    static var showMore: String { AppText.localized("Show more") }
}

struct WikiLibraryView: View {
    @State var viewModel = WikiLibraryViewModel()
    @Environment(\.modelContext) private var modelContext
    @SceneStorage("SerenesForest.wikiScroll") private var scrollAnchor: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                sectionHeading(Constants.fireEmblemWiki, subtitle: viewModel.totalCount.map {
                    AppText.count($0, english: Constants.articlesCount.english,
                                  russian: Constants.articlesCount.russian)
                } ?? "")
                HStack(spacing: 10) {
                    Picker(Constants.topic, selection: $viewModel.selectedGroup) {
                        ForEach(viewModel.groups, id: \.self) { Text(LocalizedStringKey($0)).tag($0) }
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
                ForEach(viewModel.pages) { page in
                    NavigationLink(value: PageRoute.article(page.url)) {
                        PageRow(title: page.title,
                                displayTitle: AppText.isRussian ? (page.russianTitle ?? page.title) : page.title,
                                category: page.category, gameSlug: page.gameSlug)
                    }
                        .buttonStyle(.plain)
                        .id(page.url)
                }
                if viewModel.hasMorePages {
                    Button(Constants.showMore) {
                        Task { await viewModel.loadMore(in: modelContext.container) }
                    }
                        .disabled(viewModel.isLoading)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                if viewModel.isLoading { ProgressView().frame(maxWidth: .infinity) }
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.secondary)
                }
                if viewModel.pages.isEmpty && !viewModel.isLoading && viewModel.errorMessage == nil {
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
        .task(id: "\(viewModel.search)|\(viewModel.selectedGroup)|\(viewModel.selectedGame)") {
            await viewModel.load(in: modelContext.container)
        }
        .onChange(of: viewModel.search) { _, _ in
            scrollAnchor = nil
        }
        .onChange(of: viewModel.selectedGroup) { _, _ in
            scrollAnchor = nil
        }
        .onChange(of: viewModel.selectedGame) { _, _ in
            scrollAnchor = nil
        }
        .navigationTitle(Constants.fireEmblemWiki)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
