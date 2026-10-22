import SwiftUI

private enum Constants {
    static let newsCategory = "News"
}

struct PageRowViewModel {
    let section: GameSection?
    let tint: Color?
    let isNews: Bool

    init(title: String, category: String, gameSlug: String?) {
        isNews = category == Constants.newsCategory
        guard let slug = gameSlug else {
            section = nil
            tint = nil
            return
        }
        let section = GameSection.style(for: title)
        self.section = section
        tint = GameTheme.forGame(slug).color(for: section)
    }
}
