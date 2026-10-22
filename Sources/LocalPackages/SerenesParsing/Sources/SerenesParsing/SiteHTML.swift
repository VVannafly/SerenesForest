import Foundation

public struct ParsedPage: Sendable {
    public let title: String
    public let html: String
    public let plainText: String
    public let links: [(url: URL, title: String)]
    public let images: [URL]

    public init(title: String, html: String, plainText: String,
                links: [(url: URL, title: String)], images: [URL]) {
        self.title = title
        self.html = html
        self.plainText = plainText
        self.links = links
        self.images = images
    }

}

public enum SiteHTML {
    public static func isChallenge(title: String, html: String = "") -> Bool {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.hasPrefix("one moment, please") || normalized == "just a moment..." ||
            html.localizedCaseInsensitiveContains("please wait while your request is being verified") ||
            html.localizedCaseInsensitiveContains("checking your browser before accessing")
    }

    private static func entryContent(in html: String) -> String? {
        guard let opening = try? NSRegularExpression(pattern: "<div\\b[^>]*class=[\"'][^\"']*\\b(?:entry|mw-parser-output)\\b[^\"']*[\"'][^>]*>", options: [.caseInsensitive]),
              let tag = try? NSRegularExpression(pattern: "</?div\\b[^>]*>", options: [.caseInsensitive]),
              let start = opening.firstMatch(in: html, range: NSRange(html.startIndex..<html.endIndex, in: html)),
              let contentStart = Range(start.range, in: html)?.upperBound else { return nil }
        var depth = 1
        let remaining = NSRange(contentStart..<html.endIndex, in: html)
        for match in tag.matches(in: html, range: remaining) {
            guard let range = Range(match.range, in: html) else { continue }
            if html[range].hasPrefix("</") { depth -= 1 } else { depth += 1 }
            if depth == 0 { return String(html[contentStart..<range.lowerBound]) }
        }
        return nil
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let captured = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captured])
    }

    private static func replacing(_ pattern: String, in text: String, with replacement: String = "") -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return text }
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text), withTemplate: replacement)
    }

    public static func cleanText(_ html: String) -> String {
        var value = replacing("<(script|style|noscript)[^>]*>[\\s\\S]*?</\\1>", in: html)
        value = replacing("<(br|/p|/div|/tr|/li|/h[1-6])[^>]*>", in: value, with: "\n")
        value = replacing("<[^>]+>", in: value)
        for (encoded, decoded) in ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&#8217;": "’", "&#8211;": "–"] {
            value = value.replacingOccurrences(of: encoded, with: decoded)
        }
        value = replacing("[ \\t]+", in: value, with: " ")
        value = replacing("\\n{3,}", in: value, with: "\n\n")
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func parse(_ html: String, source: URL) -> ParsedPage {
        let body = firstMatch("<body[^>]*>([\\s\\S]*?)</body>", in: html) ?? html
        let titleHTML = firstMatch("<h2[^>]*class=[\"'][^\"']*page-title[^\"']*[\"'][^>]*>([\\s\\S]*?)</h2>", in: body)
            ?? firstMatch("<h1[^>]*>([\\s\\S]*?)</h1>", in: body)
            ?? firstMatch("<title[^>]*>([\\s\\S]*?)</title>", in: html) ?? source.lastPathComponent
        let title = cleanText(titleHTML)
        let content = entryContent(in: body)
            ?? firstMatch("<main[^>]*>([\\s\\S]*?)</main>", in: body)
            ?? firstMatch("<article[^>]*>([\\s\\S]*?)</article>", in: body)
            ?? body
        var links: [(URL, String)] = []
        let linkSource = source.host == "wiki.serenesforest.net" ? content : body
        if let regex = try? NSRegularExpression(pattern: "<a\\b[^>]*href=[\"']([^\"']+)[\"'][^>]*>([\\s\\S]*?)</a>", options: [.caseInsensitive]) {
            let range = NSRange(linkSource.startIndex..<linkSource.endIndex, in: linkSource)
            for match in regex.matches(in: linkSource, range: range) {
                guard let hrefRange = Range(match.range(at: 1), in: linkSource),
                      let textRange = Range(match.range(at: 2), in: linkSource),
                      let rawURL = URL(string: String(linkSource[hrefRange]).replacingOccurrences(of: "&amp;", with: "&"), relativeTo: source)?.absoluteURL,
                      let url = SiteScope.canonical(rawURL) else { continue }
                let label = cleanText(String(linkSource[textRange]))
                links.append((url, label.isEmpty ? url.lastPathComponent : label))
            }
        }
        var images: [URL] = []
        if let regex = try? NSRegularExpression(pattern: "\\b(?:src|data-src|data-lazy-src)=[\"']([^\"']+)[\"']", options: [.caseInsensitive]) {
            let range = NSRange(content.startIndex..<content.endIndex, in: content)
            for match in regex.matches(in: content, range: range) {
                guard let valueRange = Range(match.range(at: 1), in: content),
                      let rawURL = URL(string: String(content[valueRange]).replacingOccurrences(of: "&amp;", with: "&"), relativeTo: source)?.absoluteURL,
                      let url = SiteScope.canonical(rawURL), SiteScope.isAsset(url) else { continue }
                images.append(url)
            }
        }
        return ParsedPage(title: title, html: content, plainText: cleanText(content), links: links, images: images)
    }

}
