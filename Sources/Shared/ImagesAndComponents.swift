import SwiftUI

struct CachedBundleImage: View {
    let name: String
    let mode: ContentMode
    let maxPixelSize: Int
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: mode)
            } else {
                Color.clear
            }
        }
        .task(id: name) {
            image = nil
            let loaded = await LocalImageLoader.shared.bundleImage(named: name, maxPixelSize: maxPixelSize)
            if !Task.isCancelled { image = loaded }
        }
    }
}

struct GameSectionArtwork: View {
    let slug: String
    let section: GameSection
    let symbol: String
    let tint: Color

    private var imageName: String {
        let candidate = "sectionart-\(slug)-\(section.rawValue.lowercased())"
        return Bundle.main.url(forResource: candidate, withExtension: "png", subdirectory: "GameCovers") == nil
            ? slug : candidate
    }

    var body: some View {
        CachedBundleImage(name: imageName, mode: .fill, maxPixelSize: 96)
            .frame(width: 40, height: 40)
            .background(tint.opacity(0.13))
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: symbol)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(tint, in: RoundedRectangle(cornerRadius: 6))
                    .offset(x: 3, y: 3)
            }
            .accessibilityHidden(true)
    }
}

struct GameGuideWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct GameActionButtonStyle: ButtonStyle {
    let tint: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(tint.opacity(configuration.isPressed ? 0.19 : 0.10),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(tint.opacity(0.28)) }
            .opacity(isEnabled ? 1 : 0.45)
    }
}
