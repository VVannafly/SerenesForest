import Foundation

struct FatesClassEntry: Codable, Sendable {
    let name: String
    let runs: [ArticleRun]
    let artworkURL: URL?
    let iconURLs: [URL]
}

struct FatesClassGroup: Codable, Sendable {
    let base: FatesClassEntry
    let promotions: [FatesClassEntry]
}

struct FatesClassGuide: Codable, Sendable {
    let baseTitle: [ArticleRun]
    let promotedTitle: [ArticleRun]
    let groups: [FatesClassGroup]
    let unassignedPromotions: [FatesClassEntry]
    let consumedImageURLs: [URL]
}
