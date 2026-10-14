import SerenesParsing
import Foundation
import SwiftData
import CryptoKit

enum Catalog {
    private static var buildContentDirectory: URL? {
        ProcessInfo.processInfo.environment["SERENES_BUILD_CONTENT_DIR"].map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
    }

    private static func buildContentURL(named name: String, extension fileExtension: String) -> URL? {
        guard let directory = buildContentDirectory else { return nil }
        return directory.appending(path: "\(name).\(fileExtension)")
    }

    @MainActor private static var assetImportInProgress = false
    private struct SeedChapterOrder: Decodable {
        let position: Int
        let label: String
    }
    private struct SeedPage: Decodable {
        let url: String
        let title: String
        let html: String
        let plainText: String
        let category: String
        let gameSlug: String?
        let gameSlugs: [String]?
        let chapterOrders: [String: SeedChapterOrder]?
        let archivedAt: String
    }

    private struct SeedGameNews: Decodable {
        let url: String
        let title: String
        let html: String
        let publishedAt: String
        let archivedAt: String
        let gameSlugs: [String]
    }

    static let games: [(String, String, String, String)] = [
        ("shadow-dragon-and-blade-of-light", "Shadow Dragon and the Blade of Light", "NES", "shadow-dragon-and-blade-of-light"),
        ("gaiden", "Gaiden", "NES", "gaiden"),
        ("mystery-of-the-emblem", "Mystery of the Emblem", "SNES", "mystery-of-the-emblem"),
        ("genealogy-of-the-holy-war", "Genealogy of the Holy War", "SNES", "genealogy-of-the-holy-war"),
        ("thracia-776", "Thracia 776", "SNES", "thracia-776"),
        ("binding-blade", "The Binding Blade", "GBA", "binding-blade"),
        ("blazing-sword", "The Blazing Blade", "GBA", "blazing-sword"),
        ("the-sacred-stones", "The Sacred Stones", "GBA", "the-sacred-stones"),
        ("path-of-radiance", "Path of Radiance", "GameCube", "path-of-radiance"),
        ("radiant-dawn", "Radiant Dawn", "Wii", "radiant-dawn"),
        ("shadow-dragon", "Shadow Dragon", "Nintendo DS", "shadow-dragon"),
        ("light-and-shadow", "New Mystery of the Emblem", "Nintendo DS", "light-and-shadow"),
        ("awakening", "Awakening", "Nintendo 3DS", "awakening"),
        ("fire-emblem-fates", "Fates", "Nintendo 3DS", "fire-emblem-fates"),
        ("fire-emblem-echoes-shadows-valentia", "Echoes: Shadows of Valentia", "Nintendo 3DS", "fire-emblem-echoes-shadows-valentia"),
        ("three-houses", "Three Houses", "Nintendo Switch", "three-houses"),
        ("engage", "Engage", "Nintendo Switch", "engage"),
        ("fortunes-weave", "Fortune’s Weave", "Nintendo Switch 2", "fortunes-weave"),
        ("fire-emblem-heroes", "Heroes", "Mobile", "fire-emblem-heroes"),
        ("fire-emblem-warriors", "Fire Emblem Warriors", "Nintendo Switch", "https://wiki.serenesforest.net/index.php/Fire_Emblem_Warriors"),
        ("warriors-three-hopes", "Warriors: Three Hopes", "Nintendo Switch", "https://wiki.serenesforest.net/index.php/Fire_Emblem_Warriors:_Three_Hopes"),
        ("tokyo-mirage-sessions", "Tokyo Mirage Sessions ♯FE", "Wii U", "https://wiki.serenesforest.net/index.php/Tokyo_Mirage_Sessions_%E2%99%AFFE")
    ]

