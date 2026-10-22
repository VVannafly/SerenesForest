import SwiftUI

private enum Constants {
    static let metadataSeparator = "·"
}

struct PageRow: View {
    let title: String
    let displayTitle: String
    let category: String
    let chapterLabel: String?
    let publishedAt: Date?
    private let viewModel: PageRowViewModel

    init(page: ContentPage, chapterLabel: String? = nil) {
        self.init(title: page.title, displayTitle: AppText.title(page),
                  category: page.category, gameSlug: page.gameSlug, chapterLabel: chapterLabel,
                  publishedAt: ContentPageMapper.publishedAt(page))
    }

    init(title: String, displayTitle: String, category: String, gameSlug: String?,
         chapterLabel: String? = nil, publishedAt: Date? = nil) {
        self.title = title
        self.displayTitle = displayTitle
        self.category = category
        self.chapterLabel = chapterLabel
        self.publishedAt = publishedAt
        viewModel = PageRowViewModel(title: title, category: category, gameSlug: gameSlug)
    }

    var body: some View {
        HStack(spacing: 14) {
            if viewModel.isNews {
                Image(systemName: "newspaper.fill")
                    .font(.title3)
                    .foregroundStyle(Palette.accent)
                    .frame(width: 42, height: 42)
                .background(Palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            } else {
                ContentIcon(title: title, section: viewModel.section, tint: viewModel.tint)
            }
            VStack(alignment: .leading, spacing: 5) {
                if let chapterLabel, !chapterLabel.isEmpty {
                    Text(AppText.chapterLabel(chapterLabel))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(viewModel.tint ?? Palette.accent)
                        .lineLimit(1)
                }
                Text(displayTitle).font(.headline).foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(LocalizedStringKey(category))
                    if let publishedAt {
                        Text(Constants.metadataSeparator)
                        Text(publishedAt, format: .dateTime.day().month(.abbreviated).year())
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
