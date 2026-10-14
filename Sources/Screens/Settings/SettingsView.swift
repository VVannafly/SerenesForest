import SwiftUI
import Observation
import Translation

private enum Constants {
    static var translatingLibrary: String { AppText.localized( "Translating library…") }
    static var translateSavedArticles: String { AppText.localized( "Translate saved articles") }
    static var translationRequiresNewOS: String { AppText.localized( "Article translation requires iOS 18 or macOS 15.") }
    static var translationUnavailableInSimulator: String { AppText.localized( "Перевод статей недоступен в симуляторе. Откройте приложение на устройстве.") }
    static func translationProgress(pages: Int, totalPages: Int, fragments: Int, totalFragments: Int) -> String { "\(pages)/\(totalPages) статей · \(fragments)/\(totalFragments) фрагментов" }
    static var language: String { AppText.localized( "Language") }
    static var appLanguage: String { AppText.localized( "App language") }
    static var english: String { AppText.localized( "English") }
    static var text: String { AppText.localized( "Русский") }
    static var articleTranslation: String { AppText.localized( "Article translation") }
    static var stopAfterCurrentItem: String { AppText.localized( "Stop after current item") }
    static var appearance: String { AppText.localized( "Appearance") }
    static var theme: String { AppText.localized( "Theme") }
    static var system: String { AppText.localized( "System") }
    static var light: String { AppText.localized( "Light") }
    static var dark: String { AppText.localized( "Dark") }
    static var settings: String { AppText.localized( "Settings") }
}

struct SettingsView: View {
    @State var viewModel = SettingsViewModel()
    @AppStorage("SerenesForest.language") private var language = "en"
    @AppStorage("SerenesForest.appearance") private var appearance = "system"
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            Section(Constants.language) {
                Picker(Constants.appLanguage, selection: $language) {
                    Text(Constants.english).tag("en")
                    Text(Constants.text).tag("ru")
                }
                .pickerStyle(.segmented)
            }
            if language == "ru" {
                Section(Constants.articleTranslation) {
                    if #available(iOS 18.0, macOS 15.0, *), TranslationAvailability.isSupported {
                        Button(viewModel.translatingLibrary ? Constants.translatingLibrary : Constants.translateSavedArticles) {
                            viewModel.translatedPages = 0
                            viewModel.totalPages = 0
                            viewModel.translationMessage = nil
                            viewModel.stopTranslation = false
                            viewModel.translatingLibrary = true
                        }
                        .disabled(viewModel.translatingLibrary)
                        if viewModel.translatingLibrary {
                            ProgressView(value: Double(viewModel.translatedPages), total: Double(max(viewModel.totalPages, 1)))
                            Text(Constants.translationProgress(pages: viewModel.translatedPages, totalPages: viewModel.totalPages, fragments: viewModel.translatedFragments, totalFragments: viewModel.totalFragments))
                                .font(.caption).foregroundStyle(.secondary)
                            Text(viewModel.currentPageTitle).font(.caption).lineLimit(2)
                            Button(Constants.stopAfterCurrentItem) { viewModel.stopTranslation = true }
                                .disabled(viewModel.stopTranslation)
                        }
                        if let translationMessage = viewModel.translationMessage {
                            Text(translationMessage).font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        Text(TranslationAvailability.isSupported
                             ? Constants.translationRequiresNewOS
                             : Constants.translationUnavailableInSimulator)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section(Constants.appearance) {
                Picker(Constants.theme, selection: $appearance) {
                    Text(Constants.system).tag("system")
                    Text(Constants.light).tag("light")
                    Text(Constants.dark).tag("dark")
                }
                .pickerStyle(.segmented)
            }
        }
        .background {
            if #available(iOS 18.0, macOS 15.0, *), TranslationAvailability.isSupported,
               language == "ru", viewModel.translatingLibrary {
                Color.clear.translationTask(source: Locale.Language(identifier: "en"),
                                            target: Locale.Language(identifier: "ru")) { session in
                    await viewModel.translateSavedArticles(using: session, context: context, language: language)
                }
            }
        }
        .navigationTitle(Constants.settings)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

}
