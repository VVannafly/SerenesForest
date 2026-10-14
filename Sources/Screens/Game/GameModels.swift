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
