import SwiftUI

/// Spring-damped accordion disclosure group with rotating 90° indicator chevron
/// and smooth vertical reveal animation.
public struct FMExpandableGroup<Content: View>: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @Binding private var isExpanded: Bool
    private let icon: String?
    private let iconColor: Color
    private let title: String
    private let subtitle: String?
    private let content: Content

    @State private var isHeaderHovered = false
    @FocusState private var isHeaderFocused: Bool

    public init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color = FMColor.blue,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self._isExpanded = isExpanded
        self.content = content()
    }

    public var body: some View {
        let radius = FMCornerRadius.card * density.cornerScale
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        VStack(spacing: 0) {
            Button {
                isExpanded.toggle()
                FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
            } label: {
                HStack(spacing: FMSpacing.sm) {
                    if let icon {
                        FMIconBadge(icon, color: iconColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.fmHeadline)
                            .foregroundStyle(.primary)

                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.fmSubheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, density.horizontalPadding)
                .padding(.vertical, density.verticalPadding)
                .frame(minHeight: density.rowMinHeight)
                .background(isHeaderHovered ? FMColor.controlFill(colorScheme) : .clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focused($isHeaderFocused)
            .focusEffectDisabled()
            .fmFocusRing(isFocused: isHeaderFocused, cornerRadius: FMCornerRadius.card)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .onHover { isHeaderHovered = $0 }

            if isExpanded {
                Rectangle()
                    .fill(FMColor.separator(colorScheme, highContrast: contrast == .increased))
                    .frame(height: 0.5)

                VStack(alignment: .leading, spacing: FMSpacing.sm) {
                    content
                }
                .padding(density.horizontalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
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
        .fmAnimation(.modal, value: isExpanded)
        .fmAnimation(.micro, value: isHeaderHovered)
    }
}
