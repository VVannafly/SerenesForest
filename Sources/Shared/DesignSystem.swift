import SwiftUI

enum Palette {
    static let ink = Color(red: 0.08, green: 0.10, blue: 0.17)
    static let accent = Color(red: 0.43, green: 0.36, blue: 0.93)
    static let soft = Color(red: 0.90, green: 0.88, blue: 1.0)
}

enum HeaderLayout {
    static let controlHeight: CGFloat = 40
}

enum AppText {
    private static var language: String { UserDefaults.standard.string(forKey: "SerenesForest.language") ?? "en" }
    static var isRussian: Bool { language == "ru" }

    static func localized(_ value: String.LocalizationValue) -> String {
        String(localized: value, locale: Locale(identifier: language))
    }

    static func title(_ page: ContentPage) -> String {
        isRussian ? (page.russianTitle ?? page.title) : page.title
    }

    static func chapterLabel(_ label: String) -> String {
        guard isRussian else { return label }
        if label == "Contents" { return "Содержание" }
        if label == "Prologue" { return "Пролог" }
        if label == "Epilogue" { return "Эпилог" }
        return label.replacingOccurrences(of: "Chapter ", with: "Глава ")
            .replacingOccurrences(of: "Act ", with: "Акт ")
            .replacingOccurrences(of: "east route", with: "восточный путь")
            .replacingOccurrences(of: "west route", with: "западный путь")
    }

    static func matches(_ page: ContentPage, query: String) -> Bool {
        query.isEmpty || page.title.localizedCaseInsensitiveContains(query) ||
            page.plainText.localizedCaseInsensitiveContains(query) ||
            (isRussian && (page.russianTitle?.localizedCaseInsensitiveContains(query) == true ||
                           page.russianPlainText?.localizedCaseInsensitiveContains(query) == true))
    }

    static func count(_ value: Int, english: String, russian: (String, String, String)) -> String {
        guard isRussian else { return "\(value) \(english)" }
        let lastTwo = value % 100
        let form = lastTwo >= 11 && lastTwo <= 14 ? russian.2 :
            value % 10 == 1 ? russian.0 :
            (2...4).contains(value % 10) ? russian.1 : russian.2
        return "\(value) \(form)"
    }
}

enum TranslationAvailability {
    static var isSupported: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }
}

struct NavigationTranslationsKey: EnvironmentKey {
    static let defaultValue: [String: String] = [:]
}

extension EnvironmentValues {
    var navigationTranslations: [String: String] {
        get { self[NavigationTranslationsKey.self] }
        set { self[NavigationTranslationsKey.self] = newValue }
    }
}

struct GameTheme {
    let accent: Color
    let secondary: Color
    let motif: String

    static func forGame(_ slug: String) -> Self {
        switch slug {
        case "three-houses": .init(accent: Color(red: 0.68, green: 0.48, blue: 0.19), secondary: Color(red: 0.22, green: 0.34, blue: 0.56), motif: "crown.fill")
        case "engage": .init(accent: Color(red: 0.18, green: 0.49, blue: 0.72), secondary: Color(red: 0.76, green: 0.26, blue: 0.30), motif: "circle.hexagongrid.fill")
        case "fire-emblem-fates": .init(accent: Color(red: 0.55, green: 0.28, blue: 0.39), secondary: Color(red: 0.26, green: 0.37, blue: 0.58), motif: "moon.stars.fill")
        case "awakening": .init(accent: Color(red: 0.20, green: 0.42, blue: 0.66), secondary: Color(red: 0.74, green: 0.55, blue: 0.28), motif: "sparkle")
        case "fire-emblem-echoes-shadows-valentia": .init(accent: Color(red: 0.48, green: 0.37, blue: 0.65), secondary: Color(red: 0.68, green: 0.48, blue: 0.25), motif: "sun.max.fill")
        case "path-of-radiance", "radiant-dawn": .init(accent: Color(red: 0.23, green: 0.48, blue: 0.67), secondary: Color(red: 0.70, green: 0.49, blue: 0.25), motif: "bird.fill")
        case "genealogy-of-the-holy-war", "thracia-776": .init(accent: Color(red: 0.52, green: 0.36, blue: 0.60), secondary: Color(red: 0.72, green: 0.48, blue: 0.28), motif: "shield.checkered")
        case "binding-blade", "blazing-sword", "the-sacred-stones": .init(accent: Color(red: 0.70, green: 0.31, blue: 0.27), secondary: Color(red: 0.36, green: 0.47, blue: 0.64), motif: "flame.fill")
        case "shadow-dragon", "shadow-dragon-and-blade-of-light", "light-and-shadow", "mystery-of-the-emblem": .init(accent: Color(red: 0.30, green: 0.44, blue: 0.68), secondary: Color(red: 0.64, green: 0.42, blue: 0.29), motif: "shield.fill")
        case "fire-emblem-heroes": .init(accent: Color(red: 0.57, green: 0.38, blue: 0.70), secondary: Color(red: 0.74, green: 0.53, blue: 0.24), motif: "star.fill")
        case "fire-emblem-warriors": .init(accent: Color(red: 0.67, green: 0.26, blue: 0.30), secondary: Color(red: 0.41, green: 0.47, blue: 0.55), motif: "bolt.shield.fill")
        case "warriors-three-hopes": .init(accent: Color(red: 0.69, green: 0.28, blue: 0.42), secondary: Color(red: 0.80, green: 0.45, blue: 0.28), motif: "crown.fill")
        case "tokyo-mirage-sessions": .init(accent: Color(red: 0.23, green: 0.58, blue: 0.52), secondary: Color(red: 0.64, green: 0.43, blue: 0.72), motif: "music.note")
        case "gaiden": .init(accent: Color(red: 0.59, green: 0.38, blue: 0.31), secondary: Color(red: 0.34, green: 0.51, blue: 0.53), motif: "sun.horizon.fill")
        case "fortunes-weave": .init(accent: Color(red: 0.63, green: 0.35, blue: 0.39), secondary: Color(red: 0.37, green: 0.44, blue: 0.69), motif: "diamond.fill")
        default: .init(accent: Color(red: 0.40, green: 0.49, blue: 0.62), secondary: Color(red: 0.72, green: 0.48, blue: 0.30), motif: "shield.lefthalf.filled")
        }
    }

