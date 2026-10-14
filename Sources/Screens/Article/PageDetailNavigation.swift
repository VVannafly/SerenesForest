import SerenesParsing
import SwiftUI
import SwiftData

extension PageDetailView {
    func openOriginal() {
        if let url = URL(string: page.url) { openURL(url) }
    }

    func openLinkedContent(_ rawURL: URL) {
        if rawURL.host?.lowercased() == "fireemblemwiki.org" {
            var components = URLComponents(url: rawURL, resolvingAgainstBaseURL: false)
            components?.query = nil
            components?.fragment = nil
            if let canonical = components?.url?.absoluteString,
               let saved = try? context.fetch(FetchDescriptor<ContentPage>(
                predicate: #Predicate { $0.url == canonical })).first,
               saved.isDownloaded {
                viewModel.linkedPage = saved
                viewModel.showLinkedPage = true
                return
            }
        }
        guard let url = SiteScope.canonical(rawURL) else {
            viewModel.externalLink = rawURL
            viewModel.showExternalLinkPrompt = true
            return
        }
        let canonical = url.absoluteString
        if SiteScope.isAsset(url),
           let asset = try? context.fetch(FetchDescriptor<ContentAsset>(predicate: #Predicate { $0.url == canonical })).first,
           asset.fetchedAt != nil {
            viewModel.linkedAsset = asset
        } else if SiteScope.isPage(url),
                  let saved = try? context.fetch(FetchDescriptor<ContentPage>(predicate: #Predicate { $0.url == canonical })).first,
                  saved.isDownloaded {
            viewModel.linkedPage = saved
            viewModel.showLinkedPage = true
        } else {
            viewModel.externalLink = url
            viewModel.showExternalLinkPrompt = true
        }
    }

}