    @MainActor static func seed(_ context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<Game>())
        let slugs = Set(existing.map(\.slug))
        for (slug, title, platform, path) in games where !slugs.contains(slug) {
            let url = path.hasPrefix("https://") ? path : "https://serenesforest.net/\(path)/"
            context.insert(Game(slug: slug, title: title, platform: platform, sourceURL: url))
            context.insert(ContentPage(url: url, title: title, gameSlug: slug, category: "Game"))
        }
        let home = "https://serenesforest.net/"
        if try context.fetch(FetchDescriptor<ContentPage>(predicate: #Predicate { $0.url == home })).isEmpty {
            context.insert(ContentPage(url: home, title: "Latest news", gameSlug: nil, category: "News"))
        }
        try context.save()
        if buildContentDirectory != nil {
            try importBuildContent(into: context)
            try importBuildContent(named: "WikiLibrary", marker: "SerenesForest.importedWikiLibrarySHA256V5", into: context)
            try importBuildGameNews(into: context)
        }
        let cleanupMarker = "SerenesForest.challengeCleanupV1"
        if !UserDefaults.standard.bool(forKey: cleanupMarker) {
            // Earlier archives accidentally stored anti-bot challenge pages as articles.
            for page in try context.fetch(FetchDescriptor<ContentPage>())
                where SiteHTML.isChallenge(title: page.title) {
                context.delete(page)
            }
            try context.save()
            UserDefaults.standard.set(true, forKey: cleanupMarker)
        }
        if UserDefaults.standard.object(forKey: "SerenesForest.lastSyncAttempt") == nil,
           try context.fetch(FetchDescriptor<ContentPage>()).contains(where: \.isDownloaded) {
            UserDefaults.standard.set(Date(), forKey: "SerenesForest.lastSyncAttempt")
        }
    }

    @MainActor private static func importBuildContent(into context: ModelContext) throws {
        try importBuildContent(named: "SeedContent", marker: "SerenesForest.importedSeedContentBytes", into: context)
    }

