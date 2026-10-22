import SwiftUI
import SerenesNavigation
import Observation
import SwiftData

private enum Constants {
    static var favorites: String { AppText.localized("Favourites") }
    static var library: String { AppText.localized( "Library") }
    static var browseGuidesByTitle: String { AppText.localized( "Browse guides by title") }
    static var allStatuses: String { AppText.localized( "All statuses") }
    static var noGamesFound: String { AppText.localized( "No games found") }
    static var searchGames: String { AppText.localized( "Search games") }
}

struct GamesView: View {
    @State var viewModel = GamesViewModel()
    let favoritesOnly: Bool
    @Query(sort: \Game.title) private var games: [Game]
    @Query(filter: #Predicate<ContentPage> { $0.category == "Game" }) private var pages: [ContentPage]

    init(favoritesOnly: Bool) {
        self.favoritesOnly = favoritesOnly
    }

    private var platforms: [String] { viewModel.platforms(for: games) }
    private var filtered: [Game] { viewModel.filtered(games: games, favoritesOnly: favoritesOnly) }

    var body: some View {
        let overviews = viewModel.overviews(for: filtered, pages: pages)
        GeometryReader { geometry in
            let contentWidth = min(max(geometry.size.width - 48, 0), 1052)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        sectionSubtitle(Constants.browseGuidesByTitle)
                        Spacer()
                    }
                    HStack(spacing: 8) {
                        Menu {
                            ForEach(platforms, id: \.self) { value in
                                Button(value) { viewModel.platform = value }
                            }
                        } label: {
                            libraryFilterLabel(viewModel.platform == "All" ? "Platform" : viewModel.platform, symbol: "gamecontroller")
                        }
                        Menu {
                            Button(Constants.allStatuses) { viewModel.status = "All" }
                            ForEach(GameProgress.allCases) { option in
                                Button(LocalizedStringKey(option.rawValue)) { viewModel.status = option.rawValue }
                            }
                        } label: {
                            libraryFilterLabel(viewModel.status == "All" ? "Status" : viewModel.status, symbol: "line.3.horizontal.decrease")
                        }
                        Menu {
                            ForEach(GamesViewModel.SortOrder.allCases, id: \.self) { option in
                                Button(LocalizedStringKey(option.rawValue)) { viewModel.sortOrder = option }
                            }
                        } label: {
                            libraryFilterLabel(viewModel.sortOrder.rawValue, symbol: "arrow.up.arrow.down")
                        }
                    }
                    .frame(width: contentWidth)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145, maximum: 225), spacing: 14)], spacing: 14) {
                        ForEach(filtered) { game in
                            NavigationLink(value: PageRoute.game(game.slug)) {
                                GameCard(game: game, overview: overviews[game.slug],
                                         releaseYear: viewModel.releaseYear(for: game))
                                    .frame(height: 300)
                            }
                            .buttonStyle(.plain)
                            .id(game.slug)
                        }
                    }
                    if filtered.isEmpty {
                        ContentUnavailableView(Constants.noGamesFound, systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .pauseImageLoadingDuringScroll()
        }
        .searchable(text: $viewModel.search, prompt: Constants.searchGames)
        .navigationTitle(favoritesOnly ? Constants.favorites : Constants.library)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func libraryFilterLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.caption)
            Text(LocalizedStringKey(title))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .truncationMode(.tail)
            Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
        }
        .font(.caption.weight(.semibold))
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .padding(.horizontal, 5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .accessibilityLabel(title)
    }

}
