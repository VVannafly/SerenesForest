import SwiftUI
import Observation
import SerenesNavigation
import SwiftData
import Translation

private enum Constants {
    static var openLinkInBrowser: String { AppText.localized( "Open link in browser?") }
    static var openParentSection: String { AppText.localized( "Open a parent section") }
    static var openInBrowser: String { AppText.localized( "Open in browser") }
    static var addImages: String { AppText.localized( "Add images") }
    static var preparingArticle: String { AppText.localized( "Preparing article") }
    static var articleNotInLibrary: String { AppText.localized( "Article not in library") }
    static var addThisArticleToThe: String { AppText.localized( "Add this article to the library or open its source page.") }
    static var addArticle: String { AppText.localized( "Add article") }
    static var openSourcePage: String { AppText.localized( "Open source page") }
}

struct PageDetailView: View {
    @State var viewModel = PageDetailViewModel()
    let page: ContentPage
    @AppStorage("SerenesForest.language") var language = "en"
    @Environment(ContentSync.self) var sync: ContentSync
    @Environment(PageNavigator.self) var navigator: PageNavigator
    @Environment(\.navigationTranslations) var navigationTranslations
    @Environment(\.openURL) var openURL
    @Environment(\.modelContext) var context

    var articleTint: Color {
        viewModel.articleTint(for: page)
    }

    var gameShortTitle: String? {
        viewModel.gameShortTitle(for: page)
    }

    var articleTrail: [ArticleTrailTarget] {
        viewModel.articleTrail(for: page, translations: navigationTranslations)
    }

    var trailLabel: String {
        viewModel.trailLabel(for: page, translations: navigationTranslations)
    }

    var body: some View {
        Group {
            if language == "ru", TranslationAvailability.isSupported,
               viewModel.articleBlocks != nil, page.russianContent == nil {
                articleContent.translationTask(source: Locale.Language(identifier: "en"),
                                               target: Locale.Language(identifier: "ru")) { session in
                    await viewModel.translateArticle(using: session, page: page, context: context, language: language)
                }
            } else {
                articleContent
            }
        }
        .navigationTitle("")
        .tint(articleTint)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $viewModel.linkedAsset) { AssetDetailView(asset: $0) }
        .confirmationDialog(Constants.openLinkInBrowser, isPresented: $viewModel.showExternalLinkPrompt) {
            Button { if let externalLink = viewModel.externalLink { openURL(externalLink) } } label: {
                Label(Constants.openInBrowser, systemImage: "safari")
            }
        } message: {
            Text(viewModel.externalLink?.absoluteString ?? "")
        }
        .task(id: "\(language)-\(page.fetchedAt?.timeIntervalSince1970 ?? 0)") {
            await viewModel.prepareArticle(page: page, context: context, language: language)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                BookmarkButton(page: page)
            }
            if gameShortTitle != nil {
                ToolbarItem(placement: .principal) {
                    Menu {
                        ForEach(articleTrail) { target in
                            Button(target.title) {
                                guard let slug = page.gameSlug else { return }
                                if let url = target.url {
                                    navigator.returnToAncestor(.gameLink(title: target.title,
                                                                         url: url.absoluteString, slug: slug))
                                } else {
                                    navigator.returnToAncestor(.game(slug))
                                }
                            }
                        }
                    } label: {
                        VStack(spacing: 1) {
                            Text(gameShortTitle ?? "")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 3) {
                                Text(trailLabel)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: 240)
                    }
                    .accessibilityLabel("\(gameShortTitle ?? ""), \(trailLabel)")
                    .accessibilityHint(Constants.openParentSection)
                }
            }
            if page.isDownloaded && (!page.category.hasPrefix("Wiki · ") || !viewModel.imageURLs.isEmpty) {
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await sync.saveImages(for: page); await viewModel.loadArticleAssets(context: context) } } label: {
                        Label(Constants.addImages, systemImage: "square.and.arrow.down")
                    }
                    .disabled(sync.isSyncing)
                }
            }
        }
    }

    var articleContent: some View {
        Group {
            if page.isDownloaded {
                if let articleBlocks = viewModel.presentationBlocks {
                    VStack(spacing: 0) {
                    if let translationProgress = viewModel.translationProgress {
                        HStack(spacing: 8) { ProgressView(); Text(translationProgress) }
                            .font(.caption).frame(maxWidth: .infinity).padding(8)
                    }
                    if let translationError = viewModel.translationError {
                        Text(translationError).font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity).padding(8)
                    }
                    SavedArticleView(title: viewModel.translatedTitle ?? page.title, category: page.category, tint: articleTint,
                                     blocks: articleBlocks, assets: viewModel.articleAssets, onSource: openOriginal, onLink: openLinkedContent)
                    }
                } else {
                    ProgressView(Constants.preparingArticle)
                }
            } else {
                ContentUnavailableView {
                    Label(Constants.articleNotInLibrary, systemImage: "arrow.down.circle")
                } description: {
                    Text(Constants.addThisArticleToThe)
                } actions: {
                    Button(Constants.addArticle) { Task { await sync.save(page) } }
                        .disabled(sync.isSyncing)
                    Button(action: openOriginal) { Label(Constants.openSourcePage, systemImage: "safari") }
                }
            }
        }
    }

}
