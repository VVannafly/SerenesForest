import SwiftUI
import SwiftData

private enum Constants {
    static let buildStorePath = "SERENES_BUILD_STORE_PATH"
    static let buildContentDirectory = "SERENES_BUILD_CONTENT_DIR"
    static let libraryDirectory = "SerenesForest"
    static let installingDirectory = "SerenesForest.installing"
    static let storeName = "Library.store"
    static let bundledDirectory = "PreloadedLibrary"
    static let legacyStoreName = "default.store"
    static let verifyStore = "SERENES_VERIFY_STORE"
    static let testSupportDirectory = "SERENES_TEST_SUPPORT_DIRECTORY"
}

@main
struct SerenesForestApp: App {
    private let container: ModelContainer
    @State private var sync: ContentSync
    private let isBuildingLibrary: Bool
    private let isVerifyingLibrary: Bool

    init() {
        do {
            let buildPath = ProcessInfo.processInfo.environment[Constants.buildStorePath]
            let (container, installedBundledLibrary) = try Self.makeContainer(buildPath: buildPath)
            try Catalog.seed(container.mainContext, installedBundledLibrary: installedBundledLibrary)
            self.container = container
            self.isBuildingLibrary = buildPath != nil
            self.isVerifyingLibrary = ProcessInfo.processInfo.environment[Constants.verifyStore] != nil
            _sync = State(initialValue: ContentSync(context: container.mainContext))
        } catch {
            fatalError("Unable to open the local library: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isBuildingLibrary || isVerifyingLibrary {
                    ProgressView()
                        .task {
                            do {
                                if isBuildingLibrary {
                                    try await Catalog.importBuildAssets(into: container)
                                    print("Preloaded library build finished")
                                } else {
                                    let context = container.mainContext
                                    let pages = try context.fetchCount(FetchDescriptor<ContentPage>())
                                    let assets = try context.fetchCount(FetchDescriptor<ContentAsset>())
                                    print("Preloaded library contains \(pages) pages and \(assets) assets")
                                }
                                exit(EXIT_SUCCESS)
                            } catch {
                                fputs("Preloaded library build failed: \(error)\n", stderr)
                                exit(EXIT_FAILURE)
                            }
                        }
                } else {
                    RootView(sync: sync)
                }
            }
                .modelContainer(container)
        }
    }

    private static func makeContainer(buildPath: String?) throws -> (ModelContainer, Bool) {
        let fileManager = FileManager.default
        let storeURL: URL
        var installedBundledLibrary = false
        if let buildPath {
            guard ProcessInfo.processInfo.environment[Constants.buildContentDirectory] != nil else {
                throw CocoaError(.fileNoSuchFile)
            }
            storeURL = URL(fileURLWithPath: buildPath)
            try fileManager.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        } else {
            let support = ProcessInfo.processInfo.environment[Constants.testSupportDirectory]
                .map { URL(fileURLWithPath: $0, isDirectory: true) } ?? URL.applicationSupportDirectory
            let library = support.appending(path: Constants.libraryDirectory, directoryHint: .isDirectory)
            let legacy = support.appending(path: Constants.legacyStoreName)
            if fileManager.fileExists(atPath: legacy.path) && !fileManager.fileExists(atPath: library.path) {
                storeURL = legacy
            } else {
                if !fileManager.fileExists(atPath: library.path) {
                    guard let bundled = Bundle.main.url(forResource: Constants.bundledDirectory, withExtension: nil) else {
                        throw CocoaError(.fileNoSuchFile)
                    }
                    try fileManager.createDirectory(at: support, withIntermediateDirectories: true)
                    let installing = support.appending(path: Constants.installingDirectory, directoryHint: .isDirectory)
                    if fileManager.fileExists(atPath: installing.path) {
                        try fileManager.removeItem(at: installing)
                    }
                    try fileManager.copyItem(at: bundled, to: installing)
                    try fileManager.moveItem(at: installing, to: library)
                    installedBundledLibrary = true
                }
                storeURL = library.appending(path: Constants.storeName)
            }
            guard fileManager.fileExists(atPath: storeURL.path) else {
                throw CocoaError(.fileNoSuchFile)
            }
        }
        let configuration = ModelConfiguration(url: storeURL)
        let container = try ModelContainer(for: Game.self, ContentPage.self, WikiGamePage.self,
                                           ContentAsset.self, SitemapSection.self, configurations: configuration)
        return (container, installedBundledLibrary)
    }
}