    @MainActor private static func importBuildGameNews(into context: ModelContext) throws {
        guard let url = buildContentURL(named: "GameNews", extension: "json") else { return }
        let data = try Data(contentsOf: url)
        let signature = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let marker = "SerenesForest.importedGameNewsSHA256V1"
        guard buildContentDirectory != nil || UserDefaults.standard.string(forKey: marker) != signature else { return }
        let records = try JSONDecoder().decode([SeedGameNews].self, from: data)
        var known = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<ContentPage>(
            predicate: #Predicate { $0.category == "News" })).map { ($0.url, $0) })
        let archived = DateFormatter()
        archived.locale = Locale(identifier: "en_US_POSIX")
        archived.timeZone = TimeZone(secondsFromGMT: 0)
        archived.dateFormat = "yyyyMMddHHmmss"
        let published = ISO8601DateFormatter()
        for record in records {
            guard let rawURL = URL(string: record.url), let pageURL = SiteScope.canonical(rawURL),
                  PageCategoryMapper.category(for: pageURL).0 == "News" else { continue }
            let key = pageURL.absoluteString
            let page: ContentPage
            if let existing = known[key] {
                page = existing
            } else {
                page = ContentPage(url: key, title: record.title, gameSlug: nil, category: "News")
                context.insert(page)
                known[key] = page
            }
            var slugs = Set((page.newsGameSlugs ?? "").split(separator: "|").map(String.init))
            slugs.formUnion(record.gameSlugs)
            page.newsGameSlugs = slugs.sorted().joined(separator: "|")
            page.newsPublishedAt = published.date(from: record.publishedAt) ?? page.newsPublishedAt
            if !page.isDownloaded {
                let plain = SiteHTML.cleanText(record.html)
                guard !plain.isEmpty else { continue }
                page.title = record.title
                page.html = record.html
                page.plainText = plain
                page.nativeContent = nil
                page.fetchedAt = archived.date(from: record.archivedAt)
                page.sourceModifiedAt = page.fetchedAt
                page.isDownloaded = true
                page.lastError = nil
            }
        }
        try context.save()
        for slug in Set(records.flatMap(\.gameSlugs)) {
            let pagesKey = "SerenesForest.gameNewsPages.\(slug)"
            UserDefaults.standard.set(max(2, UserDefaults.standard.integer(forKey: pagesKey)), forKey: pagesKey)
            let moreKey = "SerenesForest.gameNewsHasMore.\(slug)"
            if UserDefaults.standard.object(forKey: moreKey) == nil {
                UserDefaults.standard.set(true, forKey: moreKey)
            }
            let checkedKey = "SerenesForest.gameNewsChecked.\(slug)"
            if UserDefaults.standard.object(forKey: checkedKey) == nil,
               let first = records.first, let date = archived.date(from: first.archivedAt) {
                UserDefaults.standard.set(date, forKey: checkedKey)
            }
        }
        UserDefaults.standard.set(signature, forKey: marker)
    }

    @MainActor private static func importBuildContent(named name: String, marker: String,
                                                         into context: ModelContext) throws {
        guard let url = buildContentURL(named: name, extension: "json") else { return }
        let fileSize = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
        let wikiData = name == "WikiLibrary" ? try Data(contentsOf: url) : nil
        let wikiSignature = wikiData.map { data in
            SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
        if let wikiSignature {
            if buildContentDirectory == nil && UserDefaults.standard.string(forKey: marker) == wikiSignature { return }
        } else if buildContentDirectory == nil && fileSize > 0 && UserDefaults.standard.integer(forKey: marker) == fileSize {
            return
        }
        let records = try JSONDecoder().decode([SeedPage].self, from: wikiData ?? Data(contentsOf: url))
        let existing = try context.fetch(FetchDescriptor<ContentPage>())
        var byURL = Dictionary(uniqueKeysWithValues: existing.map { ($0.url, $0) })
        let existingWikiLinks = name == "WikiLibrary" ? try context.fetch(FetchDescriptor<WikiGamePage>()) : []
        var wikiLinksByID = Dictionary(uniqueKeysWithValues: existingWikiLinks.map { ($0.id, $0) })
        var bundledWikiLinkIDs = Set<String>()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMddHHmmss"
        for record in records {
            guard !SiteHTML.isChallenge(title: record.title) else { continue }
            let archivedAt = formatter.date(from: record.archivedAt) ?? .distantPast
            let page: ContentPage
            if let saved = byURL[record.url] {
                page = saved
            } else {
                page = ContentPage(url: record.url, title: record.title, gameSlug: record.gameSlug, category: record.category)
                context.insert(page)
                byURL[record.url] = page
            }
            let wikiSlugs = record.gameSlugs ?? record.gameSlug.map { [$0] } ?? []
            let wikiMembership = wikiSlugs.isEmpty ? nil : "|" + wikiSlugs.joined(separator: "|") + "|"
            if name == "WikiLibrary" {
                for slug in wikiSlugs {
                    let id = slug + "|" + record.url
                    bundledWikiLinkIDs.insert(id)
                    if let link = wikiLinksByID[id] {
                        link.page = page
                        link.chapterPosition = record.chapterOrders?[slug]?.position
                        link.chapterLabel = record.chapterOrders?[slug]?.label
                    } else {
                        let link = WikiGamePage(gameSlug: slug, page: page)
                        link.chapterPosition = record.chapterOrders?[slug]?.position
                        link.chapterLabel = record.chapterOrders?[slug]?.label
                        context.insert(link)
                        wikiLinksByID[id] = link
                    }
                }
            }
            let contentChanged = page.html != record.html
            guard !page.isDownloaded || (page.fetchedAt ?? .distantPast) < archivedAt ||
                    (name == "WikiLibrary" && (contentChanged || page.wikiGameSlugs != wikiMembership ||
                                               page.category != record.category || page.gameSlug != record.gameSlug ||
                                               page.title != record.title)) else { continue }
            page.title = record.title
            page.gameSlug = record.gameSlug
            if name == "WikiLibrary" {
                page.wikiGameSlugs = wikiMembership
            }
            page.category = record.category
            page.html = record.html
            page.plainText = record.plainText
            if contentChanged {
                page.nativeContent = nil
                page.russianContent = nil
            }
            // Existing translations are keyed by source fragments. Reuse the
            // fragments that still occur in a refreshed wiki article.
            if name != "WikiLibrary" {
                page.russianDraft = nil
                page.russianTitle = nil
            }
            if contentChanged {
                page.russianPlainText = nil
                page.russianNavigation = nil
            }
            page.fetchedAt = archivedAt
            page.isDownloaded = true
            page.lastError = nil
        }
        if name == "WikiLibrary" {
            let bundledURLs = Set(records.map(\.url))
            for page in existing where page.category.hasPrefix("Wiki · ") && !bundledURLs.contains(page.url) {
                context.delete(page)
            }
            for link in existingWikiLinks where !bundledWikiLinkIDs.contains(link.id) {
                context.delete(link)
            }
        }
        try context.save()
        if let wikiSignature { UserDefaults.standard.set(wikiSignature, forKey: marker) }
        else { UserDefaults.standard.set(fileSize, forKey: marker) }
    }

    @MainActor static func importBuildAssets(into container: ModelContainer) async throws {
        guard !assetImportInProgress else { return }
        assetImportInProgress = true
        defer { assetImportInProgress = false }
        let importer = BuildAssetImporter(container: container)
        if let wiki = buildContentURL(named: "WikiAssets", extension: "jsonl") {
            try await importer.run(url: wiki,
                                   fileMarker: "SerenesForest.wikiAssetFileBytes",
                                   lineMarker: "SerenesForest.wikiAssetImportedLines")
        }
        if let original = buildContentURL(named: "SeedAssets", extension: "jsonl") {
            try await importer.run(url: original,
                                   fileMarker: "SerenesForest.seedAssetFileBytes",
                                   lineMarker: "SerenesForest.seedAssetImportedLines")
        }
    }
}

actor BuildAssetImporter {
    private struct SeedAsset: Decodable {
        let url: String
        let title: String
        let sourcePageURL: String
        let mimeType: String
    }

    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func run(url: URL, fileMarker: String, lineMarker: String) async throws {
        let isBuildingLibrary = ProcessInfo.processInfo.environment["SERENES_BUILD_STORE_PATH"] != nil
        let fileSize = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
        let completionMarker = fileMarker + ".complete"
        if !isBuildingLibrary, fileSize > 0, UserDefaults.standard.integer(forKey: fileMarker) == fileSize,
           UserDefaults.standard.bool(forKey: completionMarker) { return }
        let completedLines = !isBuildingLibrary && UserDefaults.standard.integer(forKey: fileMarker) == fileSize
            ? UserDefaults.standard.integer(forKey: lineMarker) : 0
        if UserDefaults.standard.integer(forKey: fileMarker) != fileSize {
            UserDefaults.standard.set(fileSize, forKey: fileMarker)
            UserDefaults.standard.set(0, forKey: lineMarker)
            UserDefaults.standard.set(false, forKey: completionMarker)
        }
        let lookupContext = ModelContext(container)
        var known = Set(try lookupContext.fetch(FetchDescriptor<ContentAsset>()).map(\.url))
        let decoder = JSONDecoder()
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let newline = Data([10])
        var buffer = Data()
        var lineNumber = 0
        var batchContext = ModelContext(container)
        while true {
            let chunk = try handle.read(upToCount: 65_536) ?? Data()
            if chunk.isEmpty && buffer.isEmpty { break }
            buffer.append(chunk)
            while let range = buffer.range(of: newline) {
                let line = Data(buffer[..<range.lowerBound])
                buffer.removeSubrange(..<range.upperBound)
                lineNumber += 1
                if lineNumber > completedLines && !line.isEmpty {
                    let record = try decoder.decode(SeedAsset.self, from: line)
                    if known.insert(record.url).inserted {
                        let asset = ContentAsset(url: record.url, title: record.title, sourcePageURL: record.sourcePageURL)
                        asset.mimeType = record.mimeType
                        batchContext.insert(asset)
                    }
                }
                if lineNumber > completedLines && lineNumber.isMultiple(of: 100) {
                    try batchContext.save()
                    UserDefaults.standard.set(lineNumber, forKey: lineMarker)
                    batchContext = ModelContext(container)
                    await Task.yield()
                }
            }
            if chunk.isEmpty { break }
        }
        if !buffer.isEmpty {
            lineNumber += 1
            if lineNumber > completedLines {
                let record = try decoder.decode(SeedAsset.self, from: buffer)
                if known.insert(record.url).inserted {
                    let asset = ContentAsset(url: record.url, title: record.title, sourcePageURL: record.sourcePageURL)
                    asset.mimeType = record.mimeType
                    batchContext.insert(asset)
                }
            }
        }
        try batchContext.save()
        UserDefaults.standard.set(lineNumber, forKey: lineMarker)
        UserDefaults.standard.set(true, forKey: completionMarker)
    }
}
