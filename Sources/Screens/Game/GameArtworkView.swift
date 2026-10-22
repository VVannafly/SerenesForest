import SwiftUI
import SwiftData
import SerenesNavigation

private enum Constants {
    static var noSavedArtwork: String { AppText.localized( "No saved artwork") }
    static var sourcePage: String { AppText.localized( "Source page") }
}

struct GameArtworkView: View {
    private let viewModel = GameArtworkViewModel()
    @Environment(\.navigationTranslations) private var navigationTranslations
    let title: String
    let sourceURL: URL
    @Query private var assets: [ContentAsset]
    @Environment(\.openURL) private var openURL

    var body: some View {
        let artwork = viewModel.artwork(from: assets, sourceURL: sourceURL)
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110, maximum: 180), spacing: 12)], spacing: 12) {
                ForEach(artwork) { asset in
                    NavigationLink(value: PageRoute.asset(asset.url)) {
                        VStack(alignment: .leading, spacing: 6) {
                            ArtworkThumbnail(asset: asset)
                                .frame(height: 110)
                            Text(asset.title).font(.caption).lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            if artwork.isEmpty {
                ContentUnavailableView(Constants.noSavedArtwork, systemImage: "photo.on.rectangle")
            }
            Button { openURL(sourceURL) } label: {
                Label(Constants.sourcePage, systemImage: "safari")
            }
            .font(.caption)
            .padding(.bottom, 20)
        }
        .pauseImageLoadingDuringScroll()
        .navigationTitle(navigationTranslations[title] ?? title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
