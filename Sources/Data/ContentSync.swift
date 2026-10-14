import SerenesParsing
import Foundation
import SwiftData
import Observation

@MainActor @Observable
final class ContentSync {
    private(set) var isSyncing = false
    private(set) var progress = ""
    private(set) var isFullSync = false
    private(set) var isNewsSyncing = false
    var errorMessage: String?
    var newsErrorMessage: String?

    private let context: ModelContext
    private let session: URLSession
    private let lastAttemptKey = "SerenesForest.lastSyncAttempt"
    private let lastNewsCheckKey = "SerenesForest.lastNewsCheck"
    private var stopRequested = false

    init(context: ModelContext) {
        self.context = context
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 120
        configuration.httpMaximumConnectionsPerHost = 1
        session = URLSession(configuration: configuration)
    }

    func stop() { stopRequested = true }

    func save(_ page: ContentPage) async {
        guard !isSyncing else { return }
        isSyncing = true
        stopRequested = false
        progress = "Saving \(page.title)"
        errorMessage = nil
        defer { isSyncing = false; progress = "" }
        do {
            let parsed = try await downloadPage(page)
            var knownPages = Set(try context.fetch(FetchDescriptor<ContentPage>()).map(\.url))
            var knownAssets = Set(try context.fetch(FetchDescriptor<ContentAsset>()).map(\.url))
            let discovered = ContentPageMapper.mapDiscoveredContent(parsed, from: page, knownPages: &knownPages, knownAssets: &knownAssets, allowedGameSlug: page.gameSlug)
            for item in discovered.pages { context.insert(item) }
            for item in discovered.assets { context.insert(item) }
            try context.save()
        } catch {
            errorMessage = error.localizedDescription
            try? context.save()
        }
    }

