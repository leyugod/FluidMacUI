import SwiftUI

/// Compact fluid container tailored for macOS `MenuBarExtra` / `NSStatusItem` popovers,
/// applying `.fmDensity(.compact)` automatically along with header, scrollable body, and footer slots.
public struct FMMenuBarPanel<HeaderAccessory: View, Content: View, Footer: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    private let title: String
    private let subtitle: String?
    private let icon: String?
    private let iconColor: Color
    private let width: CGFloat
    private let maxBodyHeight: CGFloat?
    private let headerAccessory: HeaderAccessory
    private let content: Content
    private let footer: Footer

    public init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color = FMColor.blue,
        width: CGFloat = 320,
        maxBodyHeight: CGFloat? = nil,
        @ViewBuilder headerAccessory: () -> HeaderAccessory,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.width = width
        self.maxBodyHeight = maxBodyHeight
        self.headerAccessory = headerAccessory()
        self.content = content()
        self.footer = footer()
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: FMSpacing.xs + 2) {
                if let icon {
                    FMIconBadge(icon, color: iconColor, size: 28)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.fmHeadline)
                        .foregroundStyle(.primary)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.fmFootnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                headerAccessory
            }
            .padding(.horizontal, FMSpacing.md)
            .padding(.vertical, FMSpacing.sm)

            Rectangle()
                .fill(FMColor.separator(colorScheme, highContrast: contrast == .increased))
                .frame(height: 0.5)

            if let maxBodyHeight {
                ScrollView {
                    VStack(spacing: FMSpacing.sm) {
                        content
                    }
                    .padding(FMSpacing.sm)
                }
                .frame(maxHeight: maxBodyHeight)
            } else {
                VStack(spacing: FMSpacing.sm) {
                    content
                }
                .padding(FMSpacing.sm)
            }

            footer
        }
        .frame(width: width)
        .fmGlassSurface(.regular, cornerRadius: FMCornerRadius.card + 2, showShadow: false)
        .fmDensity(.compact)
    }
}

public extension FMMenuBarPanel where HeaderAccessory == EmptyView, Footer == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color = FMColor.blue,
        width: CGFloat = 320,
        maxBodyHeight: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            icon: icon,
            iconColor: iconColor,
            width: width,
            maxBodyHeight: maxBodyHeight,
            headerAccessory: { EmptyView() },
            content: content,
            footer: { EmptyView() }
        )
    }
}
