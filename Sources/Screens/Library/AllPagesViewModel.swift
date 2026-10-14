import Foundation
import Observation
import SwiftUI

private enum Constants { static let all = "All" }

@MainActor @Observable
final class AllPagesViewModel {
    var search = ""
    var category = Constants.all

    func categories(from allPages: [ContentPage]) -> [String] { [Constants.all] + Set(allPages.map(\.category)).sorted() }
    func pages(from allPages: [ContentPage]) -> [ContentPage] {
        allPages.filter {
            (category == Constants.all || $0.category == category) &&
            AppText.matches($0, query: search)
        }
        .sorted {
            if $0.isDownloaded != $1.isDownloaded { return $0.isDownloaded }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

}
