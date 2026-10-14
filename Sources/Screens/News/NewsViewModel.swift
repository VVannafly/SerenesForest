import SerenesParsing
import Foundation
import Observation
import SwiftUI

@MainActor @Observable
final class NewsViewModel {
    var search = ""
    var isChecking = false

    func pages(from allPages: [ContentPage]) -> [ContentPage] {
        let dated = allPages.filter {
            $0.category == "News" && $0.url != SiteScope.home &&
            AppText.matches($0, query: search)
        }.map { ($0, ContentPageMapper.newsDate($0)) }
        return dated.sorted { left, right in
                if left.0.isDownloaded != right.0.isDownloaded { return left.0.isDownloaded }
                return left.1 > right.1
            }
            .map(\.0)
    }

}
