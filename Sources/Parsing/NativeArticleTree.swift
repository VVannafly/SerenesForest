import SerenesParsing
import Foundation

extension NativeArticleParser {
    static func hasNestedTables(_ html: String) -> Bool {
        tree(html).descendants("table").contains { !$0.descendants("table").isEmpty }
    }

    static func parse(_ html: String, source: String) -> [ArticleBlock] {
        guard let sourceURL = URL(string: source) else { return [] }
        let root = tree(html)
        var blocks: [ArticleBlock] = []
        appendBlocks(from: root, source: sourceURL, to: &blocks)
        var represented: [URL: Int] = [:]
        func recordImages(in blocks: [ArticleBlock]) {
            for block in blocks {
            switch block {
            case .image(let url, _): represented[url, default: 0] += 1
            case .table(let rows):
                for url in rows.flatMap({ $0 }).flatMap(\.imageURLs) { represented[url, default: 0] += 1 }
            case .fatesClasses(let guide):
                for url in guide.consumedImageURLs { represented[url, default: 0] += 1 }
            case .classScheme(let scheme):
                for url in scheme.consumedImageURLs { represented[url, default: 0] += 1 }
            case .tabs(let tabs):
                for tab in tabs { recordImages(in: tab.blocks) }
            default: break
            }
            }
        }
        recordImages(in: blocks)
        for node in root.descendants("img") {
            guard let url = imageURL(node, source: sourceURL) else { continue }
            if represented[url, default: 0] > 0 { represented[url, default: 0] -= 1 }
            else { blocks.append(.image(url, node.attributes["alt"] ?? "")) }
        }
        return blocks
    }

    static let tokenPattern = try! NSRegularExpression(pattern: "<!--[\\s\\S]*?-->|<![^>]*>|<[^>]+>|[^<]+")
    static let attributePattern = try! NSRegularExpression(pattern: "([\\w:-]+)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))")
    static let voidTags: Set<String> = ["br", "hr", "img", "input", "meta", "link", "source", "wbr", "area"]
    static let blockTags: Set<String> = ["p", "div", "section", "article", "figure", "figcaption", "table", "ul", "ol", "blockquote", "h1", "h2", "h3", "h4", "h5", "h6", "hr", "pre"]

    static func tree(_ html: String, preserveNestedLists: Bool = false) -> ArticleNode {
        let root = ArticleNode("root")
        var stack = [root]
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        for match in tokenPattern.matches(in: html, range: range) {
            guard let tokenRange = Range(match.range, in: html) else { continue }
            let token = String(html[tokenRange])
            if token.hasPrefix("<!--") || token.hasPrefix("<!") { continue }
            if token.hasPrefix("</") {
                let name = tagName(token)
                if let index = stack.lastIndex(where: { $0.tag == name }), index > 0 {
                    stack.removeSubrange(index..<stack.count)
                }
            } else if token.hasPrefix("<") {
                let name = tagName(token)
                if name.isEmpty { continue }
                if ["script", "style", "noscript", "svg"].contains(name) {
                    if !token.hasSuffix("/>") {
                        let node = ArticleNode(name)
                        stack.last?.children.append(node)
                        stack.append(node)
                    }
                    continue
                }
                let tableStart = stack.lastIndex(where: { $0.tag == "table" }) ?? 0
                if name == "p" || name == "li" || name == "tr" || name == "td" || name == "th" {
                    if let index = stack.lastIndex(where: { $0.tag == name }), index > 0,
                       !["tr", "td", "th"].contains(name) || index > tableStart,
                       name != "li" || !preserveNestedLists ||
                       !stack[(index + 1)...].contains(where: { $0.tag == "ul" || $0.tag == "ol" }) {
                        stack.removeSubrange(index..<stack.count)
                    }
                }
                if name == "tr", let index = stack.lastIndex(where: { ["td", "th"].contains($0.tag) }), index > tableStart {
                    stack.removeSubrange(index..<stack.count)
                }
                if ["td", "th"].contains(name), let index = stack.lastIndex(where: { ["td", "th"].contains($0.tag) }), index > tableStart {
                    stack.removeSubrange(index..<stack.count)
                }
                if blockTags.contains(name), let index = stack.lastIndex(where: { $0.tag == "p" }), index > 0 {
                    stack.removeSubrange(index..<stack.count)
                }
                let node = ArticleNode(name, attributes: attributes(token))
                stack.last?.children.append(node)
                if !voidTags.contains(name) && !token.hasSuffix("/>") { stack.append(node) }
            } else if !["script", "style", "noscript", "svg"].contains(stack.last?.tag ?? "") {
                stack.last?.children.append(ArticleNode("#text", value: decode(token)))
            }
        }
        return root
    }

