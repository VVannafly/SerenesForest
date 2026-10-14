import Foundation

struct FatesClassEntry: Codable {
    let name: String
    let runs: [ArticleRun]
    let artworkURL: URL?
    let iconURLs: [URL]
}

struct FatesClassGroup: Codable {
    let base: FatesClassEntry
    let promotions: [FatesClassEntry]
}

struct FatesClassGuide: Codable {
    let baseTitle: [ArticleRun]
    let promotedTitle: [ArticleRun]
    let groups: [FatesClassGroup]
    let unassignedPromotions: [FatesClassEntry]
    let consumedImageURLs: [URL]
}
