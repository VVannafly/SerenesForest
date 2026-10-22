import SerenesParsing
import SwiftUI
import SerenesNavigation
import Observation
import SwiftData

private enum Constants {
    static var updatesFromSerenesForest: String { AppText.localized( "Updates from Serenes Forest") }
    static var checkingLatestNews: String { AppText.localized( "Checking latest news") }
    static var noNewsFound: String { AppText.localized( "No news found") }
    static var pullDownToCheckFor: String { AppText.localized( "Pull down to check for new articles.") }
    static var searchNews: String { AppText.localized( "Search news") }
    static var news: String { AppText.localized( "News") }
    static var showMore: String { AppText.localized("Show more") }
}

struct NewsView: View {
    @State var viewModel = NewsViewModel()
    @Environment(ContentSync.self) private var sync: ContentSync
    @Environment(\.modelContext) private var modelContext
    @SceneStorage("SerenesForest.newsScroll") private var scrollAnchor: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 15) {
                sectionSubtitle(Constants.updatesFromSerenesForest)
                if sync.isNewsSyncing {
                    ProgressView(Constants.checkingLatestNews)
                        .font(.subheadline)
                }
                if let message = sync.newsErrorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(viewModel.pages) { page in
                    NavigationLink(value: PageRoute.article(page.url)) {
                        PageRow(title: page.title,
                                displayTitle: AppText.isRussian ? (page.russianTitle ?? page.title) : page.title,
                                category: page.category, gameSlug: page.gameSlug,
                                publishedAt: page.publishedAt)
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
                if viewModel.pages.isEmpty && !viewModel.isLoading && viewModel.errorMessage == nil && !sync.isNewsSyncing {
                    ContentUnavailableView(Constants.noNewsFound, systemImage: "newspaper", description: Text(Constants.pullDownToCheckFor))
                }
            }
            .scrollTargetLayout()
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .scrollPosition(id: $scrollAnchor)
        .searchable(text: $viewModel.search, prompt: Constants.searchNews)
        .task(id: viewModel.search) { await viewModel.load(in: modelContext.container) }
        .navigationTitle(Constants.news)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .refreshable {
            await sync.syncNews(force: true)
            await viewModel.load(in: modelContext.container)
        }
    }
}