    func saveImages(for page: ContentPage) async {
        guard !isSyncing, page.isDownloaded, let source = URL(string: page.url) else { return }
        isSyncing = true
        stopRequested = false
        progress = "Saving images for \(page.title)"
        errorMessage = nil
        defer { isSyncing = false; progress = "" }
        let html = page.html
        let imageURLs = await Task.detached(priority: .utility) {
            Set(SiteHTML.parse(html, source: source).images.map(\.absoluteString))
        }.value
        do {
            let urls = Array(imageURLs)
            var assets: [String: ContentAsset] = [:]
            for start in stride(from: 0, to: urls.count, by: 200) {
                let batch = Array(urls[start..<min(start + 200, urls.count)])
                let descriptor = FetchDescriptor<ContentAsset>(predicate: #Predicate { batch.contains($0.url) })
                for asset in try context.fetch(descriptor) { assets[asset.url] = asset }
            }
            for url in urls where assets[url] == nil {
                let asset = ContentAsset(url: url, title: URL(string: url)?.lastPathComponent ?? "Image",
                                         sourcePageURL: page.url)
                context.insert(asset)
                assets[url] = asset
            }
            try context.save()
            let pending = assets.values.filter {
                isDue(fetchedAt: $0.fetchedAt, lastAttempt: $0.lastAttempt, now: .now)
            }
            for asset in pending where !stopRequested && !Task.isCancelled {
                do { try await downloadAsset(asset, preferArchive: true) }
                catch { errorMessage = error.localizedDescription }
            }
        } catch {
            errorMessage = error.localizedDescription
            try? context.save()
        }
    }

    func saveAllImages() async {
        guard !isSyncing else { return }
        isSyncing = true
        isFullSync = true
        stopRequested = false
        errorMessage = nil
        defer { isSyncing = false; isFullSync = false; progress = "" }
        do {
            let pages = try context.fetch(FetchDescriptor<ContentPage>()).filter(\.isDownloaded)
            var known = Set(try context.fetch(FetchDescriptor<ContentAsset>()).map(\.url))
            for (index, page) in pages.enumerated() where !stopRequested && !Task.isCancelled {
                guard let source = URL(string: page.url) else { continue }
                let html = page.html
                let images = await Task.detached(priority: .utility) {
                    SiteHTML.parse(html, source: source).images
                }.value
                for url in images {
                    let key = url.absoluteString
                    if known.insert(key).inserted {
                        context.insert(ContentAsset(url: key, title: url.lastPathComponent, sourcePageURL: page.url))
                    }
                }
                if index.isMultiple(of: 50) {
                    progress = "Indexing images \(index + 1)/\(pages.count)"
                    try context.save()
                    await Task.yield()
                }
            }
            try context.save()
            let pending = try context.fetch(FetchDescriptor<ContentAsset>()).filter {
                isDue(fetchedAt: $0.fetchedAt, lastAttempt: $0.lastAttempt, now: .now)
            }
            var failures = 0
            for (index, asset) in pending.enumerated() where !stopRequested && !Task.isCancelled {
                progress = "Saving images \(index + 1)/\(pending.count)"
                do { try await downloadAsset(asset, preferArchive: true) }
                catch { failures += 1; try? context.save() }
            }
            if failures > 0 { errorMessage = "\(failures) media files could not be added. Existing files remain in the library." }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sync(gameSlug: String? = nil, maxPages: Int? = nil) async {
        guard !isSyncing else { return }
        isSyncing = true
        isFullSync = maxPages == nil
        stopRequested = false
        if gameSlug == nil { UserDefaults.standard.set(Date(), forKey: lastAttemptKey) }
        errorMessage = nil
        defer { isSyncing = false; isFullSync = false; progress = "" }

        do {
            var pagesByURL = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<ContentPage>()).map { ($0.url, $0) })
            var failures = 0
            do {
                if let gameSlug,
                   Catalog.games.first(where: { $0.0 == gameSlug })?.3.hasPrefix("https://wiki.serenesforest.net/") == true {
                    failures += try await refreshWikiDates(gameSlug: gameSlug, pagesByURL: &pagesByURL)
                } else {
                    failures += try await refreshSitemaps(pagesByURL: &pagesByURL)
                }
            } catch {
                failures += 1
                errorMessage = error.localizedDescription
            }
            var pageQueue = pagesByURL.values.filter {
                (gameSlug == nil || $0.gameSlug == gameSlug) && $0.needsSitemapUpdate
            }
            pageQueue.sort { ($0.availableModifiedAt ?? .distantPast) > ($1.availableModifiedAt ?? .distantPast) }
            if pageQueue.isEmpty {
                if failures > 0 { errorMessage = "\(failures) sections could not be checked. \(errorMessage ?? "")" }
                return
            }
            var knownPages = Set(pagesByURL.keys)
            var knownAssets = Set(try context.fetch(FetchDescriptor<ContentAsset>()).map(\.url))
            let limit = maxPages ?? Int.max
            for (index, page) in pageQueue.prefix(limit).enumerated() {
                if stopRequested || Task.isCancelled { break }
                do {
                    progress = "Updating changed page \(index + 1)/\(pageQueue.count)"
                    let parsed = try await downloadPage(page)
                    let discovered = ContentPageMapper.mapDiscoveredContent(parsed, from: page, knownPages: &knownPages, knownAssets: &knownAssets, allowedGameSlug: gameSlug)
                    for item in discovered.pages { context.insert(item) }
                    for item in discovered.assets { context.insert(item) }
                    try context.save()
                } catch {
                    failures += 1
                    errorMessage = error.localizedDescription
                    try? context.save()
                    if shouldStop(after: error) { break }
                }
                if index + 1 < pageQueue.count { try? await Task.sleep(for: .seconds(1)) }
            }
            if failures == 0 { errorMessage = nil }
            else { errorMessage = "\(failures) items could not be updated. Existing articles remain in the library. \(errorMessage ?? "")" }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func syncIfNeeded() async {
        let lastAttempt = UserDefaults.standard.object(forKey: lastAttemptKey) as? Date ?? .distantPast
        if Date().timeIntervalSince(lastAttempt) > 24 * 60 * 60 { await sync(maxPages: 24) }
    }

    func syncNews(force: Bool = false) async {
        let checkInterval: TimeInterval = 15 * 60
        let lastCheck = UserDefaults.standard.object(forKey: lastNewsCheckKey) as? Date ?? .distantPast
        if !force && Date().timeIntervalSince(lastCheck) < checkInterval { return }

        // The launch sync shares this model context. Wait for it before checking News.
        while isSyncing && !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(250))
        }
        guard !Task.isCancelled else { return }
        let latestCheck = UserDefaults.standard.object(forKey: lastNewsCheckKey) as? Date ?? .distantPast
        if !force && Date().timeIntervalSince(latestCheck) < checkInterval { return }

        isSyncing = true
        isNewsSyncing = true
        stopRequested = false
        newsErrorMessage = nil
        defer { isSyncing = false; isNewsSyncing = false; progress = "" }

        do {
            var pagesByURL = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<ContentPage>()).map { ($0.url, $0) })
            let sitemapFailures = try await refreshSitemaps(pagesByURL: &pagesByURL, newsOnly: true)
            guard !Task.isCancelled && !stopRequested else { return }

            let pageQueue = pagesByURL.values
                .filter { $0.category == "News" && $0.url != SiteScope.home && ($0.needsSitemapUpdate || !$0.isDownloaded) }
                .sorted { ($0.availableModifiedAt ?? .distantPast) > ($1.availableModifiedAt ?? .distantPast) }
            var knownPages = Set(pagesByURL.keys)
            var knownAssets = Set(try context.fetch(FetchDescriptor<ContentAsset>()).map(\.url))
            var failures = sitemapFailures
            for (index, page) in pageQueue.enumerated() {
                if stopRequested || Task.isCancelled { break }
                do {
                    progress = "Updating news \(index + 1)/\(pageQueue.count)"
                    let parsed = try await downloadPage(page)
                    let discovered = ContentPageMapper.mapDiscoveredContent(parsed, from: page, knownPages: &knownPages, knownAssets: &knownAssets, allowedCategory: "News")
                    for item in discovered.pages { context.insert(item) }
                    for item in discovered.assets { context.insert(item) }
                    try context.save()
                } catch {
                    failures += 1
                    newsErrorMessage = error.localizedDescription
                    try? context.save()
                    if shouldStop(after: error) { break }
                }
                if index + 1 < pageQueue.count { try? await Task.sleep(for: .seconds(1)) }
            }
            if failures == 0 && !Task.isCancelled && !stopRequested {
                UserDefaults.standard.set(Date(), forKey: lastNewsCheckKey)
            } else if failures > 0 {
                newsErrorMessage = "\(failures) news items could not be updated. \(newsErrorMessage ?? "")"
            }
        } catch {
            newsErrorMessage = error.localizedDescription
        }
    }

    func syncGameNews(gameSlug: String, categoryURL: URL, pageNumber: Int = 1,
                      force: Bool = false) async throws -> Bool {
        guard Catalog.games.contains(where: { $0.0 == gameSlug }),
              categoryURL.scheme == "https", categoryURL.host == "serenesforest.net",
              categoryURL.path.hasPrefix("/category/"), (1...100).contains(pageNumber) else {
            throw URLError(.unsupportedURL)
        }
        let checkedKey = "SerenesForest.gameNewsChecked.\(gameSlug)"
        let hasMoreKey = "SerenesForest.gameNewsHasMore.\(gameSlug)"
        if pageNumber == 1, !force,
           let checked = UserDefaults.standard.object(forKey: checkedKey) as? Date,
           Date().timeIntervalSince(checked) < 15 * 60 {
            return UserDefaults.standard.bool(forKey: hasMoreKey)
        }

        while isSyncing && !Task.isCancelled {
            try await Task.sleep(for: .milliseconds(250))
        }
        try Task.checkCancellation()
        isSyncing = true
        progress = "Updating game news"
        defer { isSyncing = false; progress = "" }

        var components = URLComponents(url: categoryURL.appendingPathComponent("feed"), resolvingAgainstBaseURL: false)
        if pageNumber > 1 { components?.queryItems = [URLQueryItem(name: "paged", value: String(pageNumber))] }
        guard let feedURL = components?.url else { throw URLError(.unsupportedURL) }
        var request = URLRequest(url: feedURL)
        request.timeoutInterval = 20
        request.setValue("SerenesForestCompanion/1.0 (native game news feed)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              http.url?.host == "serenesforest.net" else { throw URLError(.badServerResponse) }
        if http.statusCode == 404 && pageNumber > 1 { return false }
        guard http.statusCode == 200 else { throw SiteHTTPError(status: http.statusCode) }
        guard data.count <= 5_000_000 else { throw URLError(.dataLengthExceedsMaximum) }
        let items = try await Task.detached(priority: .utility) { try GameNewsReader.parse(data) }.value
        guard !items.isEmpty || pageNumber > 1 else { throw URLError(.cannotParseResponse) }

        var known = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<ContentPage>(
            predicate: #Predicate { $0.category == "News" })).map { ($0.url, $0) })
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        for item in items {
            try Task.checkCancellation()
            guard let rawURL = URL(string: item.url.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let url = SiteScope.canonical(rawURL), SiteScope.isPage(url),
                  PageCategoryMapper.category(for: url).0 == "News" else { continue }
            let key = url.absoluteString
            let saved: ContentPage
            if let existing = known[key] {
                saved = existing
            } else {
                saved = ContentPage(url: key, title: item.title, gameSlug: nil, category: "News")
                context.insert(saved)
                known[key] = saved
            }
            var slugs = Set((saved.newsGameSlugs ?? "").split(separator: "|").map(String.init))
            slugs.insert(gameSlug)
            saved.newsGameSlugs = slugs.sorted().joined(separator: "|")
            saved.newsPublishedAt = formatter.date(from: item.published) ?? saved.newsPublishedAt
            let body = item.content.isEmpty ? item.summary : item.content
            let plain = SiteHTML.cleanText(body)
            if !plain.isEmpty && (!saved.isDownloaded || saved.plainText != plain) {
                let articleURL = key
                saved.nativeContent = try await Task.detached(priority: .utility) {
                    try JSONEncoder().encode(NativeArticleParser.parse(body, source: articleURL))
                }.value
                saved.title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                saved.html = body
                saved.plainText = plain
                saved.russianContent = nil
                saved.russianPlainText = nil
                saved.fetchedAt = .now
                saved.sourceModifiedAt = .now
                saved.isDownloaded = true
                saved.lastError = nil
            }
        }
        try context.save()
        let hasMore = items.count >= 10
        UserDefaults.standard.set(hasMore, forKey: hasMoreKey)
        if pageNumber == 1 { UserDefaults.standard.set(Date(), forKey: checkedKey) }
        if !items.isEmpty {
            let pageKey = "SerenesForest.gameNewsPages.\(gameSlug)"
            UserDefaults.standard.set(max(pageNumber, UserDefaults.standard.integer(forKey: pageKey)), forKey: pageKey)
        }
        return hasMore
    }

    private func isDue(fetchedAt: Date?, lastAttempt: Date?, now: Date) -> Bool {
        if let fetchedAt { return now.timeIntervalSince(fetchedAt) > 7 * 24 * 60 * 60 }
        if let lastAttempt { return now.timeIntervalSince(lastAttempt) > 24 * 60 * 60 }
        return true
    }

    private func shouldStop(after error: Error) -> Bool {
        if let httpError = error as? SiteHTTPError, [403, 429].contains(httpError.status) { return true }
        if let urlError = error as? URLError,
           [.timedOut, .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .userAuthenticationRequired].contains(urlError.code) { return true }
        return false
    }

    private func downloadPage(_ page: ContentPage) async throws -> ParsedPage {
        guard let rawURL = URL(string: page.url), let url = SiteScope.canonical(rawURL), SiteScope.isPage(url) else {
            throw URLError(.unsupportedURL)
        }
        page.lastAttempt = .now
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("SerenesForestCompanion/1.0 (personal reference library)", forHTTPHeaderField: "User-Agent")
        if let etag = page.etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        if let modified = page.lastModified { request.setValue(modified, forHTTPHeaderField: "If-Modified-Since") }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, SiteScope.canonical(http.url ?? url) != nil else { throw URLError(.badServerResponse) }
            if http.statusCode == 304 {
                page.fetchedAt = .now
                page.sourceModifiedAt = page.availableModifiedAt ?? page.sourceModifiedAt
                page.lastError = nil
                try context.save()
                return ParsedPage(title: page.title, html: page.html, plainText: page.plainText, links: [], images: [])
            }
            guard http.statusCode == 200 else { throw SiteHTTPError(status: http.statusCode) }
            guard data.count <= 5_000_000, let html = String(data: data, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
            let lowered = html.lowercased()
            if lowered.contains("please wait while your request is being verified") || lowered.contains("checking your browser before accessing") || lowered.contains("<title>just a moment") {
                throw URLError(.userAuthenticationRequired)
            }
            let pageURL = page.url
            let (parsed, nativeContent) = try await Task.detached(priority: .userInitiated) {
                let parsed = SiteHTML.parse(html, source: url)
                let nativeContent = try JSONEncoder().encode(NativeArticleParser.parse(parsed.html, source: pageURL))
                return (parsed, nativeContent)
            }.value
            guard !SiteHTML.isChallenge(title: parsed.title, html: html) else { throw URLError(.userAuthenticationRequired) }
            guard !parsed.plainText.isEmpty else { throw URLError(.cannotParseResponse) }
            ContentPageMapper.applyDownloadedPage(parsed, nativeContent: nativeContent, response: http, to: page)
            return parsed
        } catch {
            page.lastError = error.localizedDescription
            throw error
        }
    }

    private func downloadAsset(_ asset: ContentAsset, preferArchive: Bool = false) async throws {
        guard let rawURL = URL(string: asset.url), let url = SiteScope.canonical(rawURL), SiteScope.isAsset(url) else { throw URLError(.unsupportedURL) }
        asset.lastAttempt = .now
        let archive = URL(string: "https://web.archive.org/web/20261001id_/\(url.absoluteString)")!
        let candidates = url.host == "serenesforest.net"
            ? (preferArchive ? [archive, url] : [url, archive]) : [url]
        var lastError: Error = URLError(.resourceUnavailable)
        for candidate in candidates {
            if Task.isCancelled { throw CancellationError() }
            do {
                var request = URLRequest(url: candidate)
                request.timeoutInterval = candidate == url ? 15 : 30
                request.setValue("SerenesForestCompanion/1.0 (personal reference library)", forHTTPHeaderField: "User-Agent")
                let (file, response) = try await session.download(for: request)
                guard let http = response as? HTTPURLResponse,
                      let responseURL = http.url,
                      (candidate == url ? SiteScope.canonical(responseURL) != nil : responseURL.host == "web.archive.org") else {
                    throw URLError(.badServerResponse)
                }
                guard http.statusCode == 200 else { throw SiteHTTPError(status: http.statusCode) }
                guard let mime = response.mimeType, !mime.contains("html") else { throw URLError(.cannotDecodeContentData) }
                let size = (try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?.int64Value ?? 0
                guard size > 0 && size <= 100_000_000 else { throw URLError(.dataLengthExceedsMaximum) }
                asset.data = try await Task.detached(priority: .utility) {
                    try Data(contentsOf: file, options: .mappedIfSafe)
                }.value
                asset.mimeType = mime
                asset.fetchedAt = .now
                asset.lastError = nil
                try context.save()
                return
            } catch {
                lastError = error
            }
        }
        asset.lastError = lastError.localizedDescription
        throw lastError
    }

    private func refreshWikiDates(gameSlug: String, pagesByURL: inout [String: ContentPage]) async throws -> Int {
        let pages = pagesByURL.values.filter {
            $0.gameSlug == gameSlug && URL(string: $0.url)?.host == "wiki.serenesforest.net"
        }
        let formatter = ISO8601DateFormatter()
        var failures = 0
        for start in stride(from: 0, to: pages.count, by: 40) {
            if stopRequested || Task.isCancelled { break }
            let batch = Array(pages[start..<min(start + 40, pages.count)])
            let titles = batch.compactMap { page -> String? in
                guard let path = URL(string: page.url)?.path, path.hasPrefix("/index.php/") else { return nil }
                return String(path.dropFirst("/index.php/".count)).replacingOccurrences(of: "_", with: " ")
            }
            guard !titles.isEmpty else { continue }
            var components = URLComponents(string: "https://wiki.serenesforest.net/api.php")!
            components.queryItems = [
                URLQueryItem(name: "action", value: "query"),
                URLQueryItem(name: "prop", value: "info|revisions"),
                URLQueryItem(name: "inprop", value: "url"),
                URLQueryItem(name: "rvprop", value: "timestamp"),
                URLQueryItem(name: "format", value: "json"),
                URLQueryItem(name: "titles", value: titles.joined(separator: "|")),
            ]
            guard let url = components.url else { continue }
            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            progress = "Checking guide dates \(min(start + 40, pages.count))/\(pages.count)"
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      http.statusCode == 200, http.url?.host == "wiki.serenesforest.net",
                      let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let query = root["query"] as? [String: Any],
                      let revisions = query["pages"] as? [String: [String: Any]] else {
                    throw URLError(.badServerResponse)
                }
                for info in revisions.values {
                    guard let fullURL = info["fullurl"] as? String,
                          let rawURL = URL(string: fullURL),
                          let canonical = SiteScope.canonical(rawURL),
                          let page = pagesByURL[canonical.absoluteString],
                          let entries = info["revisions"] as? [[String: Any]],
                          let stamp = entries.first?["timestamp"] as? String,
                          let modified = formatter.date(from: stamp) else { continue }
                    page.availableModifiedAt = modified
                }
            } catch {
                failures += 1
                errorMessage = error.localizedDescription
            }
        }
        try context.save()
        return failures
    }

    private func refreshSitemaps(pagesByURL: inout [String: ContentPage], newsOnly: Bool = false) async throws -> Int {
        let indexURL = URL(string: "https://serenesforest.net/sitemap_index.xml")!
        progress = "Checking section dates"
        let index = try await fetchSitemap(indexURL)
        guard index.kind == .index else { throw URLError(.cannotParseResponse) }

        var sectionsByURL = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<SitemapSection>()).map { ($0.url, $0) })
        let baseline = sectionsByURL.values.compactMap(\.baselineAt).min()
            ?? pagesByURL.values.compactMap(\.fetchedAt).max()
            ?? .distantPast
        let entries = index.entries.compactMap { entry -> (URL, Date?)? in
            guard let url = SiteScope.canonical(entry.url),
                  url.lastPathComponent.range(of: newsOnly ? #"^post-sitemap[0-9]*\.xml$"# : #"^(post|page)-sitemap[0-9]*\.xml$"#, options: .regularExpression) != nil else { return nil }
            return (url, entry.modifiedAt)
        }
        var failures = 0
        for (index, entry) in entries.enumerated() {
            if stopRequested || Task.isCancelled { break }
            let sectionURL = entry.0.absoluteString
            let section = sectionsByURL[sectionURL] ?? SitemapSection(url: sectionURL)
            if let remoteDate = entry.1, let savedDate = section.modifiedAt, remoteDate <= savedDate { continue }
            progress = "Checking section \(index + 1)/\(entries.count)"
            do {
                let manifest = try await fetchSitemap(entry.0)
                guard manifest.kind == .pages else { throw URLError(.cannotParseResponse) }
                // Record every post date so a later full sync can use the same section checkpoint.
                for (pageIndex, item) in manifest.entries.enumerated() {
                    if stopRequested || Task.isCancelled { break }
                    if pageIndex.isMultiple(of: 100) { await Task.yield() }
                    guard let url = SiteScope.canonical(item.url), SiteScope.isPage(url) else { continue }
                    let key = url.absoluteString
                    let page: ContentPage
                    if let existing = pagesByURL[key] {
                        page = existing
                    } else {
                        guard let modifiedAt = item.modifiedAt, modifiedAt > baseline else { continue }
                        let (category, gameSlug) = PageCategoryMapper.category(for: url)
                        page = ContentPage(url: key, title: url.lastPathComponent.replacingOccurrences(of: "-", with: " "), gameSlug: gameSlug, category: category)
                        context.insert(page)
                        pagesByURL[key] = page
                    }
                    if let modifiedAt = item.modifiedAt {
                        if page.isDownloaded && page.sourceModifiedAt == nil && modifiedAt <= (page.fetchedAt ?? .distantPast) {
                            page.sourceModifiedAt = modifiedAt
                        }
                        if (page.isDownloaded || modifiedAt > baseline),
                           modifiedAt > (page.availableModifiedAt ?? .distantPast) {
                            page.availableModifiedAt = modifiedAt
                        }
                    }
                }
                if stopRequested || Task.isCancelled {
                    try context.save()
                    break
                }
                if sectionsByURL[sectionURL] == nil {
                    context.insert(section)
                    sectionsByURL[sectionURL] = section
                }
                section.modifiedAt = entry.1
                section.baselineAt = section.baselineAt ?? baseline
                try context.save()
            } catch {
                failures += 1
                errorMessage = error.localizedDescription
            }
        }
        return failures
    }

    private func fetchSitemap(_ url: URL) async throws -> SitemapManifest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              SiteScope.canonical(http.url ?? url) != nil,
              data.count <= 10_000_000 else { throw URLError(.badServerResponse) }
        return try await Task.detached(priority: .utility) {
            try SitemapManifest.parse(data)
        }.value
    }
}