    static func tagName(_ token: String) -> String {
        let start = token.drop(while: { $0 == "<" || $0 == "/" || $0.isWhitespace })
        return String(start.prefix(while: { $0.isLetter || $0.isNumber || $0 == "-" })).lowercased()
    }

    static func attributes(_ token: String) -> [String: String] {
        var result: [String: String] = [:]
        let range = NSRange(token.startIndex..<token.endIndex, in: token)
        for match in attributePattern.matches(in: token, range: range) {
            guard let keyRange = Range(match.range(at: 1), in: token) else { continue }
            for index in 2...4 where match.range(at: index).location != NSNotFound {
                if let valueRange = Range(match.range(at: index), in: token) {
                    result[String(token[keyRange]).lowercased()] = decode(String(token[valueRange]))
                    break
                }
            }
        }
        return result
    }

    static func decode(_ value: String) -> String {
        var result = value
        let named = ["nbsp": " ", "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "hellip": "…", "ndash": "–", "mdash": "—", "rsquo": "’", "lsquo": "‘", "ldquo": "“", "rdquo": "”", "bull": "•", "times": "×"]
        for (entity, character) in named { result = result.replacingOccurrences(of: "&\(entity);", with: character) }
        let pattern = try! NSRegularExpression(pattern: "&#(x[0-9a-fA-F]+|[0-9]+);?")
        let matches = pattern.matches(in: result, range: NSRange(result.startIndex..<result.endIndex, in: result))
        for match in matches.reversed() {
            guard let full = Range(match.range, in: result), let number = Range(match.range(at: 1), in: result) else { continue }
            let raw = String(result[number])
            let value = raw.hasPrefix("x") ? UInt32(raw.dropFirst(), radix: 16) : UInt32(raw)
            if let value, let scalar = UnicodeScalar(value) { result.replaceSubrange(full, with: String(scalar)) }
        }
        return result
    }

    static func resolved(_ raw: String?, source: URL) -> URL? {
        guard let raw else { return nil }
        let trimmedRaw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRaw.isEmpty, !trimmedRaw.hasPrefix("data:"),
              let url = URL(string: trimmedRaw, relativeTo: source)?.absoluteURL,
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return SiteScope.canonical(url) ?? url
    }

    static func imageURL(_ node: ArticleNode, source: URL) -> URL? {
        [node.attributes["src"], node.attributes["data-src"], node.attributes["data-lazy-src"]]
            .compactMap { resolved($0, source: source) }.first
    }

    static func runs(_ node: ArticleNode, source: URL, link: URL? = nil, strong: Bool = false, italic: Bool = false) -> [ArticleRun] {
        if node.tag == "#text" { return [ArticleRun(text: node.value, url: link, strong: strong, italic: italic)] }
        if node.tag == "br" { return [ArticleRun(text: "\n", url: link)] }
        if node.tag == "img" || ["script", "style", "noscript", "svg"].contains(node.tag) { return [] }
        if node.tag == "select" {
            let choices = node.children.filter { $0.tag == "option" }
                .map { trimmed(runs($0, source: source)).map(\.text).joined() }
                .filter { !$0.isEmpty }
            return choices.isEmpty ? [] : [ArticleRun(text: "[\(choices.joined(separator: ", "))]", url: nil)]
        }
        let nextLink = node.tag == "a" ? resolved(node.attributes["href"], source: source) : link
        let isStrong = strong || ["b", "strong", "th"].contains(node.tag)
        let isItalic = italic || ["i", "em"].contains(node.tag)
        return node.children.flatMap { runs($0, source: source, link: nextLink, strong: isStrong, italic: isItalic) }
    }

    static func trimmed(_ input: [ArticleRun]) -> [ArticleRun] {
        var output: [ArticleRun] = []
        for run in input {
            let clean = run.text.replacingOccurrences(of: "[\\t\\r ]+", with: " ", options: .regularExpression)
            if !clean.isEmpty { output.append(ArticleRun(text: clean, url: run.url, strong: run.strong, italic: run.italic)) }
        }
        while let first = output.first, first.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { output.removeFirst() }
        while let last = output.last, last.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { output.removeLast() }
        if !output.isEmpty {
            output[0].text = output[0].text.trimmingCharacters(in: .whitespacesAndNewlines)
            output[output.count - 1].text = output[output.count - 1].text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return output.filter { !$0.text.isEmpty }
    }

}
