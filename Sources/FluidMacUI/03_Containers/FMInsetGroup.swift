import SwiftUI

/// iOS `UITableView(.insetGrouped)`-inspired rounded section card container
/// with optional uppercase header and descriptive footer caption.
public struct FMInsetGroup<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.fmDensity) private var density
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let title: String?
    private let footer: String?
    private let content: Content

    public init(
        title: String? = nil,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    public var body: some View {
        let radius = FMCornerRadius.card * density.cornerScale
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        VStack(alignment: .leading, spacing: FMSpacing.xs) {
            if let title, !title.isEmpty {
                Text(title.uppercased())
                    .font(.fmCaption)
                    .foregroundStyle(.secondary)
                    .tracking(0.6)
                    .padding(.leading, FMSpacing.sm)
            }

            VStack(spacing: 0) {
                content
            }
            .background(
                reduceTransparency
                    ? FMColor.elevatedOpaqueSurface(colorScheme)
                    : FMColor.elevatedSurface(colorScheme),
                in: shape
            )
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(
                    FMColor.hairlineHighlight(colorScheme, highContrast: contrast == .increased),
                    lineWidth: contrast == .increased ? 1.0 : 0.5
                )
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.16 : 0.04),
                radius: 10,
                y: 4
            )

            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(.fmFootnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, FMSpacing.sm)
                    .padding(.top, 1)
            }
        }
    }
}
