import SwiftUI

struct PageRow: View {
    let page: ContentPage
    let chapterLabel: String?
    private let viewModel: PageRowViewModel

    init(page: ContentPage, chapterLabel: String? = nil) {
        self.page = page
        self.chapterLabel = chapterLabel
        viewModel = PageRowViewModel(page: page)
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
                ContentIcon(title: page.title, section: viewModel.section, tint: viewModel.tint)
            }
            VStack(alignment: .leading, spacing: 5) {
                if let chapterLabel, !chapterLabel.isEmpty {
                    Text(AppText.chapterLabel(chapterLabel))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(viewModel.tint ?? Palette.accent)
                        .lineLimit(1)
                }
                Text(AppText.title(page)).font(.headline).foregroundStyle(.primary)
                Text(LocalizedStringKey(page.category))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
