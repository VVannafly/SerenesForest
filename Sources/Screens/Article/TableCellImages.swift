import SerenesParsing
import Foundation
import SwiftUI

private enum Constants {
    static func extraImageCount(_ count: Int) -> String { "+\(count)" }
}

struct TableCellImages: View {
    let urls: [URL]
    let assets: [String: Date]
    let onLink: (URL) -> Void
    @State private var showsAll = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(urls.prefix(3).enumerated()), id: \.offset) { _, url in
                image(url)
            }
            if urls.count > 3 {
                Button(Constants.extraImageCount(urls.count - 3)) { showsAll = true }
                    .font(.caption2)
                    .popover(isPresented: $showsAll) {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 8)], spacing: 8) {
                                ForEach(Array(urls.enumerated()), id: \.offset) { _, url in image(url) }
                            }
                            .padding(12)
                        }
                        .frame(minWidth: 180, maxWidth: 320, minHeight: 80, maxHeight: 320)
                    }
            }
        }
        .frame(height: 28, alignment: .leading)
    }

    private func image(_ url: URL) -> some View {
        let canonical = SiteScope.canonical(url)?.absoluteString ?? url.absoluteString
        return ArticleImageView(url: url, assetURL: canonical, alt: "", compact: true,
                                fetchedAt: assets[canonical], onLink: onLink)
    }
}
