import Foundation

struct ClassSchemeUpgrade: Codable, Sendable {
    let runs: [ArticleRun]
    let imageURLs: [URL]
}

struct ClassSchemeBranch: Codable, Sendable {
    let entry: FatesClassEntry
    let upgrade: ClassSchemeUpgrade?
    let children: [ClassSchemeBranch]
}

struct ClassScheme: Codable, Sendable {
    let version: Int
    let stageTitles: [String]
    let roots: [ClassSchemeBranch]
    let unassignedEntries: [FatesClassEntry]
    let consumedImageURLs: [URL]

    init(stageTitles: [String], roots: [ClassSchemeBranch],
         unassignedEntries: [FatesClassEntry] = [], consumedImageURLs: [URL]) {
        version = 2
        self.stageTitles = stageTitles
        self.roots = roots
        self.unassignedEntries = unassignedEntries
        self.consumedImageURLs = consumedImageURLs
    }

    private enum CodingKeys: String, CodingKey {
        case version, stageTitles, roots, unassignedEntries, consumedImageURLs
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        stageTitles = try values.decode([String].self, forKey: .stageTitles)
        roots = try values.decode([ClassSchemeBranch].self, forKey: .roots)
        unassignedEntries = try values.decodeIfPresent([FatesClassEntry].self, forKey: .unassignedEntries) ?? []
        consumedImageURLs = try values.decode([URL].self, forKey: .consumedImageURLs)
    }
}

enum ClassSchemeBuilder {
    static func build(from guide: FatesClassGuide) -> ClassScheme {
        let roots = guide.groups.map { group in
            ClassSchemeBranch(entry: group.base, upgrade: nil,
                              children: group.promotions.map {
                                  ClassSchemeBranch(entry: $0, upgrade: nil, children: [])
                              })
        }
        return ClassScheme(stageTitles: [guide.baseTitle.map(\.text).joined(),
                                         guide.promotedTitle.map(\.text).joined()],
                           roots: roots, unassignedEntries: guide.unassignedPromotions,
                           consumedImageURLs: guide.consumedImageURLs)
    }
}
