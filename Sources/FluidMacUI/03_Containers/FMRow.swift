import SwiftUI

/// Standardized iOS-style list row designed for `FMInsetGroup` with optional `FMIconBadge`,
/// title + subtitle stack, trailing accessory view, indented hairline divider, and hover/press interaction.
public struct FMRow<Accessory: View>: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    private let icon: String?
    private let iconColor: Color
    private let title: String
    private let subtitle: String?
    private let showDivider: Bool
    private let showChevron: Bool
    private let action: (() -> Void)?
    private let accessory: Accessory

    @State private var isHovered = false
    @State private var isPressed = false

    public init(
        icon: String? = nil,
        iconColor: Color = FMColor.blue,
        title: String,
        subtitle: String? = nil,
        showDivider: Bool = true,
        showChevron: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.showDivider = showDivider
        self.showChevron = showChevron
        self.action = action
        self.accessory = accessory()
    }

    public var body: some View {
        let isInteractive = action != nil
        let dividerLeading: CGFloat = icon != nil
            ? density.horizontalPadding + density.iconBadgeSize + FMSpacing.sm
            : density.horizontalPadding

        VStack(spacing: 0) {
            HStack(spacing: FMSpacing.sm) {
                if let icon {
                    FMIconBadge(icon, color: iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.fmHeadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.fmSubheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: FMSpacing.sm)

                accessory

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .offset(x: isHovered && isInteractive ? 2 : 0)
                }
            }
            .padding(.horizontal, density.horizontalPadding)
            .padding(.vertical, density.verticalPadding)
            .frame(minHeight: density.rowMinHeight)
            .background(rowBackground(isInteractive: isInteractive))
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .modifier(FMRowTapModifier(action: action, isPressed: $isPressed, hapticsEnabled: theme.hapticsEnabled))
            .fmAnimation(.micro, value: isHovered)
            .fmAnimation(.micro, value: isPressed)

            if showDivider {
                Rectangle()
                    .fill(FMColor.separator(colorScheme, highContrast: contrast == .increased))
                    .frame(height: contrast == .increased ? 1.0 : 0.5)
                    .padding(.leading, dividerLeading)
            }
        }
    }

    private func rowBackground(isInteractive: Bool) -> Color {
        if isInteractive && isPressed {
            return FMColor.controlHoverFill(colorScheme)
        }
        if isHovered {
            return isInteractive
                ? FMColor.controlFill(colorScheme)
                : FMColor.controlFill(colorScheme).opacity(0.45)
        }
        return .clear
    }
}

private struct FMRowTapModifier: ViewModifier {
    let action: (() -> Void)?
    @Binding var isPressed: Bool
    let hapticsEnabled: Bool
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        if let action {
            content
                .focusable()
                .focused($isFocused)
                .focusEffectDisabled()
                .fmFocusRing(isFocused: isFocused, cornerRadius: FMCornerRadius.micro)
                .onKeyPress(.return) {
                    FMHaptics.perform(.alignment, enabled: hapticsEnabled)
                    action()
                    return .handled
                }
                .onKeyPress(.space) {
                    FMHaptics.perform(.alignment, enabled: hapticsEnabled)
                    action()
                    return .handled
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in isPressed = true }
                        .onEnded { value in
                            isPressed = false
                            if abs(value.translation.width) < 12 && abs(value.translation.height) < 12 {
                                FMHaptics.perform(.alignment, enabled: hapticsEnabled)
                                action()
                            }
                        }
                )
                .accessibilityAddTraits(.isButton)
        } else {
            content
        }
    }
}

public extension FMRow where Accessory == EmptyView {
    init(
        icon: String? = nil,
        iconColor: Color = FMColor.blue,
        title: String,
        subtitle: String? = nil,
        showDivider: Bool = true,
        showChevron: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.init(
            icon: icon,
            iconColor: iconColor,
            title: title,
            subtitle: subtitle,
            showDivider: showDivider,
            showChevron: showChevron,
            action: action
        ) {
            EmptyView()
        }
    }
}
