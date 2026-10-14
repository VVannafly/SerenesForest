import SwiftUI
import Observation
import SwiftData

private enum Constants {
    static let indexedPagesCount = (english: "indexed pages", russian: ("страница в библиотеке", "страницы в библиотеке", "страниц в библиотеке"))
    static var section: String { AppText.localized( "Section") }
    static var searchTheLibrary: String { AppText.localized( "Search the library") }
    static var allPages: String { AppText.localized( "All pages") }
}

struct AllPagesView: View {
    @State var viewModel = AllPagesViewModel()
    @Query private var allPages: [ContentPage]
    @SceneStorage("SerenesForest.allPagesScroll") private var scrollAnchor: String?

    private var categories: [String] { viewModel.categories(from: allPages) }
    private var pages: [ContentPage] { viewModel.pages(from: allPages) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    sectionSubtitle(AppText.count(allPages.count, english: Constants.indexedPagesCount.english, russian: Constants.indexedPagesCount.russian))
                    Spacer()
                    Picker(Constants.section, selection: $viewModel.category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    .frame(maxWidth: 180)
                }
                LazyVStack(spacing: 12) {
                    ForEach(pages) { page in
                        NavigationLink { PageDetailView(page: page) } label: { PageRow(page: page) }
                            .buttonStyle(.plain)
                            .id(page.url)
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
        .navigationTitle(Constants.allPages)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
