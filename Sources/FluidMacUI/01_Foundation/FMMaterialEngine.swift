import SwiftUI

/// Semantic corner radii before density scaling.
public enum FMCornerRadius {
    /// Micro badges & icon squircles (`8pt`).
    public static let micro: CGFloat = 8
    /// Standard controls, inputs, buttons (`12pt`).
    public static let control: CGFloat = 12
    /// Grouped cards, Bento tiles (`16pt`).
    public static let card: CGFloat = 16
    /// Floating sidebars, bottom sheets, alerts (`24pt`).
    public static let sheet: CGFloat = 24
}

/// Visual role for `FMMaterialEngine`.
public enum FMGlassRole: Sendable, Hashable {
    case regular
    case clear
    case tinted(Color)
    case interactive
    case interactiveTinted(Color)
}

/// Unified glass & frosted surface modifier supporting macOS 26 Liquid Glass,
/// classic frosted vibrancy, concentric corner curvature, and Reduce Transparency fallback.
public struct FMGlassSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density

    let role: FMGlassRole
    let cornerRadius: CGFloat
    let isCapsule: Bool
    let showShadow: Bool

    public init(
        role: FMGlassRole = .regular,
        cornerRadius: CGFloat = FMCornerRadius.card,
        isCapsule: Bool = false,
        showShadow: Bool = true
    ) {
        self.role = role
        self.cornerRadius = cornerRadius
        self.isCapsule = isCapsule
        self.showShadow = showShadow
    }

    private var scaledRadius: CGFloat {
        cornerRadius * density.cornerScale
    }

    private var isHighContrast: Bool {
        contrast == .increased
    }

    public func body(content: Content) -> some View {
        if reduceTransparency {
            opaqueFallback(content: content)
        } else {
            switch theme.surfaceStyle {
            case .liquidGlass:
                liquidGlassSurface(content: content)
            case .frosted:
                frostedSurface(content: content)
            }
        }
    }

    @ViewBuilder
    private func liquidGlassSurface(content: Content) -> some View {
        let glass = resolveNativeGlass()
        let shadowColor = showShadow ? Color.black.opacity(colorScheme == .dark ? 0.22 : 0.07) : .clear

        if isCapsule {
            content
                .glassEffect(glass, in: .capsule)
                .shadow(color: shadowColor, radius: 14, y: 6)
        } else if theme.cornerStyle == .concentric {
            content
                .glassEffect(
                    glass,
                    in: ConcentricRectangle(corners: .concentric(minimum: .fixed(scaledRadius)))
                )
                .shadow(color: shadowColor, radius: 14, y: 6)
        } else {
            content
                .glassEffect(
                    glass,
                    in: RoundedRectangle(cornerRadius: scaledRadius, style: .continuous)
                )
                .shadow(color: shadowColor, radius: 14, y: 6)
        }
    }

    private func resolveNativeGlass() -> Glass {
        switch role {
        case .regular:
            return .regular
        case .clear:
            return .clear
        case .tinted(let color):
            return .regular.tint(color.opacity(0.28))
        case .interactive:
            return .regular.interactive()
        case .interactiveTinted(let color):
            return .regular.tint(color.opacity(0.32)).interactive()
        }
    }

    @ViewBuilder
    private func frostedSurface(content: Content) -> some View {
        let material: AnyShapeStyle = role == .clear ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.regularMaterial)
        let border = FMColor.hairlineHighlight(colorScheme, highContrast: isHighContrast)
        let borderWidth: CGFloat = isHighContrast ? 1.0 : 0.5
        let shadowColor = showShadow ? Color.black.opacity(colorScheme == .dark ? 0.24 : 0.06) : .clear

        applyInsettableShape(
            content: content,
            fill: material,
            tint: tintColor,
            stroke: border,
            strokeWidth: borderWidth,
            shadowColor: shadowColor
        )
    }

    private var tintColor: Color? {
        switch role {
        case .tinted(let color): color.opacity(0.14)
        case .interactiveTinted(let color): color.opacity(0.18)
        default: nil
        }
    }

    @ViewBuilder
    private func opaqueFallback(content: Content) -> some View {
        let strokeColor: Color = {
            switch role {
            case .tinted(let c), .interactiveTinted(let c):
                return c.opacity(0.65)
            default:
                return FMColor.separator(colorScheme, highContrast: true)
            }
        }()
        applyInsettableShape(
            content: content,
            fill: AnyShapeStyle(FMColor.elevatedOpaqueSurface(colorScheme)),
            tint: tintColor,
            stroke: strokeColor,
            strokeWidth: 1.0,
            shadowColor: .clear
        )
    }

    @ViewBuilder
    private func applyInsettableShape(
        content: Content,
        fill: AnyShapeStyle,
        tint: Color?,
        stroke: Color,
        strokeWidth: CGFloat,
        shadowColor: Color
    ) -> some View {
        if isCapsule {
            let shape = Capsule(style: .continuous)
            content
                .background {
                    ZStack {
                        shape.fill(fill)
                        if let tint { shape.fill(tint) }
                    }
                }
                .overlay { shape.stroke(stroke, lineWidth: strokeWidth * 2) }
                .clipShape(shape)
                .shadow(color: shadowColor, radius: 12, y: 5)
        } else if theme.cornerStyle == .concentric {
            let shape = ConcentricRectangle(corners: .concentric(minimum: .fixed(scaledRadius)))
            content
                .background {
                    ZStack {
                        shape.fill(fill)
                        if let tint { shape.fill(tint) }
                    }
                }
                .overlay { shape.stroke(stroke, lineWidth: strokeWidth * 2) }
                .clipShape(shape)
                .shadow(color: shadowColor, radius: 12, y: 5)
        } else {
            let shape = RoundedRectangle(cornerRadius: scaledRadius, style: .continuous)
            content
                .background {
                    ZStack {
                        shape.fill(fill)
                        if let tint { shape.fill(tint) }
                    }
                }
                .overlay { shape.stroke(stroke, lineWidth: strokeWidth * 2) }
                .clipShape(shape)
                .shadow(color: shadowColor, radius: 12, y: 5)
        }
    }
}

public extension View {
    /// Applies FluidMacUI's adaptive optical surface (Liquid Glass or Frosted with automatic Reduce Transparency fallback).
    func fmGlassSurface(
        _ role: FMGlassRole = .regular,
        cornerRadius: CGFloat = FMCornerRadius.card,
        isCapsule: Bool = false,
        showShadow: Bool = true
    ) -> some View {
        modifier(
            FMGlassSurfaceModifier(
                role: role,
                cornerRadius: cornerRadius,
                isCapsule: isCapsule,
                showShadow: showShadow
            )
        )
    }

    /// Clips a view using the active theme's continuous or concentric corner curvature.
    func fmClipCorner(_ radius: CGFloat, isCapsule: Bool = false) -> some View {
        modifier(FMCornerClipModifier(radius: radius, isCapsule: isCapsule))
    }
}

private struct FMCornerClipModifier: ViewModifier {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    let radius: CGFloat
    let isCapsule: Bool

    func body(content: Content) -> some View {
        let scaled = radius * density.cornerScale
        if isCapsule {
            content.clipShape(Capsule(style: .continuous))
        } else if theme.cornerStyle == .concentric {
            content.clipShape(ConcentricRectangle(corners: .concentric(minimum: .fixed(scaled))))
        } else {
            content.clipShape(RoundedRectangle(cornerRadius: scaled, style: .continuous))
        }
    }
}
