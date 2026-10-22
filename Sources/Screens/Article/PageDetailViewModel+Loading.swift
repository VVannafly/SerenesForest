import SerenesParsing
import Foundation
import SwiftData
import SwiftUI
import Translation

private enum Constants {
    static let russian = "ru"
    static let unavailableInSimulator = "Перевод статьи недоступен в симуляторе."
    static let translating = "Перевод статьи…"
    static let partial = "Часть фрагментов не переведена. Прогресс сохранён."
    static let legacyClassTag = Data("\"fatesClasses\"".utf8)
    static func progress(_ done: Int, total: Int) -> String { "Перевод статьи: \(done)/\(total)" }
    static func failed(_ message: String) -> String { "Не удалось перевести статью: \(message)" }
}

extension PageDetailViewModel {
    func prepareArticle(page: ContentPage, context: ModelContext, language: String) async {
        guard page.isDownloaded else { return }
        showArticle(nil)
        let html = page.html
        let pageURL = page.url
        let hasObsoletePageTabs = html.contains("tab-switch")
        let stored = page.nativeContent
        let prepared = await Task.detached(priority: .userInitiated) { () -> ([ArticleBlock], Data?, [String], Bool) in
            let decoded = stored.flatMap { try? JSONDecoder().decode([ArticleBlock].self, from: $0) }
            let hasCollapsedTable = decoded?.contains { block in
                if case .table(let rows) = block { return rows.first?.count == 1 }
                return false
            } == true
            let hasOrphanedImages = decoded?.contains { block in
                if case .image = block { return true }
                return false
            } == true
            let needsTableRepair = hasCollapsedTable && hasOrphanedImages && html.contains("<table") &&
                NativeArticleParser.hasNestedTables(html)
            let needsClassesRepair = URL(string: pageURL).map {
                ClassesParserFactory.needsCacheRepair(source: $0, blocks: decoded)
            } == true
            let needsRepair = needsTableRepair || needsClassesRepair
            let original = needsRepair ? NativeArticleParser.parse(html, source: pageURL)
                : decoded ?? NativeArticleParser.parse(html, source: pageURL)
            let cleaned = hasObsoletePageTabs
                ? NativeArticleParser.removingObsoletePageTabs(original)
                : (blocks: original, changed: false)
            let blocks = cleaned.blocks
            let encoded = decoded == nil || cleaned.changed || needsRepair ||
                (stored?.range(of: Constants.legacyClassTag) != nil)
                ? try? JSONEncoder().encode(blocks) : nil
            var references = Set<String>()
            func collectImages(_ blocks: [ArticleBlock]) {
                for block in blocks {
                    switch block {
                    case .image(let url, _):
                        references.insert(SiteScope.canonical(url)?.absoluteString ?? url.absoluteString)
                    case .table(let rows):
                        for cell in rows.joined() {
                            for url in cell.imageURLs {
                                references.insert(SiteScope.canonical(url)?.absoluteString ?? url.absoluteString)
                            }
                        }
                    case .classScheme(let scheme):
                        func collect(_ branch: ClassSchemeBranch) {
                            let urls = [branch.entry.artworkURL].compactMap { $0 } + branch.entry.iconURLs +
                                (branch.upgrade?.imageURLs ?? [])
                            for url in urls {
                                references.insert(SiteScope.canonical(url)?.absoluteString ?? url.absoluteString)
                            }
                            branch.children.forEach(collect)
                        }
                        scheme.roots.forEach(collect)
                        for entry in scheme.unassignedEntries {
                            for url in [entry.artworkURL].compactMap({ $0 }) + entry.iconURLs {
                                references.insert(SiteScope.canonical(url)?.absoluteString ?? url.absoluteString)
                            }
                        }
                    case .tabs(let tabs):
                        for tab in tabs { collectImages(tab.blocks) }
                    default: break
                    }
                }
            }
            collectImages(blocks)
            return (blocks, encoded, Array(references), needsRepair)
        }.value
        guard !Task.isCancelled else { return }
        translationAttempted = false
        translationProgress = nil
        translationError = nil
        if language == Constants.russian {
            if let storedRussian = page.russianContent, !prepared.3,
               let translated = try? JSONDecoder().decode([ArticleBlock].self, from: storedRussian) {
                let cleaned = hasObsoletePageTabs
                    ? NativeArticleParser.removingObsoletePageTabs(translated)
                    : (blocks: translated, changed: false)
                showArticle(cleaned.blocks)
                if cleaned.changed || storedRussian.range(of: Constants.legacyClassTag) != nil {
                    page.russianContent = try? JSONEncoder().encode(cleaned.blocks)
                    page.russianPlainText = ArticleTranslation.plainText(cleaned.blocks)
                    try? context.save()
                }
                translatedTitle = page.russianTitle
            } else {
                if prepared.3 && page.russianContent != nil {
                    page.russianContent = nil
                    page.russianPlainText = nil
                    try? context.save()
                }
                let draft = page.russianDraft.flatMap {
                    try? JSONDecoder().decode([String: String].self, from: $0)
                } ?? [:]
                showArticle(ArticleTranslation.apply(draft, to: prepared.0))
                translatedTitle = page.russianTitle
                if !TranslationAvailability.isSupported {
                    translationError = Constants.unavailableInSimulator
                } else {
                    translationProgress = Constants.translating
                }
            }
        } else {
            showArticle(prepared.0)
            translatedTitle = nil
        }
        imageURLs = prepared.2
        if let encoded = prepared.1 {
            let container = context.container
            let url = page.url
            Task.detached(priority: .utility) {
                let background = ModelContext(container)
                let descriptor = FetchDescriptor<ContentPage>(predicate: #Predicate { $0.url == url })
                if let cached = try? background.fetch(descriptor).first, cached.nativeContent == stored {
                    cached.nativeContent = encoded
                    try? background.save()
                }
            }
        }
        await loadArticleAssets(context: context)
    }

    func translateArticle(using session: TranslationSession, page: ContentPage, context: ModelContext, language: String) async {
        guard language == Constants.russian, page.russianContent == nil, !translationAttempted else { return }
        translationAttempted = true
        do {
            let result = try await LibraryTranslator.translate(page, using: session, context: context) { done, total in
                translationProgress = Constants.progress(done, total: total)
            }
            guard !Task.isCancelled, language == Constants.russian else { return }
            showArticle(result.blocks)
            translatedTitle = result.title
            translationProgress = nil
            translationError = result.complete ? nil : Constants.partial
        } catch {
            guard !Task.isCancelled else { return }
            translationProgress = nil
            translationError = Constants.failed(error.localizedDescription)
            if let draft = page.russianDraft.flatMap({ try? JSONDecoder().decode([String: String].self, from: $0) }),
               let articleBlocks = articleBlocks {
                showArticle(ArticleTranslation.apply(draft, to: articleBlocks))
                translatedTitle = page.russianTitle
            }
        }
    }

    func loadArticleAssets(context: ModelContext) async {
        let references = imageURLs
        let container = context.container
        let result = await Task.detached(priority: .utility) { () -> [String: Date] in
            let background = ModelContext(container)
            var dates: [String: Date] = [:]
            for start in stride(from: 0, to: references.count, by: 200) {
                let urls = Array(references[start..<min(start + 200, references.count)])
                let descriptor = FetchDescriptor<ContentAsset>(predicate: #Predicate { urls.contains($0.url) })
                if let assets = try? background.fetch(descriptor) {
                    for asset in assets { dates[asset.url] = asset.fetchedAt }
                }
            }
            return dates
        }.value
        guard !Task.isCancelled else { return }
        articleAssets = result
    }

}
