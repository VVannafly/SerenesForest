import SwiftUI

private enum Constants {
    static var readFullArticle: String { AppText.localized( "Read full article") }
    static var sourcePage: String { AppText.localized( "Source page") }
    static var aboutTheGame: String { AppText.localized( "About the Game") }
}

struct GameAboutView: View {
    let page: ContentPage
    @Environment(\.openURL) private var openURL

    private var theme: GameTheme { GameTheme.forGame(page.gameSlug ?? "") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let slug = page.gameSlug {
                    CachedBundleImage(name: slug, mode: .fit, maxPixelSize: 1200)
                        .aspectRatio(2.1, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                Text(AppText.title(page))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                if let overview = GameOverview(page: page) {
                    Text(overview.tagline)
                        .font(.headline)
                        .foregroundStyle(theme.accent)
                    Text(overview.story)
                        .font(.body)
                        .textSelection(.enabled)
                } else {
                    Text(AppText.isRussian ? (page.russianPlainText ?? page.plainText) : page.plainText)
                        .font(.body)
                        .textSelection(.enabled)
                }
                NavigationLink { PageDetailView(page: page) } label: {
                    Label(Constants.readFullArticle, systemImage: "text.book.closed")
                }
                .buttonStyle(.borderedProminent)
                Button {
                    if let url = URL(string: page.url) { openURL(url) }
                } label: {
                    Label(Constants.sourcePage, systemImage: "safari")
                }
                .buttonStyle(.bordered)
            }
            .padding(20)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(Constants.aboutTheGame)
        .tint(theme.accent)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
