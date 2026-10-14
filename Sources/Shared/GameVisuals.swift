import SwiftUI

enum GameProgress: String, CaseIterable, Identifiable {
    case unplayed = "Unplayed"
    case backlog = "Backlog"
    case inProgress = "In progress"
    case completed = "Completed"

    var id: Self { self }

    init(status: String) {
        self = Self(rawValue: status) ?? (status == "Playing" ? .inProgress : .unplayed)
    }

    var symbol: String {
        switch self {
        case .unplayed: "circle.dashed"
        case .backlog: "bookmark.fill"
        case .inProgress: "play.fill"
        case .completed: "checkmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .unplayed: .secondary
        case .backlog: Color(red: 0.65, green: 0.45, blue: 0.22)
        case .inProgress: Color(red: 0.25, green: 0.52, blue: 0.79)
        case .completed: Color(red: 0.25, green: 0.58, blue: 0.43)
        }
    }
}

struct ContentIcon: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 36

    init(title: String, section: GameSection? = nil, size: CGFloat = 36, tint overrideTint: Color? = nil, symbol overrideSymbol: String? = nil) {
        self.size = size
        let name = title.lowercased()
        let section = section ?? .general
        tint = overrideTint ?? section.tint
        if let overrideSymbol {
            symbol = overrideSymbol
        } else if name.contains("support") || name.contains("conversation") || name.contains("relationship") {
            symbol = "bubble.left.and.bubble.right.fill"
        } else if name.contains("character") || name.contains("hero") || name.contains("unit") || name.contains("avatar") || name.contains("recruit") || name.contains("child") {
            symbol = "person.crop.square.fill"
        } else if name.contains("class") || name.contains("promotion") || name.contains("skill") || name.contains("ability") {
            symbol = "shield.lefthalf.filled"
        } else if name.contains("weapon") || name.contains("sword") || name.contains("lance") || name.contains("axe") || name.contains("bow") || name.contains("tome") {
            symbol = "hammer.fill"
        } else if name.contains("item") || name.contains("shop") || name.contains("treasure") || name.contains("equipment") || name.contains("inventory") {
            symbol = "bag.fill"
        } else if name.contains("script") || name.contains("story") || name.contains("dialogue") || name.contains("ending") || name.contains("memory") {
            symbol = "text.book.closed.fill"
        } else if name.contains("chapter") || name.contains("map") || name.contains("walkthrough") || name.contains("paralogue") {
            symbol = "map.fill"
        } else if name.contains("music") || name.contains("soundtrack") || name.contains("ost") {
            symbol = "music.note"
        } else if name.contains("art") || name.contains("gallery") || name.contains("image") || name.contains("portrait") {
            symbol = "photo.fill"
        } else if name.contains("guide") || name.contains("tutorial") || name.contains("beginner") {
            symbol = "book.closed.fill"
        } else if name.contains("stat") || name.contains("growth") || name.contains("rank") {
            symbol = "chart.bar.fill"
        } else {
            symbol = section.symbol
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: size * 0.27))
            .accessibilityHidden(true)
    }
}