    func color(for section: GameSection) -> Color {
        switch section {
        case .general, .characters, .classes: accent
        case .scripts, .inventory, .miscellaneous: secondary
        }
    }
}

enum Destination: String, Hashable, CaseIterable {
    case discover = "Discover"
    case library = "Library"
    case favorites = "Favorites"
    case menu = "Menu"
    case savedPages = "Saved pages"
    case news = "News"
    case guides = "Guides"
    case wiki = "Fire Emblem Wiki"
    case allPages = "All pages"
    case media = "Media"
    case settings = "Settings"

    var symbol: String {
        switch self {
        case .discover: "sparkles.rectangle.stack"
        case .library: "square.grid.2x2.fill"
        case .favorites: "heart.fill"
        case .menu: "line.3.horizontal"
        case .savedPages: "bookmark.fill"
        case .news: "newspaper.fill"
        case .guides: "text.book.closed.fill"
        case .wiki: "books.vertical.fill"
        case .allPages: "square.stack.fill"
        case .media: "photo.on.rectangle.angled"
        case .settings: "gearshape.fill"
        }
    }

    static let menuItems: [Destination] = [
        .savedPages, .news, .guides, .wiki, .allPages, .media, .settings
    ]
}

enum GameSection: String {
    case general = "General"
    case scripts = "Scripts"
    case characters = "Characters"
    case classes = "Classes"
    case inventory = "Inventory"
    case miscellaneous = "Miscellaneous"

    var symbol: String {
        switch self {
        case .general: "map.fill"
        case .scripts: "text.book.closed.fill"
        case .characters: "person.2.fill"
        case .classes: "shield.lefthalf.filled"
        case .inventory: "bag.fill"
        case .miscellaneous: "square.stack.3d.up.fill"
        }
    }

    var tint: Color {
        switch self {
        case .general: Color(red: 0.28, green: 0.49, blue: 0.75)
        case .scripts: Color(red: 0.60, green: 0.42, blue: 0.78)
        case .characters: Color(red: 0.72, green: 0.36, blue: 0.45)
        case .classes: Color(red: 0.30, green: 0.58, blue: 0.52)
        case .inventory: Color(red: 0.68, green: 0.48, blue: 0.23)
        case .miscellaneous: Color(red: 0.42, green: 0.48, blue: 0.67)
        }
    }

    static func style(for title: String) -> Self {
        let name = title.lowercased()
        if name.contains("script") || name.contains("article") { return .scripts }
        if name.contains("character") || name.contains("hero") || name.contains("emblem") { return .characters }
        if name.contains("class") { return .classes }
        if name.contains("weapon") || name.contains("item") || name.contains("inventor") { return .inventory }
        if name.contains("general") || name.contains("beginner") { return .general }
        return .miscellaneous
    }
}
