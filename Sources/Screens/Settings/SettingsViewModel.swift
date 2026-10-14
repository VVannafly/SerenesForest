import Foundation
import Observation
import SwiftUI
import SwiftData
import Translation

private enum Constants {
    static let russian = "ru"
    static let paused = "Перевод приостановлен. Повторный запуск продолжит с сохранённого места."
    static func completed(_ count: Int, failed: Int) -> String { "Перевод завершён. Переведено: \(count), требуют повтора: \(failed)." }
    static func stopped(_ message: String) -> String { "Перевод остановлен: \(message). Прогресс сохранён." }
}

@MainActor @Observable
final class SettingsViewModel {
    var translatingLibrary = false
    var stopTranslation = false
    var translatedPages = 0
    var totalPages = 0
    var translatedFragments = 0
    var totalFragments = 0
    var currentPageTitle = ""
    var translationMessage: String?

    @available(iOS 18.0, macOS 15.0, *)
    func translateSavedArticles(using session: TranslationSession, context: ModelContext, language: String) async {
        defer { translatingLibrary = false }
        do {
            let saved = try context.fetch(FetchDescriptor<ContentPage>(
                predicate: #Predicate { $0.isDownloaded == true },
                sortBy: [SortDescriptor(\.url)]))
            let pending = saved.filter { $0.russianContent == nil }
            totalPages = pending.count
            var failedPages = 0
            var consecutiveFailures = 0
            for page in pending {
                if Task.isCancelled || stopTranslation || language != Constants.russian { break }
                currentPageTitle = page.title
                do {
                    let result = try await LibraryTranslator.translate(page, using: session, context: context) { done, total in
                        translatedFragments = done
                        totalFragments = total
                    }
                    if result.complete { translatedPages += 1 }
                    else { failedPages += 1 }
                    consecutiveFailures = 0
                } catch {
                    if Task.isCancelled { break }
                    failedPages += 1
                    consecutiveFailures += 1
                    if consecutiveFailures >= 3 { throw error }
                }
                await Task.yield()
            }
            translationMessage = stopTranslation
                ? Constants.paused
                : Constants.completed(translatedPages, failed: failedPages)
        } catch {
            if !Task.isCancelled {
                translationMessage = Constants.stopped(error.localizedDescription)
            }
        }
        currentPageTitle = ""
    }}
