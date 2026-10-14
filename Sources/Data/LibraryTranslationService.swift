import Foundation
import SwiftData
import Translation

@available(iOS 18.0, macOS 15.0, *)
@MainActor enum LibraryTranslator {
    struct Result {
        let blocks: [ArticleBlock]
        let title: String
        let complete: Bool
    }

    static func translate(_ page: ContentPage, using session: TranslationSession,
                          context: ModelContext, progress: (Int, Int) -> Void = { _, _ in }) async throws -> Result {
        let html = page.html
        let url = page.url
        let stored = page.nativeContent
        let blocks = await Task.detached(priority: .utility) {
            let decoded = stored.flatMap { try? JSONDecoder().decode([ArticleBlock].self, from: $0) }
            let needsClassesRepair = URL(string: url).map {
                ClassesParserFactory.needsCacheRepair(source: $0, blocks: decoded)
            } == true
            return needsClassesRepair ? NativeArticleParser.parse(html, source: url)
                : decoded ?? NativeArticleParser.parse(html, source: url)
        }.value
        let texts = ArticleTranslation.sourceTexts(title: page.title, blocks: blocks)
        var translations = page.russianDraft.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
        let missing = texts.filter { translations[$0] == nil }
        progress(texts.count - missing.count, texts.count)

        func save() throws -> Result {
            let translated = ArticleTranslation.apply(translations, to: blocks)
            let complete = texts.allSatisfy { translations[$0] != nil }
            let title = translations[page.title.trimmingCharacters(in: .whitespacesAndNewlines)] ?? page.title
            page.russianDraft = try JSONEncoder().encode(translations)
            page.russianContent = complete ? try JSONEncoder().encode(translated) : nil
            page.russianTitle = title
            page.russianPlainText = ArticleTranslation.plainText(translated)
            try context.save()
            return Result(blocks: translated, title: title, complete: complete)
        }

        for start in stride(from: 0, to: missing.count, by: 16) {
            try Task.checkCancellation()
            let chunk = Array(missing[start..<min(start + 16, missing.count)])
            let requests = chunk.enumerated().map { index, value in
                TranslationSession.Request(sourceText: value, clientIdentifier: String(index))
            }
            do {
                for response in try await session.translations(from: requests) {
                    let source = response.clientIdentifier.flatMap(Int.init)
                        .flatMap { chunk.indices.contains($0) ? chunk[$0] : nil } ?? response.sourceText
                    translations[source] = response.targetText
                }
            } catch {
                var translatedAny = false
                for value in chunk {
                    try Task.checkCancellation()
                    do {
                        if let response = try await session.translations(from: [
                            TranslationSession.Request(sourceText: value)
                        ]).first {
                            translations[value] = response.targetText
                            translatedAny = true
                        }
                    } catch { continue }
                }
                if !translatedAny {
                    if !translations.isEmpty { _ = try save() }
                    throw error
                }
            }
            _ = try save()
            progress(texts.filter { translations[$0] != nil }.count, texts.count)
        }
        return try save()
    }
}

