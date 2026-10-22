import SwiftUI
import SerenesNavigation
import Observation
import SwiftData
import Translation

private enum Constants {
    static let sectionsCount = (english: "sections", russian: ("раздел", "раздела", "разделов"))
    static let articlesCount = (english: "articles", russian: ("статья", "статьи", "статей"))
    static var route: String { AppText.localized( "Route") }
    static var gameGuide: String { AppText.localized( "Game guide") }
    static var fireEmblemWiki: String { AppText.localized( "Fire Emblem Wiki") }
}

struct GameDetailView: View {
    @State var viewModel = GameDetailViewModel()
    @Bindable var game: Game
    @AppStorage("SerenesForest.language") var language = "en"
    @AppStorage(RecentGamesHistory.storageKey) private var recentGameSlugs = ""
    @Environment(\.modelContext) var context
    @Environment(ContentSync.self) var sync: ContentSync
    @Query var pages: [ContentPage]
    @Query var wikiMemberships: [WikiGamePage]
    @Query(filter: #Predicate<ContentPage> { $0.category == "General" || $0.category == "Media" })
    private var sharedPages: [ContentPage]
    @Environment(\.openURL) var openURL
    @SceneStorage var expandedSectionID: Int

    init(game: Game) {
        self.game = game
        _expandedSectionID = SceneStorage(wrappedValue: -1, "SerenesForest.expanded.\(game.slug)")
        let slug = game.slug
        _pages = Query(filter: #Predicate<ContentPage> { $0.gameSlug == slug })
        _wikiMemberships = Query(filter: #Predicate<WikiGamePage> { $0.gameSlug == slug })
    }

    var overview: GameOverview? { viewModel.overview(for: game, pages: pages) }

    var progress: GameProgress { GameProgress(status: game.status) }
    var theme: GameTheme { GameTheme.forGame(game.slug) }
    var visibleSections: [GameNavigationSection] { viewModel.visibleSections(gameSlug: game.slug) }

    var navigationSourceTexts: [String] { viewModel.navigationSourceTexts }

    var body: some View {
        let home = viewModel.homePage(for: game, pages: pages)
        let wikiSections = viewModel.wikiSections(pages: pages, memberships: wikiMemberships,
                                                  gameSlug: game.slug)
        let wikiCount = viewModel.wikiArticleCount(in: wikiSections)
        let sectionRows = viewModel.sectionRows(gameSlug: game.slug)
        let navigationPages = pages + sharedPages
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                gameHero
                if viewModel.hasRoutes(for: game) {
                    Picker(Constants.route, selection: $viewModel.selectedFatesRoute) {
                        ForEach(FatesRoute.allCases) { route in
                            Text(LocalizedStringKey(route.rawValue)).tag(route)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.selectedFatesRoute) { _, _ in expandedSectionID = -1 }
                }
                sectionHeading(Constants.gameGuide, subtitle: AppText.count(visibleSections.count, english: Constants.sectionsCount.english, russian: Constants.sectionsCount.russian))
                LazyVStack(spacing: 12) {
                    ForEach(sectionRows.indices, id: \.self) { rowIndex in
                        let row = sectionRows[rowIndex]
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(0..<viewModel.sectionColumnCount, id: \.self) { column in
                                if column < row.count {
                                    sectionCard(row[column])
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Color.clear.frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .id("guide-\(rowIndex)")
                        if let expanded = viewModel.expandedSection(in: row, id: expandedSectionID) {
                            let style = GameSection.style(for: expanded.title)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(LocalizedStringKey(viewModel.navigationTranslations[expanded.title] ?? expanded.title))
                                    .font(.headline)
                                    .foregroundStyle(theme.color(for: style))
                                    .padding(.horizontal, 8)
                                VStack(spacing: 3) {
                                    ForEach(expanded.items) { item in
                                        GameNavigationRow(item: item, pages: navigationPages,
                                                          tint: theme.color(for: style))
                                    }
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(theme.color(for: style).opacity(0.22)) }
                        }
                    }
                }
                if !wikiSections.isEmpty {
                    sectionHeading(Constants.fireEmblemWiki, subtitle: AppText.count(wikiCount, english: Constants.articlesCount.english, russian: Constants.articlesCount.russian))
                    ForEach(wikiSections) { section in
                        DisclosureGroup(isExpanded: Binding(
                            get: { viewModel.expandedWikiGroups.contains(section.title) },
                            set: { expanded in
                                if expanded { viewModel.expandedWikiGroups.insert(section.title) }
                                else { viewModel.expandedWikiGroups.remove(section.title) }
                            }
                        )) {
                            LazyVStack(spacing: 8) {
                                ForEach(section.entries) { entry in
                                    NavigationLink(value: PageRoute.article(entry.page.url)) {
                                        PageRow(page: entry.page, chapterLabel: entry.label)
                                    }
                                        .buttonStyle(.plain)
                                        .id(entry.page.url)
                                }
                            }
                            .padding(.top, 10)
                        } label: {
                            HStack {
                                Text(LocalizedStringKey(section.title.replacingOccurrences(of: "Wiki · ", with: "")))
                                    .font(.headline)
                                Spacer()
                                Text("\(section.entries.count)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 850)
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.width
            } action: { width in
                viewModel.guideWidth = width
            }
            .frame(maxWidth: .infinity)
        }
        .pauseImageLoadingDuringScroll()
        .environment(\.navigationTranslations, viewModel.navigationTranslations)
        .background {
            if TranslationAvailability.isSupported,
               language == "ru", !viewModel.sections.isEmpty,
               viewModel.navigationTranslations.count < navigationSourceTexts.count {
                Color.clear.translationTask(source: Locale.Language(identifier: "en"),
                                            target: Locale.Language(identifier: "ru")) { session in
                    await viewModel.translateNavigation(using: session, home: home, context: context, language: language)
                }
            }
        }
        .navigationTitle("")
        .onAppear {
            recentGameSlugs = RecentGamesHistory.record(game.slug, in: recentGameSlugs)
        }
        .tint(theme.accent)
        .toolbar {
            if let home {
                ToolbarItem(placement: .primaryAction) { BookmarkButton(page: home) }
            }
        }
        .task(id: home?.fetchedAt) {
            guard let home else { return }
            await viewModel.loadNavigation(home: home, gameSlug: game.slug, language: language)
        }
        .onChange(of: language) { _, value in
            viewModel.restoreNavigation(home: home, language: value)
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

}
