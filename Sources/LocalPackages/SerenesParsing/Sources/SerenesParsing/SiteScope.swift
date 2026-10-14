import Foundation

public enum SiteScope {
    public static let home = "https://serenesforest.net/"
    private static let assetExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "svg", "avif", "pdf", "mp3", "m4a", "ogg", "mp4", "webm", "zip"]

    public static func canonical(_ candidate: URL) -> URL? {
        let host = candidate.host?.lowercased() ?? ""
        let isWiki = host == "wiki.serenesforest.net"
        let isWikiAssetHost = host == "s3-wiki.serenesforest.net"
        let isFireEmblemWikiAssetHost = host == "cdn.fireemblemwiki.org"
        guard ["http", "https"].contains(candidate.scheme?.lowercased() ?? ""),
              isWiki || isWikiAssetHost || isFireEmblemWikiAssetHost ||
              ["serenesforest.net", "www.serenesforest.net"].contains(host) else { return nil }
        var components = URLComponents(url: candidate, resolvingAgainstBaseURL: true)
        components?.scheme = "https"
        components?.host = isWiki || isWikiAssetHost || isFireEmblemWikiAssetHost ? host : "serenesforest.net"
        if !isWiki && !isWikiAssetHost && !isFireEmblemWikiAssetHost && components?.path == "/",
           components?.queryItems?.contains(where: { $0.name == "page_id" && $0.value == "60457" }) == true {
            components?.path = "/three-houses-support-conversations/"
        }
        if isWiki, components?.path == "/index.php" {
            let items = components?.queryItems ?? []
            guard !items.contains(where: { ["action", "redlink", "oldid"].contains($0.name) }),
                  let title = items.first(where: { $0.name == "title" })?.value, !title.isEmpty else { return nil }
            let pathCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/:_()'-")
            guard let encodedTitle = title.replacingOccurrences(of: " ", with: "_")
                .addingPercentEncoding(withAllowedCharacters: pathCharacters) else { return nil }
            components?.percentEncodedPath = "/index.php/" + encodedTitle
        }
        if !isWiki && !isWikiAssetHost && !isFireEmblemWikiAssetHost && candidate.path.lowercased().hasPrefix("/fe8/class/"),
           candidate.pathExtension.lowercased() == "png" {
            let name = candidate.deletingPathExtension().lastPathComponent.lowercased()
            let available = Set(["berserker", "branch", "branch2", "druid", "fighter", "general", "greatknight", "hero2",
                                 "journeyman", "mage", "mageknight", "paladin", "pirate", "pupil",
                                 "sage2", "shaman", "summoner", "warrior"])
            if available.contains(name) {
                let currentName = name == "hero2" ? "hero" : name == "sage2" ? "sage" : name
                components?.path = "/wp-content/uploads/2014/05/fe8\(currentName).png"
            }
        }
        components?.query = nil
        components?.fragment = nil
        if !isWiki && !isWikiAssetHost && !isFireEmblemWikiAssetHost, let path = components?.path,
           !path.hasSuffix("/"), !path.isEmpty, URL(fileURLWithPath: path).pathExtension.isEmpty {
            components?.path = path + "/"
        }
        guard let url = components?.url else { return nil }
        let path = url.path.lowercased()
        if isWikiAssetHost { return isAsset(url) ? url : nil }
        if isFireEmblemWikiAssetHost { return isAsset(url) ? url : nil }
        if isWiki {
            if isAsset(url) { return url }
            guard path.hasPrefix("/index.php/") else { return nil }
            let title = String(path.dropFirst("/index.php/".count))
            let namespace = title.split(separator: ":", maxSplits: 1).first.map(String.init) ?? ""
            return ["user", "category", "special", "talk", "template", "file"].contains(namespace) ? nil : url
        }
        guard !path.hasPrefix("/wiki"), !path.hasPrefix("/forums"), !path.hasPrefix("/wp-admin"),
              !path.hasPrefix("/wp-json"), !path.hasPrefix("/wp-login"), !path.hasPrefix("/cdn-cgi"),
              !path.hasPrefix("/xmlrpc"), !path.hasSuffix("/feed/") else { return nil }
        return url
    }

    public static func isAsset(_ url: URL) -> Bool { assetExtensions.contains(url.pathExtension.lowercased()) }

    public static func isPage(_ url: URL) -> Bool {
        !isAsset(url) && !url.path.lowercased().hasPrefix("/wp-content/") &&
        (url.pathExtension.isEmpty || ["html", "htm"].contains(url.pathExtension.lowercased()))
    }


}
