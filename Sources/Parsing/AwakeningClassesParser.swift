import Foundation

private enum Constants {
    static let path = "awakening/classes/introduction"
}

enum AwakeningClassesParser {
    private static let promotions: [String: [String]] = [
        "Lord": ["Great Lord"],
        "Tactician": ["Grandmaster"],
        "Cavalier": ["Paladin", "Great Knight"],
        "Knight": ["Great Knight", "General"],
        "Myrmidon": ["Swordmaster", "Assassin"],
        "Thief": ["Assassin", "Trickster"],
        "Barbarian": ["Berserker", "Warrior"],
        "Fighter": ["Warrior", "Hero"],
        "Mercenary": ["Hero", "Bow Knight"],
        "Archer": ["Bow Knight", "Sniper"],
        "Pegasus Knight": ["Falcon Knight", "Dark Flier"],
        "Wyvern Rider": ["Wyvern Lord", "Griffon Rider"],
        "Dark Mage": ["Sorcerer", "Dark Knight"],
        "Mage": ["Dark Knight", "Sage"],
        "Priest, Cleric": ["Sage", "War Monk, War Cleric"],
        "Troubadour": ["War Monk, War Cleric", "Valkyrie"]
    ]

    static func accepts(_ source: URL) -> Bool {
        source.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == Constants.path
    }

    static func parse(_ node: ArticleNode, source: URL) -> FatesClassGuide? {
        guard accepts(source) else { return nil }
        return TwoStageClassGuideParser.parse(node, source: source, relationships: promotions)
    }
}
