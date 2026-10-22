import SwiftUI

extension EnvironmentValues {
    @Entry var imageLoadingPaused = false
}

private struct PauseImageLoadingDuringScroll: ViewModifier {
    @State private var isScrolling = false

    func body(content: Content) -> some View {
        content
            .onScrollPhaseChange { _, phase in
                isScrolling = phase.isScrolling
            }
            .environment(\.imageLoadingPaused, isScrolling)
    }
}

extension View {
    func pauseImageLoadingDuringScroll() -> some View {
        modifier(PauseImageLoadingDuringScroll())
    }
}

struct CachedBundleImage: View {
    let name: String
    let mode: ContentMode
    let maxPixelSize: Int
    @Environment(\.imageLoadingPaused) private var imageLoadingPaused
    @State private var image: CGImage?
    @State private var loadedKey: String?

    private var imageKey: String { "\(name)|\(maxPixelSize)" }

    var body: some View {
        Group {
            if let image, loadedKey == imageKey {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: mode)
            } else {
                Color.clear
            }
        }
        .task(id: "\(imageKey)|\(imageLoadingPaused)") {
            guard !imageLoadingPaused, loadedKey != imageKey else { return }
            let loaded = await ImageLoadingService.shared.bundleImage(named: name, maxPixelSize: maxPixelSize)
            if !Task.isCancelled, let loaded {
                image = loaded
                loadedKey = imageKey
            }
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
