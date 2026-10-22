import Foundation

public struct SitemapEntry: Sendable {
    public let url: URL
    public let modifiedAt: Date?
}

public struct SitemapManifest: Sendable {
    public enum Kind: Sendable { case index, pages }

    public let kind: Kind
    public let entries: [SitemapEntry]

    public static func parse(_ data: Data) throws -> Self {
        let reader = SitemapReader()
        let parser = XMLParser(data: data)
        parser.delegate = reader
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        guard parser.parse(), let kind = reader.kind else { throw URLError(.cannotParseResponse) }
        return Self(kind: kind, entries: reader.entries)
    }
}

final class SitemapReader: NSObject, XMLParserDelegate {
    private var path: [String] = []
    private var location = ""
    private var modification = ""
    private let formatter = ISO8601DateFormatter()

    private(set) var kind: SitemapManifest.Kind?
    private(set) var entries: [SitemapEntry] = []

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes attributeDict: [String: String]) {
        let name = String(elementName.split(separator: ":").last ?? "")
        path.append(name)
        if path.count == 1 {
            kind = name == "sitemapindex" ? .index : name == "urlset" ? .pages : nil
        } else if path.count == 2 && (name == "sitemap" || name == "url") {
            location = ""
            modification = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard path.count == 3, ["sitemap", "url"].contains(path[1]) else { return }
        if path[2] == "loc" { location += string }
        if path[2] == "lastmod" { modification += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        guard let name = path.last else { return }
        if path.count == 2 && (name == "sitemap" || name == "url"),
           let url = URL(string: location.trimmingCharacters(in: .whitespacesAndNewlines)) {
            let rawDate = modification.trimmingCharacters(in: .whitespacesAndNewlines)
            entries.append(SitemapEntry(url: url, modifiedAt: formatter.date(from: rawDate)))
        }
        path.removeLast()
    }
}
