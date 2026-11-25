import SwiftUI

/// Replaces macOS's harsh native rectangular blue focus box with a continuous-curvature
/// glowing ring aligned to the active theme accent and window active state.
public struct FMFocusRingModifier: ViewModifier {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.colorScheme) private var colorScheme

    let isFocused: Bool
    let cornerRadius: CGFloat
    let isCapsule: Bool
    let color: Color?

    public init(
        isFocused: Bool,
        cornerRadius: CGFloat = FMCornerRadius.control,
        isCapsule: Bool = false,
        color: Color? = nil
    ) {
        self.isFocused = isFocused
        self.cornerRadius = cornerRadius
        self.isCapsule = isCapsule
        self.color = color
    }

    public func body(content: Content) -> some View {
        let ringColor = FMColor.adaptiveAccent(
            color ?? theme.accentColor,
            activeState: activeState,
            scheme: colorScheme
        )
        let scaled = cornerRadius * density.cornerScale + 2

        content
            .focusEffectDisabled()
            .overlay {
                Group {
                    if isCapsule {
                        Capsule(style: .continuous)
                            .strokeBorder(ringColor.opacity(isFocused ? 0.85 : 0), lineWidth: 2)
                            .padding(-3)
                    } else {
                        RoundedRectangle(cornerRadius: scaled, style: .continuous)
                            .strokeBorder(ringColor.opacity(isFocused ? 0.85 : 0), lineWidth: 2)
                            .padding(-3)
                    }
                }
                .shadow(color: ringColor.opacity(isFocused ? 0.32 : 0), radius: 5)
                .scaleEffect(isFocused ? 1.0 : 1.03)
                .allowsHitTesting(false)
                .fmAnimation(.micro, value: isFocused)
            }
    }
}

/// Adds smooth desktop pointer hover feedback with optional micro-elevation lift.
public struct FMHoverLiftModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    let enabled: Bool
    let liftOffset: CGFloat
    let scale: CGFloat

    public init(enabled: Bool = true, liftOffset: CGFloat = -2, scale: CGFloat = 1.01) {
        self.enabled = enabled
        self.liftOffset = liftOffset
        self.scale = scale
    }

    public func body(content: Content) -> some View {
        let active = enabled && isEnabled && isHovered
        content
            .scaleEffect(active ? scale : 1.0)
            .offset(y: active ? liftOffset : 0)
            .brightness(active ? 0.025 : 0)
            .fmAnimation(.micro, value: active)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

public extension View {
    /// Suppresses the default macOS focus box and draws a FluidMacUI continuous accent ring when focused.
    func fmFocusRing(
        isFocused: Bool,
        cornerRadius: CGFloat = FMCornerRadius.control,
        isCapsule: Bool = false,
        color: Color? = nil
    ) -> some View {
        modifier(
            FMFocusRingModifier(
                isFocused: isFocused,
                cornerRadius: cornerRadius,
                isCapsule: isCapsule,
                color: color
            )
        )
    }

    /// Cleanly removes macOS's default blue focus ring without drawing a replacement (for non-input decorative containers).
    func fmFocusClean() -> some View {
        focusEffectDisabled()
    }

    /// Adds a subtle pointer hover lift and highlight.
    func fmHoverLift(enabled: Bool = true, liftOffset: CGFloat = -2, scale: CGFloat = 1.01) -> some View {
        modifier(FMHoverLiftModifier(enabled: enabled, liftOffset: liftOffset, scale: scale))
    }
}
