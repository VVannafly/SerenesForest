import SwiftUI
import Observation
import SwiftData

private enum Constants {
    static let articlesCount = (english: "articles", russian: ("статья", "статьи", "статей"))
    static var newsFeed: String { AppText.localized( "News Feed") }
    static var noNewsFound: String { AppText.localized( "No news found") }
    static var pullDownToCheckFor: String { AppText.localized( "Pull down to check for new articles.") }
    static var loadOlderNews: String { AppText.localized( "Load older news") }
    static var searchNews: String { AppText.localized( "Search news") }
}

struct GameNewsFeedView: View {
    let gameSlug: String
    let categoryURL: URL
    @State private var viewModel: GameNewsFeedViewModel
    @Environment(ContentSync.self) private var sync: ContentSync
    @Query(filter: #Predicate<ContentPage> { $0.category == "News" }) private var news: [ContentPage]
    @SceneStorage private var storedScrollAnchor: String

    init(gameSlug: String, categoryURL: URL) {
        self.gameSlug = gameSlug
        self.categoryURL = categoryURL
        _viewModel = State(initialValue: GameNewsFeedViewModel(gameSlug: gameSlug, categoryURL: categoryURL))
        _storedScrollAnchor = SceneStorage(wrappedValue: "", "SerenesForest.gameNewsScroll.\(gameSlug)")
    }

    private var scrollAnchor: Binding<String?> {
        Binding(get: { storedScrollAnchor.isEmpty ? nil : storedScrollAnchor },
                set: { storedScrollAnchor = $0 ?? "" })
    }

    private var pages: [ContentPage] { viewModel.pages(from: news) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                sectionHeading(Constants.newsFeed, subtitle: AppText.count(pages.count, english: Constants.articlesCount.english, russian: Constants.articlesCount.russian))
                if let errorMessage = viewModel.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(pages) { page in
                    NavigationLink { PageDetailView(page: page) } label: { PageRow(page: page) }
                        .buttonStyle(.plain)
                        .id(page.url)
                }
                if pages.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(Constants.noNewsFound, systemImage: "newspaper",
                                           description: Text(Constants.pullDownToCheckFor))
                }
                if viewModel.hasMore {
                    Button {
                        Task { await viewModel.load(pageNumber: viewModel.nextPage, sync: sync) }
                    } label: {
                        if viewModel.isLoading { ProgressView() }
                        else { Label(Constants.loadOlderNews, systemImage: "arrow.down") }
                    }
                    .disabled(viewModel.isLoading || sync.isSyncing)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                } else if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .scrollTargetLayout()
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .scrollPosition(id: scrollAnchor)
        .searchable(text: $viewModel.search, prompt: Constants.searchNews)
        .navigationTitle(Constants.newsFeed)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await viewModel.load(pageNumber: 1, sync: sync) }
        .refreshable { await viewModel.load(pageNumber: 1, force: true, sync: sync) }
    }

}
