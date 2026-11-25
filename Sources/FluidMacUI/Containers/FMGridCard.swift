import SwiftUI

/// iOS Shortcuts / Health-inspired Bento dashboard tile with icon header,
/// optional top-right quick action, hover elevation lift, and spring press feedback.
public struct FMGridCard<Accessory: View, Content: View>: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density

    private let icon: String?
    private let iconColor: Color
    private let title: String
    private let subtitle: String?
    private let surface: FMCardSurface
    private let action: (() -> Void)?
    private let accessory: Accessory
    private let content: Content

    @State private var isPressed = false

    public init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color = FMColor.blue,
        surface: FMCardSurface = .elevated,
        action: (() -> Void)? = nil,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.surface = surface
        self.action = action
        self.accessory = accessory()
        self.content = content()
    }

    public var body: some View {
        FMGlassCard(
            surface: surface,
            cornerRadius: FMCornerRadius.card,
            padding: density.horizontalPadding,
            hoverLift: action != nil
        ) {
            VStack(alignment: .leading, spacing: FMSpacing.sm) {
                HStack(alignment: .top, spacing: FMSpacing.xs) {
                    if let icon {
                        FMIconBadge(icon, color: iconColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.fmTitle2)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.fmFootnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: FMSpacing.xs)

                    accessory
                }

                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .fmAnimation(.micro, value: isPressed)
        .modifier(FMGridCardTapModifier(action: action, isPressed: $isPressed, hapticsEnabled: theme.hapticsEnabled))
    }
}

private struct FMGridCardTapModifier: ViewModifier {
    let action: (() -> Void)?
    @Binding var isPressed: Bool
    let hapticsEnabled: Bool
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        if let action {
            content
                .contentShape(Rectangle())
                .focusable()
                .focused($isFocused)
                .focusEffectDisabled()
                .fmFocusRing(isFocused: isFocused, cornerRadius: FMCornerRadius.card)
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

public extension FMGridCard where Accessory == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color = FMColor.blue,
        surface: FMCardSurface = .elevated,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            icon: icon,
            iconColor: iconColor,
            surface: surface,
            action: action,
            accessory: { EmptyView() },
            content: content
        )
    }
}
