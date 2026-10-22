import SwiftUI
import SerenesNavigation
import Observation
import SwiftData

private enum Constants {
    static let mediaFilesCount = (english: "media files", russian: ("медиафайл", "медиафайла", "медиафайлов"))
    static var collections: String { AppText.localized( "Collections") }
    static var files: String { AppText.localized( "Files") }
    static var searchMedia: String { AppText.localized( "Search media") }
    static var media: String { AppText.localized( "Media") }
    static var showMore: String { AppText.localized("Show more") }
}

struct MediaView: View {
    @State var viewModel = MediaViewModel()
    @Query(filter: #Predicate<ContentPage> { $0.category == "Media" }) private var pages: [ContentPage]
    @Environment(\.modelContext) private var modelContext
    @SceneStorage("SerenesForest.mediaScroll") private var scrollAnchor: String?

    private var mediaPages: [ContentPage] { viewModel.mediaPages(from: pages) }

    var body: some View {
        let filteredPages = mediaPages
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sectionSubtitle(AppText.count(viewModel.totalAssetCount, english: Constants.mediaFilesCount.english, russian: Constants.mediaFilesCount.russian))
                Text(Constants.collections).font(.headline)
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.visiblePages(from: filteredPages)) { page in
                        NavigationLink(value: PageRoute.article(page.url)) { PageRow(page: page) }
                            .buttonStyle(.plain)
                            .id("page-\(page.url)")
                    }
                    if viewModel.hasMorePages(in: filteredPages) {
                        Button(Constants.showMore) { viewModel.showMorePages() }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .scrollTargetLayout()
                Text(Constants.files).font(.headline).padding(.top, 12)
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.assets) { asset in
                        NavigationLink(value: PageRoute.asset(asset.url)) { AssetRow(asset: asset) }
                            .buttonStyle(.plain)
                            .id("asset-\(asset.url)")
                    }
                    if viewModel.hasMoreAssets {
                        Button(Constants.showMore) {
                            Task { await viewModel.loadMoreAssets(in: modelContext.container) }
                        }
                            .disabled(viewModel.isLoadingAssets)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    if viewModel.isLoadingAssets { ProgressView().frame(maxWidth: .infinity) }
                }
                .scrollTargetLayout()
            }
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .scrollPosition(id: $scrollAnchor)
        .searchable(text: $viewModel.search, prompt: Constants.searchMedia)
        .task(id: viewModel.search) { await viewModel.loadAssets(in: modelContext.container) }
        .onChange(of: viewModel.search) { _, _ in
            scrollAnchor = nil
        }
        .navigationTitle(Constants.media)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
