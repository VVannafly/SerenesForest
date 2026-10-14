import Foundation
import SwiftUI

struct TableCellText: View, Equatable {
    let runs: [ArticleRun]
    let bold: Bool
    @State private var showsFullText = false

    static func == (lhs: TableCellText, rhs: TableCellText) -> Bool {
        lhs.runs == rhs.runs && lhs.bold == rhs.bold
    }

    var body: some View {
        Text(attributed(runs))
            .font(bold ? .caption.bold() : .caption)
            .fixedSize(horizontal: false, vertical: true)
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                if !runs.isEmpty { showsFullText = true }
            })
            .popover(isPresented: $showsFullText) {
                Text(attributed(runs))
                    .font(.caption)
                    .padding(12)
                    .frame(minWidth: 120, maxWidth: 300, alignment: .leading)
                    .presentationCompactAdaptation(.popover)
            }
            .accessibilityLabel(runs.map(\.text).joined())
    }

    private func attributed(_ runs: [ArticleRun]) -> AttributedString {
        var result = AttributedString()
        for run in runs {
            var part = AttributedString(run.text)
            if let url = run.url { part.link = url; part.foregroundColor = .accentColor }
            if run.strong { part.font = .body.bold() }
            if run.italic { part.font = .body.italic() }
            result += part
        }
        return result
    }
}
