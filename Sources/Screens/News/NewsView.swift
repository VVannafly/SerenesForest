import SerenesParsing
import SwiftUI
import Observation
import SwiftData

private enum Constants {
    static var updatesFromSerenesForest: String { AppText.localized( "Updates from Serenes Forest") }
    static var checkingLatestNews: String { AppText.localized( "Checking latest news") }
    static var noNewsFound: String { AppText.localized( "No news found") }
    static var pullDownToCheckFor: String { AppText.localized( "Pull down to check for new articles.") }
    static var searchNews: String { AppText.localized( "Search news") }
    static var news: String { AppText.localized( "News") }
}

struct NewsView: View {
    @State var viewModel = NewsViewModel()
    @Environment(ContentSync.self) private var sync: ContentSync
    @Query private var allPages: [ContentPage]
    @SceneStorage("SerenesForest.newsScroll") private var scrollAnchor: String?

    private var pages: [ContentPage] { viewModel.pages(from: allPages) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 15) {
                sectionSubtitle(Constants.updatesFromSerenesForest)
                if viewModel.isChecking || sync.isNewsSyncing {
                    ProgressView(Constants.checkingLatestNews)
                        .font(.subheadline)
                }
                if let message = sync.newsErrorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(pages) { page in
                    NavigationLink { PageDetailView(page: page) } label: { PageRow(page: page) }
                        .buttonStyle(.plain)
                        .id(page.url)
                }
                if pages.isEmpty && !viewModel.isChecking && !sync.isNewsSyncing {
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
        .navigationTitle(Constants.news)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            viewModel.isChecking = true
            await sync.syncNews()
            viewModel.isChecking = false
        }
        .refreshable { await sync.syncNews(force: true) }
    }
}
