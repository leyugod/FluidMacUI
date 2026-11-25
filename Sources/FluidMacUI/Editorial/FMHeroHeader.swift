import SwiftUI

/// Native Apple App Store / detail-page hero header combining a large continuous-curvature
/// icon or artwork, strong typographic title/subtitle hierarchy, and a compact primary capsule CTA.
public struct FMHeroHeader<Artwork: View, Actions: View>: View {
    private let title: String
    private let subtitle: String?
    private let artworkSize: CGFloat
    private let artwork: Artwork
    private let actions: Actions

    public init(
        title: String,
        subtitle: String? = nil,
        artworkSize: CGFloat = 96,
        @ViewBuilder artwork: () -> Artwork,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.subtitle = subtitle
        self.artworkSize = artworkSize
        self.artwork = artwork()
        self.actions = actions()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: FMSpacing.lg) {
            artwork
                .frame(width: artworkSize, height: artworkSize)
                .clipShape(RoundedRectangle(cornerRadius: artworkSize * 0.225, style: .continuous))
                .shadow(color: .black.opacity(0.24), radius: 12, y: 5)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .default))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: FMSpacing.sm) {
                    actions
                }
                .padding(.top, 8)
            }

            Spacer(minLength: FMSpacing.md)
        }
    }
}

public extension FMHeroHeader where Artwork == FMIconBadge {
    init(
        icon: String,
        iconColor: Color = FMColor.blue,
        title: String,
        subtitle: String? = nil,
        artworkSize: CGFloat = 96,
        @ViewBuilder actions: () -> Actions
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            artworkSize: artworkSize,
            artwork: { FMIconBadge(icon, color: iconColor, size: artworkSize) },
            actions: actions
        )
    }
}
