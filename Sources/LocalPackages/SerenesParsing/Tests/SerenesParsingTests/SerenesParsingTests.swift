import Foundation
import XCTest
@testable import SerenesParsing

final class SerenesParsingTests: XCTestCase {
    func testPageParserKeepsCanonicalLinksAndImages() throws {
        let source = try XCTUnwrap(URL(string: "https://serenesforest.net/game/"))
        let html = "<html><body><main><h1>Guide</h1><p>Intro <a href=\"/game/chapter/?ref=nav\">Chapter</a></p><img src=\"/wp-content/uploads/map.png\"></main></body></html>"

        let page = SiteHTML.parse(html, source: source)

        XCTAssertEqual(page.title, "Guide")
        XCTAssertEqual(page.links.map(\.url.absoluteString), ["https://serenesforest.net/game/chapter/"])
        XCTAssertEqual(page.images.map(\.absoluteString), ["https://serenesforest.net/wp-content/uploads/map.png"])
    }

    func testSitemapReadsModificationDate() throws {
        let xml = "<urlset><url><loc>https://serenesforest.net/game/</loc><lastmod>2026-10-01T12:00:00Z</lastmod></url></urlset>"

        let manifest = try SitemapManifest.parse(Data(xml.utf8))

        XCTAssertEqual(manifest.kind, .pages)
        XCTAssertEqual(manifest.entries.first?.url.absoluteString, "https://serenesforest.net/game/")
        XCTAssertNotNil(manifest.entries.first?.modifiedAt)
    }

    func testRSSReaderKeepsNewsItemFields() throws {
        let xml = "<rss><channel><item><title>Update</title><link>https://serenesforest.net/2026/10/update/</link><description>Summary</description></item></channel></rss>"

        let items = try GameNewsReader.parse(Data(xml.utf8))

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.title, "Update")
        XCTAssertEqual(items.first?.summary, "Summary")
    }
}
