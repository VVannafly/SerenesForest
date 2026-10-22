import SwiftUI
import SerenesNavigation
import Observation
import SwiftData

private enum Constants {
    static let bookmarksCount = (english: "bookmarks", russian: ("закладка", "закладки", "закладок"))
    static var savedPages: String { AppText.localized( "Saved pages") }
    static var noSavedPages: String { AppText.localized( "No saved pages") }
    static var searchSavedPages: String { AppText.localized( "Search saved pages") }
}

struct SavedPagesView: View {
    @State var viewModel = SavedPagesViewModel()
    @Query(filter: #Predicate<ContentPage> { $0.bookmarkedAt != nil },
           sort: \ContentPage.bookmarkedAt, order: .reverse)
    private var savedPages: [ContentPage]
    @Query private var games: [Game]
    @SceneStorage("SerenesForest.savedPagesScroll") private var scrollAnchor: String?

    private var entries: [SavedPageEntry] { viewModel.entries(savedPages: savedPages, games: games) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                sectionHeading(Constants.savedPages, subtitle: AppText.count(savedPages.count, english: Constants.bookmarksCount.english, russian: Constants.bookmarksCount.russian))
                if savedPages.isEmpty {
                    ContentUnavailableView(Constants.noSavedPages, systemImage: "bookmark")
                        .frame(maxWidth: .infinity)
                } else if entries.isEmpty {
                    ContentUnavailableView.search(text: viewModel.search)
                } else {
                    ForEach(entries) { entry in
                        if let game = entry.game {
                            NavigationLink(value: PageRoute.game(game.slug)) {
                                PageRow(page: entry.page)
                            }
                            .buttonStyle(.plain)
                            .id(entry.page.url)
                        } else {
                            NavigationLink(value: PageRoute.article(entry.page.url)) {
                                PageRow(page: entry.page)
                            }
                            .buttonStyle(.plain)
                            .id(entry.page.url)
                        }
                    }
                }
            }
            .scrollTargetLayout()
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .scrollPosition(id: $scrollAnchor)
        .searchable(text: $viewModel.search, prompt: Constants.searchSavedPages)
        .navigationTitle(Constants.savedPages)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
