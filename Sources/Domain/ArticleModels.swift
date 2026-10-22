import Foundation

struct ArticleRun: Hashable, Codable, Sendable {
    var text: String
    var url: URL?
    var strong = false
    var italic = false
}

struct ArticleCell: Codable, Sendable {
    var runs: [ArticleRun]
    var imageURLs: [URL]
    var header: Bool
    var span: Int
    var rowSpan: Int
}

struct ArticleTab: Codable, Sendable {
    var title: String
    var blocks: [ArticleBlock]
}

enum ArticleBlock: Codable, Sendable {
    case heading(Int, [ArticleRun])
    case paragraph([ArticleRun])
    case list(Bool, [[ArticleRun]])
    case image(URL, String)
    case table([[ArticleCell]])
    case classScheme(ClassScheme)
    case tabs([ArticleTab])
    case quote([ArticleRun])
    case rule

    // Keep the old on-disk enum tag readable while writing only classScheme.
    private enum StoredBlock: Codable, Sendable {
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

    init(from decoder: Decoder) throws {
        switch try StoredBlock(from: decoder) {
        case .heading(let level, let runs): self = .heading(level, runs)
        case .paragraph(let runs): self = .paragraph(runs)
        case .list(let ordered, let items): self = .list(ordered, items)
        case .image(let url, let alt): self = .image(url, alt)
        case .table(let rows): self = .table(rows)
        case .fatesClasses(let guide): self = .classScheme(ClassSchemeBuilder.build(from: guide))
        case .classScheme(let scheme): self = .classScheme(scheme)
        case .tabs(let tabs): self = .tabs(tabs)
        case .quote(let runs): self = .quote(runs)
        case .rule: self = .rule
        }
    }

    func encode(to encoder: Encoder) throws {
        let stored: StoredBlock
        switch self {
        case .heading(let level, let runs): stored = .heading(level, runs)
        case .paragraph(let runs): stored = .paragraph(runs)
        case .list(let ordered, let items): stored = .list(ordered, items)
        case .image(let url, let alt): stored = .image(url, alt)
        case .table(let rows): stored = .table(rows)
        case .classScheme(let scheme): stored = .classScheme(scheme)
        case .tabs(let tabs): stored = .tabs(tabs)
        case .quote(let runs): stored = .quote(runs)
        case .rule: stored = .rule
        }
        try stored.encode(to: encoder)
    }
}

enum ArticleTableKind: Sendable {
    case standard
    case classProgression
}

struct ArticleTablePresentation: Sendable {
    let rows: [[ArticleCell]]
    let kind: ArticleTableKind
    let progression: ArticleClassProgression?
}

struct ArticleClassProgression: Sendable {
    let baseTitle: String
    let promotedTitle: String
    let pairs: [ArticleClassPair]
}

struct ArticleClassPair: Sendable {
    let base: ArticleCell?
    let promoted: ArticleCell?
    let showsArrow: Bool
}

struct ArticleHeadingPresentation: Sendable {
    let level: Int
    let runs: [ArticleRun]
    let symbol: String
}

struct ArticleTabPresentation: Sendable {
    let title: String
    let blocks: [ArticlePresentationBlock]
}

enum ArticlePresentationBlock: Sendable {
    case heading(ArticleHeadingPresentation)
    case paragraph([ArticleRun])
    case list(Bool, [[ArticleRun]])
    case image(URL, String)
    case table(ArticleTablePresentation)
    case classScheme(ClassScheme)
    case tabs([ArticleTabPresentation])
    case quote([ArticleRun])
    case rule
}

// Translate only visible text. The original article structure, links and image URLs
// remain intact, so translated pages use the same native renderer as source pages.
struct GameNavigationSection: Identifiable, Sendable {
    let id: Int
    let title: String
    let items: [GameNavigationItem]
}

struct GameNavigationItem: Identifiable, Codable, Sendable {
    let id: Int
    let title: String
    let links: [GameNavigationLink]
    var children: [GameNavigationItem] = []
}

struct GameNavigationLink: Codable, Sendable {
    let title: String
    let url: URL
}
