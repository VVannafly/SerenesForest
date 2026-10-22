import SwiftUI
import SerenesNavigation
import Observation
import SwiftData

private enum Constants {
    static let pagesCount = (english: "pages", russian: ("страница", "страницы", "страниц"))
    static var guides: String { AppText.localized( "Guides") }
    static var noGuidesFound: String { AppText.localized( "No guides found") }
    static var checkUpdatesToAddNew: String { AppText.localized( "Check updates to add new guides.") }
    static var searchGuides: String { AppText.localized( "Search guides") }
    static var showMore: String { AppText.localized("Show more") }
}

struct GuidesView: View {
    @State var viewModel = GuidesViewModel()
    @Query(filter: #Predicate<ContentPage> { $0.category == "Guide" }) private var allGuides: [ContentPage]
    @SceneStorage("SerenesForest.guidesScroll") private var scrollAnchor: String?

    private var games: [GuideGame] { viewModel.games(from: allGuides) }

    private func gameExpansion(_ slug: String) -> Binding<Bool> {
        Binding(get: {
            viewModel.isGameExpanded(slug)
        }, set: { viewModel.setGameExpanded($0, slug: slug) })
    }

    private func topicExpansion(_ id: String) -> Binding<Bool> {
        Binding(get: {
            viewModel.isTopicExpanded(id)
        }, set: { viewModel.setTopicExpanded($0, id: id) })
    }

    var body: some View {
        let groups = games
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                sectionHeading(Constants.guides, subtitle: AppText.count(viewModel.pageCount(in: groups),
                    english: Constants.pagesCount.english, russian: Constants.pagesCount.russian))
                ForEach(groups) { game in
                    DisclosureGroup(isExpanded: gameExpansion(game.slug)) {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(game.topics) { topic in
                                let topicID = "\(game.slug)|\(topic.id)"
                                DisclosureGroup(isExpanded: topicExpansion(topicID)) {
                                    LazyVStack(alignment: .leading, spacing: 8) {
                                        ForEach(viewModel.visiblePages(in: topic, id: topicID)) { page in
                                            NavigationLink(value: PageRoute.article(page.url)) { PageRow(page: page) }
                                                .buttonStyle(.plain)
                                                .id(page.url)
                                        }
                                        if viewModel.hasMorePages(in: topic, id: topicID) {
                                            Button(Constants.showMore) { viewModel.showMorePages(id: topicID) }
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                        }
                                    }
                                    .padding(.top, 8)
                                } label: {
                                    HStack(spacing: 9) {
                                        Image(systemName: viewModel.topicSymbol(topic.title))
                                            .frame(width: 20)
                                        Text(LocalizedStringKey(topic.title)).font(.subheadline.weight(.semibold))
                                        Spacer(minLength: 8)
                                        Text("\(topic.pages.count)").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .padding(12)
                                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.top, 10)
                    } label: {
                        HStack(spacing: 12) {
                            CachedBundleImage(name: game.slug, mode: .fill, maxPixelSize: 120)
                                .frame(width: 42, height: 42)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                            Text(game.title).font(.headline)
                            Spacer(minLength: 8)
                            Text("\(game.count)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .id("guide-game-\(game.slug)")
                }
                if groups.isEmpty {
                    ContentUnavailableView(Constants.noGuidesFound, systemImage: "text.book.closed", description: Text(Constants.checkUpdatesToAddNew))
                }
            }
            .scrollTargetLayout()
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .pauseImageLoadingDuringScroll()
        .scrollPosition(id: $scrollAnchor)
        .searchable(text: $viewModel.search, prompt: Constants.searchGuides)
        .onChange(of: viewModel.search) { _, _ in
            viewModel.resetSearchExpansion()
            scrollAnchor = nil
        }
        .navigationTitle(Constants.guides)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
