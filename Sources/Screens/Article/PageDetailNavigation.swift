import SwiftUI

extension PageDetailView {
    func openOriginal() {
        if let url = URL(string: page.url) { openURL(url) }
    }

    func openLinkedContent(_ rawURL: URL) {
        switch viewModel.destination(for: rawURL, in: context) {
        case .article(let url):
            navigator.openArticle(url)
        case .asset(let asset):
            viewModel.linkedAsset = asset
        case .external(let url):
            viewModel.externalLink = url
            viewModel.showExternalLinkPrompt = true
        }
    }

}
