import Foundation

struct ArticleRun: Hashable, Codable {
    var text: String
    var url: URL?
    var strong = false
    var italic = false
}

struct ArticleCell: Codable {
    var runs: [ArticleRun]
    var imageURLs: [URL]
    var header: Bool
    var span: Int
    var rowSpan: Int
}

struct ArticleTab: Codable {
    var title: String
    var blocks: [ArticleBlock]
}

enum ArticleBlock: Codable {
    case heading(Int, [ArticleRun])
    case paragraph([ArticleRun])
    case list(Bool, [[ArticleRun]])
    case image(URL, String)
    case table([[ArticleCell]])
    case fatesClasses(FatesClassGuide)
    case classScheme(ClassScheme)
    case tabs([ArticleTab])
    case quote([ArticleRun])
    case rule
}

enum ArticleTableKind {
    case standard
    case classProgression
}

struct ArticleTablePresentation {
    let rows: [[ArticleCell]]
    let kind: ArticleTableKind
    let progression: ArticleClassProgression?
}

struct ArticleClassProgression {
    let baseTitle: String
    let promotedTitle: String
    let pairs: [ArticleClassPair]
}

struct ArticleClassPair {
    let base: ArticleCell?
    let promoted: ArticleCell?
    let showsArrow: Bool
}

struct ArticleHeadingPresentation {
    let level: Int
    let runs: [ArticleRun]
    let symbol: String
}

struct ArticleTabPresentation {
    let title: String
    let blocks: [ArticlePresentationBlock]
}

enum ArticlePresentationBlock {
    case heading(ArticleHeadingPresentation)
    case paragraph([ArticleRun])
    case list(Bool, [[ArticleRun]])
    case image(URL, String)
    case table(ArticleTablePresentation)
    case fatesClasses(FatesClassGuide)
    case classScheme(ClassScheme)
    case tabs([ArticleTabPresentation])
    case quote([ArticleRun])
    case rule
}

// Translate only visible text. The original article structure, links and image URLs
// remain intact, so translated pages use the same native renderer as source pages.
struct GameNavigationSection: Identifiable {
    let id: Int
    let title: String
    let items: [GameNavigationItem]
}

struct GameNavigationItem: Identifiable {
    let id: Int
    let title: String
    let links: [GameNavigationLink]
    var children: [GameNavigationItem] = []
}

struct GameNavigationLink {
    let title: String
    let url: URL
}
