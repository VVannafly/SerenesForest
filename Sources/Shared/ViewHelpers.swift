import SwiftUI

func sectionHeading(_ title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
        Text(LocalizedStringKey(title)).font(.title2.bold())
        Text(LocalizedStringKey(subtitle)).font(.subheadline).foregroundStyle(.secondary)
    }
}

func sectionSubtitle(_ subtitle: String) -> some View {
    Text(LocalizedStringKey(subtitle))
        .font(.subheadline)
        .foregroundStyle(.secondary)
}

