import Foundation

enum ArticleTranslation {
    static func plainText(_ blocks: [ArticleBlock]) -> String {
        blocks.map { block -> String in
            switch block {
            case .heading(_, let runs), .paragraph(let runs), .quote(let runs):
                return runs.map(\.text).joined()
            case .list(_, let items):
                return items.map { $0.map(\.text).joined() }.joined(separator: "\n")
            case .image(_, let alt): return alt
            case .table(let rows):
                return rows.map { $0.map { $0.runs.map(\.text).joined() }.joined(separator: " ") }.joined(separator: "\n")
            case .fatesClasses(let guide):
                return guide.groups.map { group in
                    ([group.base] + group.promotions).map { $0.runs.map(\.text).joined() }.joined(separator: "\n")
                }.joined(separator: "\n") + "\n" + guide.unassignedPromotions.map { $0.runs.map(\.text).joined() }.joined(separator: "\n")
            case .classScheme(let scheme):
                func text(_ branch: ClassSchemeBranch) -> String {
                    ([branch.entry.runs.map(\.text).joined(), branch.upgrade?.runs.map(\.text).joined() ?? ""] +
                     branch.children.map(text)).joined(separator: "\n")
                }
                return scheme.roots.map(text).joined(separator: "\n")
            case .tabs(let tabs):
                return tabs.map { $0.title + "\n" + plainText($0.blocks) }.joined(separator: "\n")
            case .rule: return ""
            }
        }.joined(separator: "\n")
    }

    static func sourceTexts(title: String, blocks: [ArticleBlock]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        func append(_ value: String) {
            let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, text.rangeOfCharacter(from: .letters) != nil,
                  seen.insert(text).inserted else { return }
            result.append(text)
        }
        append(title)
        for block in blocks {
            switch block {
            case .heading(_, let runs), .paragraph(let runs), .quote(let runs):
                runs.forEach { append($0.text) }
            case .list(_, let items):
                items.flatMap { $0 }.forEach { append($0.text) }
            case .image(_, let alt): append(alt)
            case .table(let rows):
                rows.flatMap { $0 }.flatMap(\.runs).forEach { append($0.text) }
            case .fatesClasses(let guide):
                (guide.baseTitle + guide.promotedTitle).forEach { append($0.text) }
                for entry in guide.groups.flatMap({ [$0.base] + $0.promotions }) + guide.unassignedPromotions {
                    entry.runs.forEach { append($0.text) }
                }
            case .classScheme(let scheme):
                scheme.stageTitles.forEach(append)
                func visit(_ branch: ClassSchemeBranch) {
                    branch.entry.runs.forEach { append($0.text) }
                    branch.upgrade?.runs.forEach { append($0.text) }
                    branch.children.forEach(visit)
                }
                scheme.roots.forEach(visit)
            case .tabs(let tabs):
                for tab in tabs {
                    append(tab.title)
                    sourceTexts(title: "", blocks: tab.blocks).forEach(append)
                }
            case .rule: break
            }
        }
        return result
    }

    static func apply(_ translations: [String: String], to blocks: [ArticleBlock]) -> [ArticleBlock] {
        func text(_ value: String) -> String {
            let source = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let translated = translations[source], !translated.isEmpty else { return value }
            let leading = value.prefix(while: { $0.isWhitespace })
            let trailing = value.reversed().prefix(while: { $0.isWhitespace }).reversed()
            return String(leading) + translated + String(trailing)
        }
        func runs(_ values: [ArticleRun]) -> [ArticleRun] {
            values.map { run in
                var result = run
                result.text = text(run.text)
                return result
            }
        }
        func entry(_ source: FatesClassEntry) -> FatesClassEntry {
            FatesClassEntry(name: source.name, runs: runs(source.runs),
                            artworkURL: source.artworkURL, iconURLs: source.iconURLs)
        }
        func branch(_ source: ClassSchemeBranch) -> ClassSchemeBranch {
            ClassSchemeBranch(entry: entry(source.entry),
                              upgrade: source.upgrade.map {
                                  ClassSchemeUpgrade(runs: runs($0.runs), imageURLs: $0.imageURLs)
                              },
                              children: source.children.map(branch))
        }
        return blocks.map { block in
            switch block {
            case .heading(let level, let content): .heading(level, runs(content))
            case .paragraph(let content): .paragraph(runs(content))
            case .quote(let content): .quote(runs(content))
            case .list(let ordered, let items): .list(ordered, items.map(runs))
            case .image(let url, let alt): .image(url, text(alt))
            case .table(let rows): .table(rows.map { row in row.map { cell in
                var result = cell
                result.runs = runs(cell.runs)
                return result
            } })
            case .fatesClasses(let guide): .fatesClasses(FatesClassGuide(
                baseTitle: runs(guide.baseTitle), promotedTitle: runs(guide.promotedTitle),
                groups: guide.groups.map { FatesClassGroup(base: entry($0.base), promotions: $0.promotions.map(entry)) },
                unassignedPromotions: guide.unassignedPromotions.map(entry),
                consumedImageURLs: guide.consumedImageURLs
            ))
            case .classScheme(let scheme): .classScheme(ClassScheme(
                stageTitles: scheme.stageTitles.map(text), roots: scheme.roots.map(branch),
                consumedImageURLs: scheme.consumedImageURLs
            ))
            case .tabs(let tabs): .tabs(tabs.map { tab in
                ArticleTab(title: text(tab.title), blocks: apply(translations, to: tab.blocks))
            })
            case .rule: .rule
            }
        }
    }
}
