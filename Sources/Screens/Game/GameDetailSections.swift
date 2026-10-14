import SwiftUI

private enum Constants {
    static func sectionTopics(_ title: String, count: Int) -> String { AppText.localized( "\(title), \(count) topics") }
    static let topicsCount = (english: "topics", russian: ("тема", "темы", "тем"))
}

extension GameDetailView {
    func sectionCard(_ section: GameNavigationSection) -> some View {
        let style = GameSection.style(for: section.title)
        let expanded = expandedSectionID == section.id
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedSectionID = expanded ? -1 : section.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                GameSectionArtwork(slug: game.slug, section: style,
                                   symbol: sectionSymbol(style), tint: theme.color(for: style))
                Text(LocalizedStringKey(viewModel.navigationTranslations[section.title] ?? section.title))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                HStack {
                    Text(AppText.count(section.items.count, english: Constants.topicsCount.english, russian: Constants.topicsCount.russian))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .foregroundStyle(theme.color(for: style))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(theme.color(for: style).opacity(expanded ? 0.55 : 0.18), lineWidth: expanded ? 2 : 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Constants.sectionTopics(section.title, count: section.items.count))
        .accessibilityAddTraits(expanded ? [.isSelected] : [])
    }

    func sectionSymbol(_ section: GameSection) -> String {
        switch section {
        case .general: theme.motif
        case .scripts: "text.book.closed.fill"
        case .characters: "person.2.fill"
        case .classes: "shield.lefthalf.filled"
        case .inventory: "bag.fill"
        case .miscellaneous: "sparkles.rectangle.stack.fill"
        }
    }

}
