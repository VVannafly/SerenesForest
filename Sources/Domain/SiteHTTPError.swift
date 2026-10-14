import Foundation

struct SiteHTTPError: LocalizedError {
    let status: Int
    var errorDescription: String? { "Serenes Forest returned HTTP \(status)." }
}
