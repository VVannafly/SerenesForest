import SerenesParsing
import Foundation
import Observation

@Observable
final class FatesClassesViewModel {
    let guide: FatesClassGuide
    let assets: [String: Date]

    init(guide: FatesClassGuide, assets: [String: Date]) {
        self.guide = guide
        self.assets = assets
    }

    var baseTitle: String { guide.baseTitle.map(\.text).joined() }
    var promotedTitle: String { guide.promotedTitle.map(\.text).joined() }

    func assetKey(for url: URL) -> String {
        SiteScope.canonical(url)?.absoluteString ?? url.absoluteString
    }

    func fetchedAt(for url: URL) -> Date? {
        assets[assetKey(for: url)]
    }
}
