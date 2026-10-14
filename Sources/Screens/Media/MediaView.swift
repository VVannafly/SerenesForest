import SwiftUI
import Observation
import SwiftData

private enum Constants {
    static let mediaFilesCount = (english: "media files", russian: ("медиафайл", "медиафайла", "медиафайлов"))
    static var collections: String { AppText.localized( "Collections") }
    static var files: String { AppText.localized( "Files") }
    static var searchMedia: String { AppText.localized( "Search media") }
    static var media: String { AppText.localized( "Media") }
}

struct MediaView: View {
    @State var viewModel = MediaViewModel()
    @Query private var pages: [ContentPage]
    @Query private var assets: [ContentAsset]
    @SceneStorage("SerenesForest.mediaScroll") private var scrollAnchor: String?

    private var mediaPages: [ContentPage] { viewModel.mediaPages(from: pages) }
    private var mediaAssets: [ContentAsset] { viewModel.mediaAssets(from: assets) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sectionSubtitle(AppText.count(assets.count, english: Constants.mediaFilesCount.english, russian: Constants.mediaFilesCount.russian))
                Text(Constants.collections).font(.headline)
                LazyVStack(spacing: 12) {
                    ForEach(mediaPages) { page in
                        NavigationLink { PageDetailView(page: page) } label: { PageRow(page: page) }
                            .buttonStyle(.plain)
                            .id("page-\(page.url)")
                    }
                }
                .scrollTargetLayout()
                Text(Constants.files).font(.headline).padding(.top, 12)
                LazyVStack(spacing: 12) {
                    ForEach(mediaAssets) { asset in
                        NavigationLink { AssetDetailView(asset: asset) } label: { AssetRow(asset: asset) }
                            .buttonStyle(.plain)
                            .id("asset-\(asset.url)")
                    }
                }
                .scrollTargetLayout()
            }
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .scrollPosition(id: $scrollAnchor)
        .searchable(text: $viewModel.search, prompt: Constants.searchMedia)
        .navigationTitle(Constants.media)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
