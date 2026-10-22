import SwiftUI

enum FatesRoute: String, CaseIterable, Identifiable {
    case birthright = "Birthright"
    case conquest = "Conquest"
    case revelation = "Revelation"

    var id: String { rawValue }

    func includes(_ title: String) -> Bool {
        if title.hasPrefix("Birthright - Hoshido") { return self == .birthright }
        if title.hasPrefix("Conquest - Nohr") { return self == .conquest }
        if title.hasPrefix("Revelation") { return self == .revelation }
        return true // General and All Routes information belongs to every route.
    }
}

struct WikiGuideEntry: Identifiable {
    let page: ContentPage
    let position: Int?
    let label: String?
    var id: String { page.url }
}

struct WikiGuideSection: Identifiable {
    let title: String
    let entries: [WikiGuideEntry]
    var id: String { title }
}

enum RecentGamesHistory {
    static let storageKey = "SerenesForest.recentGames"
    static let limit = 8

    static func record(_ slug: String, in stored: String) -> String {
        let previous = stored.split(separator: "|").map(String.init)
        return ([slug] + previous.filter { $0 != slug }).prefix(limit).joined(separator: "|")
    }

    static func games(from available: [Game], stored: String) -> [Game] {
        let bySlug = Dictionary(uniqueKeysWithValues: available.map { ($0.slug, $0) })
        return stored.split(separator: "|").prefix(limit).compactMap { bySlug[String($0)] }
    }
}
