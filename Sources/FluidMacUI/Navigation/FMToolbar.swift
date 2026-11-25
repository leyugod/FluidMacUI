import SwiftUI

/// macOS 26 signature floating circular or capsule Liquid Glass toolbar button
/// (matching native App Store `<`, `↑`, sidebar toggle, and inspector controls).
public struct FMToolbarButton: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.isEnabled) private var isEnabled

    private let icon: String
    private let title: String?
    private let isActive: Bool
    private let diameter: CGFloat
    private let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false
    @FocusState private var isFocused: Bool

    public init(
        icon: String,
        title: String? = nil,
        isActive: Bool = false,
        diameter: CGFloat = 30,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.isActive = isActive
        self.diameter = diameter
        self.action = action
    }

    public var body: some View {
        let accent = FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
        let role: FMGlassRole = isActive ? .interactiveTinted(accent) : .interactive

        Button {
            FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13.5, weight: .semibold))
                if let title, !title.isEmpty {
                    Text(title)
                        .font(.fmControl)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(isActive ? accent : Color.primary.opacity(isEnabled ? 0.9 : 0.35))
            .padding(.horizontal, title == nil ? 0 : 11)
            .frame(minWidth: diameter, minHeight: diameter)
            .fmGlassSurface(role, isCapsule: true, showShadow: false)
            .brightness(isHovered && isEnabled ? 0.05 : 0)
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .focusEffectDisabled()
        .fmFocusRing(isFocused: isFocused, isCapsule: true)
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard isEnabled else { return }
                    isPressed = true
                }
                .onEnded { _ in isPressed = false }
        )
        .fmAnimation(.micro, value: isHovered)
        .fmAnimation(.micro, value: isPressed)
        .fmAnimation(.micro, value: isActive)
    }
}

/// Groups adjacent `FMToolbarButton` controls inside macOS 26's native `GlassEffectContainer`
/// so adjacent glass buttons morph and share optical reflections seamlessly.
public struct FMToolbarGroup<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    public init(spacing: CGFloat = 6, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        GlassEffectContainer(spacing: spacing) {
            HStack(spacing: spacing) {
                content
            }
        }
    }
}

/// Floating transparent header bar aligned flush at the top of the macOS window (`46pt` height),
/// matching native AppKit unified toolbar vertical metrics and providing native window dragging on empty space.
public struct FMFloatingHeaderBar<Leading: View, Center: View, Trailing: View>: View {
    private let height: CGFloat
    private let leading: Leading
    private let center: Center
    private let trailing: Trailing

    public init(
        height: CGFloat = 46,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder center: () -> Center,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.height = height
        self.leading = leading()
        self.center = center()
        self.trailing = trailing()
    }

    public var body: some View {
        ZStack {
            FMTitleBarDragArea()

            HStack(spacing: FMSpacing.sm) {
                leading
                Spacer(minLength: FMSpacing.sm)
                trailing
            }
            .padding(.horizontal, 14)

            center
                .allowsHitTesting(false)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }
}
