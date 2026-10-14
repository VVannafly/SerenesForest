import SerenesParsing
import Foundation
import Observation

@Observable
final class ClassSchemeViewModel {
    let scheme: ClassScheme
    let assets: [String: Date]

    init(scheme: ClassScheme, assets: [String: Date]) {
        self.scheme = scheme
        self.assets = assets
    }

    func title(at depth: Int) -> String? {
        guard scheme.stageTitles.indices.contains(depth) else { return nil }
        let title = scheme.stageTitles[depth]
        return title.isEmpty ? nil : title
    }

    func assetKey(for url: URL) -> String {
        SiteScope.canonical(url)?.absoluteString ?? url.absoluteString
    }

    func fetchedAt(for url: URL) -> Date? {
        assets[assetKey(for: url)]
    }

    func availableIcons(_ urls: [URL]) -> [URL] {
        urls.filter { fetchedAt(for: $0) != nil }
    }
}
