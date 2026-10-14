import Foundation

struct ClassSchemeUpgrade: Codable {
    let runs: [ArticleRun]
    let imageURLs: [URL]
}

struct ClassSchemeBranch: Codable {
    let entry: FatesClassEntry
    let upgrade: ClassSchemeUpgrade?
    let children: [ClassSchemeBranch]
}

struct ClassScheme: Codable {
    let version: Int
    let stageTitles: [String]
    let roots: [ClassSchemeBranch]
    let consumedImageURLs: [URL]

    init(stageTitles: [String], roots: [ClassSchemeBranch], consumedImageURLs: [URL]) {
        version = 2
        self.stageTitles = stageTitles
        self.roots = roots
        self.consumedImageURLs = consumedImageURLs
    }
}
