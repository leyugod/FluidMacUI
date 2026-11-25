import SwiftUI

/// Compact telemetry / action item designed to sit inside `FMStatusBar`.
public struct FMStatusBarItem: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.isEnabled) private var isEnabled

    private let icon: String?
    private let text: String
    private let statusColor: Color?
    private let customAccessibilityLabel: String?
    private let action: (() -> Void)?

    @State private var isHovered = false
    @State private var isPressed = false
    @FocusState private var isFocused: Bool

    /// Creates a status bar telemetry or interactive action item.
    /// - Parameters:
    ///   - icon: Optional SF Symbol name displayed before `text`.
    ///   - text: Status text rendered with tabular numerals to prevent jitter.
    ///   - statusColor: Optional leading status indicator dot color.
    ///   - accessibilityLabel: Optional custom VoiceOver label (defaults to `text`).
    ///   - action: Optional tap/keyboard handler that makes the item interactive.
    public init(
        icon: String? = nil,
        text: String,
        statusColor: Color? = nil,
        accessibilityLabel: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.text = text
        self.statusColor = statusColor
        self.customAccessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        if let action {
            interactiveBody(action: action)
        } else {
            itemContent(isInteractiveHovered: false)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(customAccessibilityLabel ?? text)
        }
    }

    private func interactiveBody(action: @escaping () -> Void) -> some View {
        itemContent(isInteractiveHovered: isHovered && isEnabled)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        isHovered && isEnabled
                            ? (isPressed ? FMColor.controlHoverFill(colorScheme) : FMColor.controlFill(colorScheme))
                            : .clear
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .scaleEffect(isPressed && isEnabled ? 0.97 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.45)
            .focusable(isEnabled)
            .focused($isFocused)
            .focusEffectDisabled()
            .fmFocusRing(isFocused: isFocused, cornerRadius: 5)
            .fmAnimation(.micro, value: isHovered)
            .fmAnimation(.micro, value: isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isEnabled else { return }
                        if !isPressed {
                            isPressed = true
                        }
                    }
                    .onEnded { value in
                        let wasPressed = isPressed
                        isPressed = false
                        guard isEnabled, wasPressed,
                              abs(value.translation.width) < 28,
                              abs(value.translation.height) < 20
                        else { return }
                        trigger(action)
                    }
            )
            .onKeyPress(.return) {
                guard isEnabled else { return .ignored }
                trigger(action)
                return .handled
            }
            .onKeyPress(.space) {
                guard isEnabled else { return .ignored }
                trigger(action)
                return .handled
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(customAccessibilityLabel ?? text)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                guard isEnabled else { return }
                trigger(action)
            }
    }

    private func trigger(_ action: () -> Void) {
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
        action()
    }

    private func itemContent(isInteractiveHovered: Bool) -> some View {
        HStack(spacing: 5) {
            if let statusColor {
                let resolvedDot = FMColor.adaptiveAccent(
                    statusColor,
                    activeState: activeState,
                    scheme: colorScheme
                )
                Circle()
                    .fill(resolvedDot)
                    .frame(width: 6.5, height: 6.5)
                    .shadow(
                        color: reduceTransparency || activeState == .inactive
                            ? .clear
                            : resolvedDot.opacity(0.45),
                        radius: 2.5
                    )
                    .accessibilityHidden(true)
            }

            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isInteractiveHovered ? .primary : .secondary)
                    .accessibilityHidden(true)
            }

            Text(text)
                .font(.system(size: 11.5, weight: .medium).monospacedDigit())
                .foregroundStyle(isInteractiveHovered ? .primary : .secondary)
                .lineLimit(1)
        }
    }
}

/// Subtle vertical separator sized for items inside `FMStatusBar`.
public struct FMStatusBarDivider: View {
    public init() {}

    public var body: some View {
        FMHairlineDivider(.vertical)
            .frame(height: 12)
            .accessibilityHidden(true)
    }
}

/// Native macOS bottom status and telemetry bar (matching Finder, Xcode, Pages, and Mail)
/// with leading, center, and trailing slots, top hairline divider, compact density, and Reduce Transparency support.
public struct FMStatusBar<Leading: View, Center: View, Trailing: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let height: CGFloat
    private let leading: Leading
    private let center: Center
    private let trailing: Trailing

    /// Creates a bottom status bar with leading, center, and trailing regions.
    public init(
        height: CGFloat = 28,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder center: () -> Center,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.height = max(20, height)
        self.leading = leading()
        self.center = center()
        self.trailing = trailing()
    }

    public var body: some View {
        VStack(spacing: 0) {
            FMHairlineDivider(.horizontal)

            HStack(spacing: FMSpacing.sm) {
                HStack(spacing: FMSpacing.xs) {
                    leading
                }
                .layoutPriority(1)

                Spacer(minLength: FMSpacing.xs)

                HStack(spacing: FMSpacing.xs) {
                    center
                }

                Spacer(minLength: FMSpacing.xs)

                HStack(spacing: FMSpacing.xs) {
                    trailing
                }
                .layoutPriority(1)
            }
            .padding(.horizontal, FMSpacing.sm)
            .frame(height: height)
        }
        .background {
            if reduceTransparency {
                FMColor.sidebarBackground(colorScheme)
            } else {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    FMColor.sidebarBackground(colorScheme)
                        .opacity(colorScheme == .dark ? 0.62 : 0.72)
                }
            }
        }
        .fmDensity(.compact)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Status bar")
    }
}

public extension FMStatusBar where Center == EmptyView {
    /// Creates a bottom status bar with leading and trailing regions.
    init(
        height: CGFloat = 28,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            height: height,
            leading: leading,
            center: { EmptyView() },
            trailing: trailing
        )
    }
}

public extension FMStatusBar where Leading == EmptyView, Trailing == EmptyView {
    /// Creates a bottom status bar with a single centered region.
    init(
        height: CGFloat = 28,
        @ViewBuilder center: () -> Center
    ) {
        self.init(
            height: height,
            leading: { EmptyView() },
            center: center,
            trailing: { EmptyView() }
        )
    }
}

public extension FMStatusBar where Center == EmptyView, Trailing == EmptyView {
    /// Creates a bottom status bar with a single leading region.
    init(
        height: CGFloat = 28,
        @ViewBuilder leading: () -> Leading
    ) {
        self.init(
            height: height,
            leading: leading,
            center: { EmptyView() },
            trailing: { EmptyView() }
        )
    }
}
