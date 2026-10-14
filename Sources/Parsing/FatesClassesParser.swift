import Foundation

private enum Constants {
    static let hoshidanPath = "fire-emblem-fates/hoshidan-classes"
    static let nohrianPath = "fire-emblem-fates/nohrian-classes"
}

enum FatesClassesParser {
    private static let hoshidanPromotions: [String: [String]] = [
        "Nohr Prince(ss)": ["Hoshido Noble"],
        "Samurai": ["Swordmaster", "Master of Arms"],
        "Villager": ["Master of Arms", "Merchant"],
        "Apothecary": ["Merchant", "Mechanist"],
        "Ninja": ["Mechanist", "Master Ninja"],
        "Oni Savage": ["Oni Chieftain", "Blacksmith"],
        "Spear Fighter": ["Spear Master", "Basara"],
        "Diviner": ["Basara", "Onmyoji"],
        "Monk": ["Onmyoji", "Great Master"],
        "Shrine Maiden": ["Onmyoji", "Priestess"],
        "Sky Knight": ["Falcon Knight", "Kinshi Knight"],
        "Archer": ["Kinshi Knight", "Sniper"],
        "Kitsune": ["Nine-Tails"],
        "Songstress": []
    ]

    private static let nohrianPromotions: [String: [String]] = [
        "Nohr Prince(ss)": ["Nohr Noble"],
        "Cavalier": ["Paladin", "Great Knight"],
        "Knight": ["Great Knight", "General"],
        "Fighter": ["Berserker", "Hero"],
        "Mercenary": ["Hero", "Bow Knight"],
        "Outlaw": ["Bow Knight", "Adventurer"],
        "Wyvern Rider": ["Wyvern Lord", "Malig Knight"],
        "Dark Mage": ["Sorcerer", "Dark Knight"],
        "Troubadour": ["Strategist", "Butler", "Maid"],
        "Wolfskin": ["Wolfssegner"]
    ]

    static func accepts(_ source: URL) -> Bool {
        promotions(for: source) != nil
    }

    static func parse(_ node: ArticleNode, source: URL) -> FatesClassGuide? {
        guard let relationships = promotions(for: source) else { return nil }
        return TwoStageClassGuideParser.parse(node, source: source, relationships: relationships)
    }

    private static func promotions(for source: URL) -> [String: [String]]? {
        let path = source.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        switch path {
        case Constants.hoshidanPath: return hoshidanPromotions
        case Constants.nohrianPath: return nohrianPromotions
        default: return nil
        }
    }

}
