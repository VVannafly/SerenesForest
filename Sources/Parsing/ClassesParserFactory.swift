import Foundation

enum ClassesParserFactory {
    private enum Strategy {
        case fates
        case awakening
        case sacredStones

        func parse(_ table: ArticleNode, source: URL) -> ArticleBlock? {
            switch self {
            case .fates:
                return FatesClassesParser.parse(table, source: source)
                    .map { .classScheme(ClassSchemeBuilder.build(from: $0)) }
            case .awakening:
                return AwakeningClassesParser.parse(table, source: source)
                    .map { .classScheme(ClassSchemeBuilder.build(from: $0)) }
            case .sacredStones:
                return SacredStonesClassSchemeParser.parse(table, source: source).map(ArticleBlock.classScheme)
            }
        }

        func isRepresented(by block: ArticleBlock) -> Bool {
            switch (self, block) {
            case (.fates, .classScheme), (.awakening, .classScheme),
                 (.sacredStones, .classScheme):
                return true
            case (_, .tabs(let tabs)):
                return tabs.contains { tab in tab.blocks.contains(where: isRepresented) }
            default:
                return false
            }
        }
    }

    static func parse(_ table: ArticleNode, source: URL) -> ArticleBlock? {
        strategy(for: source)?.parse(table, source: source)
    }

    static func needsCacheRepair(source: URL, blocks: [ArticleBlock]?) -> Bool {
        guard let strategy = strategy(for: source), let blocks else { return false }
        return !blocks.contains(where: strategy.isRepresented)
    }

    private static func strategy(for source: URL) -> Strategy? {
        if FatesClassesParser.accepts(source) { return .fates }
        if AwakeningClassesParser.accepts(source) { return .awakening }
        if SacredStonesClassSchemeParser.accepts(source) { return .sacredStones }
        return nil
    }
}
