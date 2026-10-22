import SerenesParsing
import Foundation

private enum Constants {
    static let news = "News"
}

enum ContentPageMapper {
    static func publishedAt(_ page: ContentPage) -> Date? {
        guard page.category == Constants.news else { return nil }
        let date = page.newsPublishedAt ?? newsDate(page)
        return date == .distantPast ? nil : date
    }

    static func newsDate(_ page: ContentPage) -> Date {
        let parts = URL(string: page.url)?.pathComponents ?? []
        if parts.count >= 4,
           let year = Int(parts[1]), let month = Int(parts[2]), let day = Int(parts[3]) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? (page.fetchedAt ?? .distantPast)
        }
        return page.fetchedAt ?? .distantPast
    }

    static func mapDiscoveredContent(
        _ parsed: ParsedPage,
        from page: ContentPage,
        knownPages: inout Set<String>,
        knownAssets: inout Set<String>,
        allowedGameSlug: String? = nil,
        allowedCategory: String? = nil
    ) -> (pages: [ContentPage], assets: [ContentAsset]) {
        var pages: [ContentPage] = []
        var assets: [ContentAsset] = []
        for link in parsed.links {
            let url = link.url.absoluteString
            if SiteScope.isAsset(link.url) {
                if knownAssets.insert(url).inserted {
                    let asset = ContentAsset(url: url, title: link.title, sourcePageURL: page.url)
                    assets.append(asset)
                }
            } else if SiteScope.isPage(link.url) {
                let (category, slug) = PageCategoryMapper.category(for: link.url)
                let wikiRoot = page.category == "Game" && URL(string: page.url)?.host == "wiki.serenesforest.net"
                let assignedSlug = slug ?? (wikiRoot ? allowedGameSlug : nil)
                guard allowedGameSlug == nil || assignedSlug == allowedGameSlug else { continue }
                guard allowedCategory == nil || category == allowedCategory else { continue }
                guard knownPages.insert(url).inserted else { continue }
                let discovered = ContentPage(url: url, title: link.title, gameSlug: assignedSlug, category: category)
                pages.append(discovered)
            }
        }
        for image in parsed.images where knownAssets.insert(image.absoluteString).inserted {
            let asset = ContentAsset(url: image.absoluteString, title: image.lastPathComponent, sourcePageURL: page.url)
            assets.append(asset)
        }
        return (pages, assets)
    }

    static func applyDownloadedPage(
        _ parsed: ParsedPage,
        nativeContent: Data,
        response: HTTPURLResponse,
        to page: ContentPage
    ) {
        page.title = parsed.title
        page.html = parsed.html
        page.plainText = parsed.plainText
        page.nativeContent = nativeContent
        page.russianContent = nil
        page.russianDraft = nil
        page.russianTitle = nil
        page.russianPlainText = nil
        page.russianNavigation = nil
        page.fetchedAt = .now
        page.sourceModifiedAt = page.availableModifiedAt ?? page.sourceModifiedAt
        page.etag = response.value(forHTTPHeaderField: "ETag")
        page.lastModified = response.value(forHTTPHeaderField: "Last-Modified")
        page.isDownloaded = true
        page.lastError = nil
    }
}
