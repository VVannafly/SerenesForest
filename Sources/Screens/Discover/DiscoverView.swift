import SwiftUI
import SwiftData

private enum Constants {
    static let shieldArtwork = "ShieldOfFlames"
    static var russianTitle: String { AppText.localized( "Библиотека\nFire Emblem") }
    static var compactTitle: String { AppText.localized( "Fire Emblem\nLibrary") }
    static var expandedTitle: String { AppText.localized( "Your Fire Emblem\nreference library.") }
    static func articleCount(_ count: Int, russian: Bool, compact: Bool) -> String {
        if russian { return "\(count) СТАТЕЙ" }
        return compact ? "\(count) ARTICLES" : "FIRE EMBLEM LIBRARY · \(count) ARTICLES"
    }
    static let gamesAcrossGenerationsCount = (english: "games across generations", russian: ("игра разных поколений", "игры разных поколений", "игр разных поколений"))
    static var browseGuidesNewsAndArtwork: String { AppText.localized( "Browse guides, news, and artwork. Check for new and changed pages whenever you choose.") }
    static var addMissingMedia: String { AppText.localized( "Add missing media") }
    static var latestUpdates: String { AppText.localized( "Latest updates") }
    static var recentArticlesInYourLibrary: String { AppText.localized( "Recent articles in your library") }
    static var noNewsArticlesYet: String { AppText.localized( "No news articles yet") }
    static var checkUpdatesToAddRecent: String { AppText.localized( "Check updates to add recent posts.") }
    static var exploreTheSeries: String { AppText.localized( "Explore the series") }
    static var discover: String { AppText.localized( "Discover") }
}

struct DiscoverView: View {
    var sync: ContentSync
    @State private var viewModel = DiscoverViewModel()
    @Query(sort: \Game.title) private var games: [Game]
    @Query(filter: #Predicate<ContentPage> { $0.category == "Game" }) private var overviewPages: [ContentPage]
    @Query(filter: #Predicate<ContentPage> { $0.category == "News" }) private var newsPages: [ContentPage]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var availableGames: [Game] { viewModel.availableGames(from: games) }

    private var latestNews: [ContentPage] {
        viewModel.latestNews(from: newsPages)
    }

    var body: some View {
        let overviews = viewModel.overviews(for: availableGames, pages: overviewPages)
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(LinearGradient(colors: [Palette.ink, Palette.accent, Color(red: 0.26, green: 0.63, blue: 0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(Constants.shieldArtwork)
                        .resizable()
                        .scaledToFit()
                        .frame(width: sizeClass == .compact ? 190 : 310,
                               height: sizeClass == .compact ? 190 : 310)
                        .opacity(0.94)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .offset(x: sizeClass == .compact ? 22 : 0)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: sizeClass == .compact ? 8 : 12) {
                        Text(Constants.articleCount(viewModel.downloadedArticleCount,
                                                    russian: AppText.isRussian, compact: sizeClass == .compact))
                            .font(.caption.bold()).tracking(sizeClass == .compact ? 1.2 : 2.4)
                            .foregroundStyle(Palette.soft)
                        Text(AppText.isRussian ? Constants.russianTitle :
                             sizeClass == .compact ? Constants.compactTitle : Constants.expandedTitle)
                            .font(.system(size: sizeClass == .compact ? 29 : 38, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        if sizeClass != .compact {
                            Text(Constants.browseGuidesNewsAndArtwork)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.82))
                                .frame(maxWidth: 430, alignment: .leading)
                        }
                        Button { Task { await viewModel.saveAllImages(using: sync) } } label: {
                            Label(Constants.addMissingMedia, systemImage: "arrow.down.circle.fill")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 18).padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Palette.ink)
                        .background(.white, in: Capsule())
                        .disabled(sync.isSyncing)
                    }
                    .padding(sizeClass == .compact ? 20 : 28)
                }
                .frame(height: sizeClass == .compact ? 220 : 300)
                .clipShape(RoundedRectangle(cornerRadius: 28))

                sectionHeading(Constants.latestUpdates, subtitle: Constants.recentArticlesInYourLibrary)
                if latestNews.isEmpty {
                    ContentUnavailableView(Constants.noNewsArticlesYet, systemImage: "newspaper", description: Text(Constants.checkUpdatesToAddRecent))
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(latestNews) { page in
                        NavigationLink { PageDetailView(page: page) } label: { PageRow(page: page) }
                            .buttonStyle(.plain)
                    }
                }

                HStack {
                    sectionHeading(Constants.exploreTheSeries, subtitle: AppText.count(availableGames.count, english: Constants.gamesAcrossGenerationsCount.english, russian: Constants.gamesAcrossGenerationsCount.russian))
                    Spacer()
                }
                ScrollView(.horizontal) {
                    HStack(spacing: 14) {
                        ForEach(viewModel.featuredGames(from: availableGames)) { game in
                            NavigationLink { GameDetailView(game: game) } label: {
                                GameCard(game: game, overview: overviews[game.slug])
                                    .frame(width: 190, height: 300)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
            .padding(24)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image(Constants.shieldArtwork)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .accessibilityHidden(true)
                    Text(Constants.discover).font(.headline)
                }
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task(id: sync.isSyncing) { viewModel.refreshArticleCount(in: modelContext) }
    }

}
