import SwiftUI

/// Visual style variants for `FMButtonStyle`.
public enum FMButtonVariant: Sendable, Hashable {
    /// High-emphasis accent filled button.
    case primary
    /// Subtle neutral filled button.
    case secondary
    /// Translucent accent-tinted capsule/rounded button.
    case tinted
    /// High-emphasis destructive red action button.
    case destructive
    /// Optical Liquid Glass / frosted button.
    case glass
    /// Borderless hover-revealing ghost button.
    case ghost
}

/// iOS-inspired spring-squish button style with macOS hover brightness,
/// inactive window desaturation, keyboard focus ring, and optional inline spinner.
public struct FMButtonStyle: ButtonStyle {
    public let variant: FMButtonVariant
    public let isLoading: Bool
    public let fullWidth: Bool
    public let isCapsule: Bool
    public let customColor: Color?

    public init(
        variant: FMButtonVariant = .primary,
        isLoading: Bool = false,
        fullWidth: Bool = false,
        isCapsule: Bool = false,
        color: Color? = nil
    ) {
        self.variant = variant
        self.isLoading = isLoading
        self.fullWidth = fullWidth
        self.isCapsule = isCapsule
        self.customColor = color
    }

    public func makeBody(configuration: Configuration) -> some View {
        FMButtonBody(
            configuration: configuration,
            variant: variant,
            isLoading: isLoading,
            fullWidth: fullWidth,
            isCapsule: isCapsule,
            customColor: customColor
        )
    }
}

/// Resolved layout metrics for `FMButtonStyle` combining `FMDensity` and SwiftUI `ControlSize`.
public struct FMButtonMetrics: Sendable, Equatable {
    public let minHeight: CGFloat
    public let horizontalPadding: CGFloat
    public let fontSize: CGFloat

    public static func resolve(density: FMDensity, controlSize: ControlSize) -> FMButtonMetrics {
        let baseHeight = density.controlHeight
        let basePad = density.horizontalPadding
        switch controlSize {
        case .mini:
            return FMButtonMetrics(minHeight: max(22, baseHeight - 12), horizontalPadding: max(8, basePad - 6), fontSize: 11.5)
        case .small:
            return FMButtonMetrics(minHeight: max(26, baseHeight - 8), horizontalPadding: max(10, basePad - 4), fontSize: 12.5)
        case .regular:
            return FMButtonMetrics(minHeight: baseHeight, horizontalPadding: basePad, fontSize: 13.5)
        case .large:
            return FMButtonMetrics(minHeight: baseHeight + 6, horizontalPadding: basePad + 4, fontSize: 14.5)
        case .extraLarge:
            return FMButtonMetrics(minHeight: baseHeight + 12, horizontalPadding: basePad + 8, fontSize: 15.5)
        @unknown default:
            return FMButtonMetrics(minHeight: baseHeight, horizontalPadding: basePad, fontSize: 13.5)
        }
    }
}

private struct FMButtonBody: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.controlSize) private var controlSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.isEnabled) private var isEnabled

    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    let configuration: ButtonStyle.Configuration
    let variant: FMButtonVariant
    let isLoading: Bool
    let fullWidth: Bool
    let isCapsule: Bool
    let customColor: Color?

    private var accent: Color {
        FMColor.adaptiveAccent(
            customColor ?? theme.accentColor,
            activeState: activeState,
            scheme: colorScheme
        )
    }

    private var destructiveColor: Color {
        FMColor.adaptiveAccent(
            FMColor.red,
            activeState: activeState,
            scheme: colorScheme
        )
    }

    private var cornerRadius: CGFloat {
        FMCornerRadius.control * density.cornerScale
    }

    var body: some View {
        let pressed = configuration.isPressed && isEnabled && !isLoading
        let metrics = FMButtonMetrics.resolve(density: density, controlSize: controlSize)

        HStack(spacing: FMSpacing.xs) {
            if isLoading {
                FMSpinner(style: .ring, size: .small, tint: foregroundColor)
            }
            configuration.label
                .opacity(isLoading ? 0.72 : 1.0)
        }
        .font(.system(size: metrics.fontSize, weight: .medium, design: .rounded))
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, metrics.horizontalPadding)
        .frame(minHeight: metrics.minHeight)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .background { backgroundSurface(pressed: pressed) }
        .contentShape(
            isCapsule
                ? AnyShape(Capsule(style: .continuous))
                : AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        )
        .scaleEffect(pressed ? 0.96 : 1.0)
        .brightness(isHovered && !pressed && isEnabled ? 0.045 : 0)
        .opacity(isEnabled ? 1.0 : 0.45)
        .focused($isFocused)
        .focusEffectDisabled()
        .fmFocusRing(
            isFocused: isFocused,
            cornerRadius: FMCornerRadius.control,
            isCapsule: isCapsule,
            color: variant == .destructive ? FMColor.red : customColor
        )
        .fmAnimation(.micro, value: pressed)
        .fmAnimation(.micro, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onChange(of: configuration.isPressed) { _, newPressed in
            if newPressed && isEnabled && !isLoading {
                FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
            }
        }
        .disabled(isLoading)
        .allowsHitTesting(!isLoading)
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary, .destructive:
            return .white
        case .tinted:
            return accent
        case .secondary, .glass, .ghost:
            return .primary
        }
    }

    @ViewBuilder
    private func backgroundSurface(pressed: Bool) -> some View {
        switch variant {
        case .primary:
            fillShape(accent.opacity(pressed ? 0.86 : 1.0))
        case .destructive:
            fillShape(destructiveColor.opacity(pressed ? 0.86 : 1.0))
        case .tinted:
            fillShape(accent.opacity(isHovered ? 0.22 : 0.14))
        case .secondary:
            fillShape(isHovered ? FMColor.controlHoverFill(colorScheme) : FMColor.controlFill(colorScheme))
        case .ghost:
            fillShape(isHovered ? FMColor.controlFill(colorScheme) : .clear)
        case .glass:
            Color.clear
                .fmGlassSurface(
                    .interactive,
                    cornerRadius: FMCornerRadius.control,
                    isCapsule: isCapsule,
                    showShadow: false
                )
        }
    }

    @ViewBuilder
    private func fillShape(_ color: Color) -> some View {
        if isCapsule {
            Capsule(style: .continuous).fill(color)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(color)
        }
    }
}

public extension ButtonStyle where Self == FMButtonStyle {
    static var fmPrimary: FMButtonStyle { FMButtonStyle(variant: .primary) }
    static var fmSecondary: FMButtonStyle { FMButtonStyle(variant: .secondary) }
    static var fmTinted: FMButtonStyle { FMButtonStyle(variant: .tinted) }
    static var fmDestructive: FMButtonStyle { FMButtonStyle(variant: .destructive) }
    static var fmGlass: FMButtonStyle { FMButtonStyle(variant: .glass) }
    static var fmGhost: FMButtonStyle { FMButtonStyle(variant: .ghost) }

    static func fm(
        _ variant: FMButtonVariant,
        isLoading: Bool = false,
        fullWidth: Bool = false,
        isCapsule: Bool = false,
        color: Color? = nil
    ) -> FMButtonStyle {
        FMButtonStyle(
            variant: variant,
            isLoading: isLoading,
            fullWidth: fullWidth,
            isCapsule: isCapsule,
            color: color
        )
    }
}
