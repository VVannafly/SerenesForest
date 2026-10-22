import SwiftUI
import SerenesNavigation
import Observation
import SwiftData

private enum Constants {
    static let indexedPagesCount = (english: "indexed pages", russian: ("страница в библиотеке", "страницы в библиотеке", "страниц в библиотеке"))
    static var section: String { AppText.localized( "Section") }
    static var searchTheLibrary: String { AppText.localized( "Search the library") }
    static var allPages: String { AppText.localized( "All pages") }
    static var showMore: String { AppText.localized("Show more") }
}

struct AllPagesView: View {
    @State var viewModel = AllPagesViewModel()
    @Environment(\.modelContext) private var modelContext
    @SceneStorage("SerenesForest.allPagesScroll") private var scrollAnchor: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    if let totalCount = viewModel.totalCount {
                        sectionSubtitle(AppText.count(totalCount, english: Constants.indexedPagesCount.english, russian: Constants.indexedPagesCount.russian))
                    }
                    Spacer()
                    Picker(Constants.section, selection: $viewModel.category) {
                        ForEach(viewModel.categories, id: \.self) { Text($0) }
                    }
                    .frame(maxWidth: 180)
                }
                LazyVStack(spacing: 12) {
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
                }
                .scrollTargetLayout()
            }
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .scrollPosition(id: $scrollAnchor)
        .searchable(text: $viewModel.search, prompt: Constants.searchTheLibrary)
        .task(id: "\(viewModel.search)|\(viewModel.category)") {
            await viewModel.load(in: modelContext.container)
        }
        .onChange(of: viewModel.search) { _, _ in
            scrollAnchor = nil
        }
        .onChange(of: viewModel.category) { _, _ in
            scrollAnchor = nil
        }
        .navigationTitle(Constants.allPages)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
