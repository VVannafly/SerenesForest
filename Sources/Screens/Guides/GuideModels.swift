import SwiftUI

struct GuideTopic: Identifiable {
    let title: String
    let pages: [ContentPage]
    var id: String { title }
}

struct GuideGame: Identifiable {
    let slug: String
    let title: String
    let topics: [GuideTopic]
    var id: String { slug }
    var count: Int { topics.reduce(0) { $0 + $1.pages.count } }
}
