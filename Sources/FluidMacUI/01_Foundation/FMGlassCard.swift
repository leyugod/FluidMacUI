import SwiftUI

/// Visual presentation mode for `FMGlassCard`.
public enum FMCardSurface: Sendable, Hashable {
    /// Adapts to `FMTheme.surfaceStyle` (Liquid Glass or Frosted).
    case glass(FMGlassRole = .regular)
    /// Lightweight elevated surface recommended for dense scroll lists.
    case elevated
}

/// Foundational rounded card primitive with continuous/concentric corners,
/// adaptive hairline highlight, and optional hover elevation lift.
public struct FMGlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.fmDensity) private var density
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let surface: FMCardSurface
    private let cornerRadius: CGFloat
    private let padding: CGFloat?
    private let hoverLift: Bool
    private let content: Content

    public init(
        surface: FMCardSurface = .glass(.regular),
        cornerRadius: CGFloat = FMCornerRadius.card,
        padding: CGFloat? = nil,
        hoverLift: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.surface = surface
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.hoverLift = hoverLift
        self.content = content()
    }

    public var body: some View {
        let inset = padding ?? density.horizontalPadding
        let scaledRadius = cornerRadius * density.cornerScale

        Group {
            switch surface {
            case .glass(let role):
                content
                    .padding(inset)
                    .fmGlassSurface(role, cornerRadius: cornerRadius)

            case .elevated:
                let shape = RoundedRectangle(cornerRadius: scaledRadius, style: .continuous)
                content
                    .padding(inset)
                    .background(
                        reduceTransparency
                            ? FMColor.elevatedOpaqueSurface(colorScheme)
                            : FMColor.elevatedSurface(colorScheme),
                        in: shape
                    )
                    .overlay {
                        shape.strokeBorder(
                            FMColor.hairlineHighlight(colorScheme, highContrast: contrast == .increased),
                            lineWidth: contrast == .increased ? 1.0 : 0.5
                        )
                    }
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.16 : 0.045),
                        radius: 10,
                        y: 4
                    )
            }
        }
        .fmHoverLift(enabled: hoverLift)
    }
}
