import SwiftUI
import Observation
#if os(iOS)
import UIKit
#endif

private enum Constants {
    static var serenesForest: String { AppText.localized( "Serenes Forest") }
    static var stopAfterCurrentItem: String { AppText.localized( "Stop after current item") }
    static var checkUpdates: String { AppText.localized( "Check updates") }
    static var addMissingMedia: String { AppText.localized( "Add missing media") }
    static var update: String { AppText.localized( "Update") }
    static var checkSitemapDatesAndUpdate: String { AppText.localized( "Check sitemap dates and update changed pages") }
    static var dismiss: String { AppText.localized( "Dismiss") }
}

struct RootView: View {
    var sync: ContentSync
    @State var viewModel = RootViewModel()
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
        NavigationSplitView {
            List(Destination.allCases, id: \.self, selection: $viewModel.selected) { destination in
                Label(LocalizedStringKey(destination.rawValue), systemImage: destination.symbol)
                    .tag(destination)
            }
            .navigationTitle(Constants.serenesForest)
            .listStyle(.sidebar)
        } detail: {
            NavigationStack {
                Group {
                    switch viewModel.selected ?? .discover {
                    case .discover:
                        DiscoverView(sync: sync)
                    case .library: GamesView(favoritesOnly: false)
                    case .favorites: GamesView(favoritesOnly: true)
                    case .savedPages: SavedPagesView()
                    case .news: NewsView()
                    case .guides: GuidesView()
                    case .wiki: WikiLibraryView()
                    case .allPages: AllPagesView()
                    case .media: MediaView()
                    case .settings: SettingsView()
                    }
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
            #if os(iOS)
            .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
        }
        .tint(Palette.accent)
        .environment(sync)
        .environment(\.locale, Locale(identifier: language))
        .preferredColorScheme(colorScheme)
        .task { await sync.syncIfNeeded() }
    }
}
