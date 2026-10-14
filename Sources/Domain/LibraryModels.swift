import Foundation
import SwiftData
import CryptoKit

@Model
final class Game {
    @Attribute(.unique) var slug: String
    var title: String
    var platform: String
    var sourceURL: String
    var status: String
    var isFavorite: Bool

    init(slug: String, title: String, platform: String, sourceURL: String) {
        self.slug = slug
        self.title = title
        self.platform = platform
        self.sourceURL = sourceURL
        self.status = "Unplayed"
        self.isFavorite = false
    }
}

@Model
final class ContentPage {
    @Attribute(.unique) var url: String
    var title: String
    var gameSlug: String?
    var wikiGameSlugs: String?
    var category: String
    var html: String
    var plainText: String
    @Attribute(.externalStorage) var nativeContent: Data?
    @Attribute(.externalStorage) var russianContent: Data?
    @Attribute(.externalStorage) var russianDraft: Data?
    var russianTitle: String?
    var russianPlainText: String?
    @Attribute(.externalStorage) var russianNavigation: Data?
    var fetchedAt: Date?
    var sourceModifiedAt: Date?
    var availableModifiedAt: Date?
    var etag: String?
    var lastModified: String?
    var isDownloaded: Bool
    var bookmarkedAt: Date?
    var newsGameSlugs: String?
    var newsPublishedAt: Date?
    var lastAttempt: Date?
    var lastError: String?

    var needsSitemapUpdate: Bool {
        guard let availableModifiedAt else { return false }
        return !isDownloaded || availableModifiedAt > (sourceModifiedAt ?? fetchedAt ?? .distantPast)
    }

    init(url: String, title: String, gameSlug: String?, category: String) {
        self.url = url
        self.title = title
        self.gameSlug = gameSlug
        self.wikiGameSlugs = nil
        self.category = category
        self.html = ""
        self.plainText = ""
        self.nativeContent = nil
        self.russianContent = nil
        self.russianDraft = nil
        self.russianTitle = nil
        self.russianPlainText = nil
        self.russianNavigation = nil
        self.fetchedAt = nil
        self.sourceModifiedAt = nil
        self.availableModifiedAt = nil
        self.etag = nil
        self.lastModified = nil
        self.isDownloaded = false
        self.bookmarkedAt = nil
        self.newsGameSlugs = nil
        self.newsPublishedAt = nil
        self.lastAttempt = nil
        self.lastError = nil
    }
}

@Model
final class WikiGamePage {
    @Attribute(.unique) var id: String
    var gameSlug: String
    @Relationship(deleteRule: .nullify) var page: ContentPage?
    var chapterPosition: Int?
    var chapterLabel: String?

    init(gameSlug: String, page: ContentPage) {
        self.id = gameSlug + "|" + page.url
        self.gameSlug = gameSlug
        self.page = page
        self.chapterPosition = nil
        self.chapterLabel = nil
    }
}

@Model
final class SitemapSection {
    @Attribute(.unique) var url: String
    var modifiedAt: Date?
    var baselineAt: Date?

    init(url: String) {
        self.url = url
        self.modifiedAt = nil
        self.baselineAt = nil
    }
}

@Model
final class ContentAsset {
    @Attribute(.unique) var url: String
    var title: String
    var sourcePageURL: String
    var mimeType: String?
    @Attribute(.externalStorage) var data: Data?
    var fetchedAt: Date?
    var lastAttempt: Date?
    var lastError: String?

    init(url: String, title: String, sourcePageURL: String) {
        self.url = url
        self.title = title
        self.sourcePageURL = sourcePageURL
        self.mimeType = nil
        self.data = nil
        self.fetchedAt = nil
        self.lastAttempt = nil
        self.lastError = nil
    }
}
