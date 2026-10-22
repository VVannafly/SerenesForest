import SwiftUI
import Observation
import SerenesNavigation
import SwiftData
#if os(iOS)
import UIKit
#endif

private enum Constants {
    static var discovery: String { AppText.localized("Discovery") }
    static var library: String { AppText.localized("Library") }
    static var favourites: String { AppText.localized("Favourites") }
    static var menu: String { AppText.localized("Menu") }
    static var stopAfterCurrentItem: String { AppText.localized("Stop after current item") }
    static var checkUpdates: String { AppText.localized("Check updates") }
    static var addMissingMedia: String { AppText.localized("Add missing media") }
    static var update: String { AppText.localized("Update") }
    static var checkSitemapDatesAndUpdate: String { AppText.localized("Check sitemap dates and update changed pages") }
    static var dismiss: String { AppText.localized("Dismiss") }
    static var articleNotInLibrary: String { AppText.localized("Article not in library") }
}

struct RootView: View {
    var sync: ContentSync
    @State var viewModel = RootViewModel()
    @State private var discoveryNavigator = PageNavigator()
    @State private var libraryNavigator = PageNavigator()
    @State private var favouritesNavigator = PageNavigator()
    @State private var menuNavigator = PageNavigator()
    @Environment(\.modelContext) private var context
    @AppStorage("SerenesForest.language") private var language = "en"
    @AppStorage("SerenesForest.appearance") private var appearance = "system"

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    var body: some View {
        TabView(selection: $viewModel.selected) {
            Tab(Constants.discovery, systemImage: Destination.discover.symbol, value: Destination.discover) {
                navigationStack(for: .discover, navigator: discoveryNavigator)
            }
            Tab(Constants.library, systemImage: Destination.library.symbol, value: Destination.library) {
                navigationStack(for: .library, navigator: libraryNavigator)
            }
            Tab(Constants.favourites, systemImage: Destination.favorites.symbol, value: Destination.favorites) {
                navigationStack(for: .favorites, navigator: favouritesNavigator)
            }
            Tab(Constants.menu, systemImage: Destination.menu.symbol, value: Destination.menu) {
                navigationStack(for: .menu, navigator: menuNavigator)
            }
        }
        .tint(Palette.accent)
        .environment(sync)
        .environment(\.locale, Locale(identifier: language))
        .preferredColorScheme(colorScheme)
        .task { await sync.syncIfNeeded() }
    }

    private func navigationStack(for tab: Destination, navigator: PageNavigator) -> some View {
        @Bindable var navigator = navigator
        return NavigationStack(path: $navigator.path) {
            destinationView(tab)
                .navigationDestination(for: PageRoute.self) { route in
                    routeView(route)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            if sync.isSyncing {
                                Button(Constants.stopAfterCurrentItem, systemImage: "stop.circle") { sync.stop() }
                            } else {
                                Button(Constants.checkUpdates, systemImage: "arrow.clockwise") { Task { await sync.sync() } }
                                Button(Constants.addMissingMedia, systemImage: "photo.on.rectangle.angled") { Task { await sync.saveAllImages() } }
                            }
                        } label: {
                            if sync.isSyncing { ProgressView() }
                            else { Label(Constants.update, systemImage: "arrow.clockwise") }
                        }
                        .help(Constants.checkSitemapDatesAndUpdate)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if sync.isSyncing || sync.errorMessage != nil {
                        HStack(spacing: 10) {
                            Image(systemName: sync.errorMessage == nil ? "arrow.triangle.2.circlepath" : "exclamationmark.triangle")
                            Text(sync.errorMessage ?? sync.progress)
                                .font(.caption)
                                .lineLimit(2)
                            Spacer()
                            if sync.errorMessage != nil {
                                Button(Constants.dismiss) { sync.errorMessage = nil }
                                    .font(.caption)
                            }
                        }
                        .padding(12)
                        .background(.regularMaterial)
                    }
                }
        }
        .environment(navigator)
        #if os(iOS)
        .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
    }

    @ViewBuilder private func destinationView(_ destination: Destination) -> some View {
        switch destination {
        case .discover: DiscoverView(sync: sync)
        case .library: GamesView(favoritesOnly: false)
        case .favorites: GamesView(favoritesOnly: true)
        case .menu: menuPage
        case .savedPages: SavedPagesView()
        case .news: NewsView()
        case .guides: GuidesView()
        case .wiki: WikiLibraryView()
        case .allPages: AllPagesView()
        case .media: MediaView()
        case .settings: SettingsView()
        }
    }

    private var menuPage: some View {
        List(Destination.menuItems, id: \.self) { destination in
            NavigationLink(value: PageRoute.menu(destination.rawValue)) {
                Label(LocalizedStringKey(destination.rawValue), systemImage: destination.symbol)
            }
        }
        .navigationTitle(Constants.menu)
    }

    @ViewBuilder private func routeView(_ route: PageRoute) -> some View {
        switch route {
        case .article(let url):
            if let page = viewModel.page(at: url, in: context) {
                PageDetailView(page: page)
            } else { missingPage }
        case .game(let slug):
            if let game = viewModel.game(slug: slug, in: context) {
                GameDetailView(game: game)
            } else { missingPage }
        case .gameAbout(let url):
            if let page = viewModel.page(at: url, in: context) {
                GameAboutView(page: page)
            } else { missingPage }
        case .gameLink(let title, let rawURL, let slug):
            if let url = URL(string: rawURL) {
                GameLinkView(title: title, url: url, gameSlug: slug,
                             pages: viewModel.pages(gameSlug: slug, in: context),
                             tint: GameTheme.forGame(slug).accent)
            } else { missingPage }
        case .topicItems(let data, let slug):
            if let item = viewModel.item(from: data) {
                GameTopicItemsView(item: item, pages: viewModel.pages(gameSlug: slug, in: context),
                                   tint: GameTheme.forGame(slug).accent)
            } else { missingPage }
        case .topicLinks(let data, let slug):
            if let item = viewModel.item(from: data) {
                GameTopicLinksView(item: item, pages: viewModel.pages(gameSlug: slug, in: context),
                                   tint: GameTheme.forGame(slug).accent)
            } else { missingPage }
        case .newsFeed(let slug, let rawURL):
            if let url = URL(string: rawURL) {
                GameNewsFeedView(gameSlug: slug, categoryURL: url)
            } else { missingPage }
        case .artwork(let title, let rawURL):
            if let url = URL(string: rawURL) {
                GameArtworkView(title: title, sourceURL: url)
            } else { missingPage }
        case .asset(let url):
            if let asset = viewModel.asset(at: url, in: context) {
                AssetDetailView(asset: asset)
            } else { missingPage }
        case .menu(let name):
            if let destination = Destination(rawValue: name), Destination.menuItems.contains(destination) {
                destinationView(destination)
            } else { missingPage }
        }
    }

    private var missingPage: some View {
        ContentUnavailableView(Constants.articleNotInLibrary, systemImage: "doc.text")
    }
}
