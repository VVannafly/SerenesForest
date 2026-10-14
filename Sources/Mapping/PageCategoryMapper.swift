import Foundation

enum PageCategoryMapper {
    static func category(for url: URL) -> (String, String?) {
        let path = url.path
        if url.host == "wiki.serenesforest.net" {
            let roots = [
                ("Fire_Emblem_Warriors", "fire-emblem-warriors"),
                ("Fire_Emblem_Warriors:_Three_Hopes", "warriors-three-hopes"),
                ("Tokyo_Mirage_Sessions_♯FE", "tokyo-mirage-sessions"),
            ]
            if let game = roots.first(where: { path == "/index.php/\($0.0)" }) {
                return ("Game", game.1)
            }
            return ("Guide", nil)
        }
        if path.range(of: "^/20[0-9]{2}/", options: .regularExpression) != nil { return ("News", nil) }
        if let game = Catalog.games.first(where: { path.hasPrefix("/\($0.3)/") && !$0.3.hasPrefix("wiki/") }) {
            return (path == "/\(game.3)/" ? "Game" : "Guide", game.0)
        }
        if ["/gallery/", "/music/", "/videos/", "/scribbles/"].contains(where: path.hasPrefix) { return ("Media", nil) }
        return ("General", nil)
    }
}
