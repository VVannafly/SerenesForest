import SwiftUI

private enum Constants {
    static let newsCategory = "News"
}

struct PageRowViewModel {
    let section: GameSection?
    let tint: Color?
    let isNews: Bool

    init(page: ContentPage) {
        isNews = page.category == Constants.newsCategory
        guard let slug = page.gameSlug else {
            section = nil
            tint = nil
            return
        }
        let section = GameSection.style(for: page.title)
        self.section = section
        tint = GameTheme.forGame(slug).color(for: section)
    }
}
