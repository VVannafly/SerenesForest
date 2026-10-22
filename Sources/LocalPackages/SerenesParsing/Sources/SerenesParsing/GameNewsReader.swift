import Foundation

public struct GameNewsItem: Sendable {
    public var title = ""
    public var url = ""
    public var published = ""
    public var content = ""
    public var summary = ""
}

public enum GameNewsReader {
    public static func parse(_ data: Data) throws -> [GameNewsItem] {
        try RSSReader.parse(data)
    }
}

private final class RSSReader: NSObject, XMLParserDelegate {
    private var path: [String] = []
    private var current: GameNewsItem?
    private(set) var items: [GameNewsItem] = []

    static func parse(_ data: Data) throws -> [GameNewsItem] {
        let reader = RSSReader()
        let parser = XMLParser(data: data)
        parser.delegate = reader
        parser.shouldProcessNamespaces = false
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else { throw URLError(.cannotParseResponse) }
        return reader.items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName: String?, attributes attributeDict: [String: String]) {
        path.append(elementName)
        if path == ["rss", "channel", "item"] { current = GameNewsItem() }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { append(string) }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let value = String(data: CDATABlock, encoding: .utf8) { append(value) }
    }

    private func append(_ value: String) {
        guard path.count == 4, path[2] == "item", current != nil else { return }
        switch path[3] {
        case "title": current?.title += value
        case "link": current?.url += value
        case "pubDate": current?.published += value
        case "content:encoded": current?.content += value
        case "description": current?.summary += value
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName: String?) {
        if path == ["rss", "channel", "item"], let current {
            items.append(current)
            self.current = nil
        }
        if !path.isEmpty { path.removeLast() }
    }
}
