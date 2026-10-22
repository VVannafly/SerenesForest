import SwiftUI

struct GameCard: View {
    let game: Game
    let overview: GameOverview?
    var releaseYear: Int? = nil

    private var progress: GameProgress { GameProgress(status: game.status) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { geometry in
                Rectangle().fill(Palette.accent.opacity(0.12))
                    .overlay { Image(systemName: "shield.checkered").font(.largeTitle).foregroundStyle(Palette.accent) }
                    .overlay {
                        CachedBundleImage(name: game.slug, mode: .fill, maxPixelSize: 480)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
            }
            .frame(height: 112)
            .clipped()
            .overlay(alignment: .topLeading) {
                Text(game.platform.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.4)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .padding(10)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text(game.title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
                if let overview {
                    Text(overview.story)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 2)
                HStack(spacing: 4) {
                    Label(LocalizedStringKey(progress.rawValue), systemImage: progress.symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(progress.tint)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let releaseYear {
                        Text(String(releaseYear))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .overlay(alignment: .topLeading) {
            if game.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.pink)
                    .padding(8)
                    .background(.regularMaterial, in: Circle())
                    .padding(8)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.07)) }
    }
}
