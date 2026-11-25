import SwiftUI
import AppKit

/// Rendering backend for translucent surfaces.
public enum FMSurfaceStyle: String, CaseIterable, Sendable, Hashable, Identifiable {
    /// macOS 26+ native Liquid Glass optical lensing & container morphing.
    case liquidGlass
    /// Classic frosted vibrancy material with 0.5pt inner specular rim.
    case frosted

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .liquidGlass: "Liquid Glass"
        case .frosted: "经典磨砂"
        }
    }
}

/// Corner curvature strategy.
public enum FMCornerStyle: String, CaseIterable, Sendable, Hashable, Identifiable {
    /// macOS 26+ Concentric corner system aligned optically to parent bounds.
    case concentric
    /// Classic Apple squircle continuous curvature (`RoundedRectangle(style: .continuous)`).
    case continuous

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .concentric: "同心曲率"
        case .continuous: "超椭圆连续"
        }
    }
}

/// Global environment-injected theme configuration for `FluidMacUI`.
public struct FMTheme: Sendable, Equatable {
    public var accentColor: Color
    public var surfaceStyle: FMSurfaceStyle
    public var cornerStyle: FMCornerStyle
    public var hapticsEnabled: Bool
    /// Multiplier for animation speed (`1.0` = real-time, `0.3` = slow-motion inspection).
    public var animationSpeed: Double

    public init(
        accentColor: Color = FMColor.blue,
        surfaceStyle: FMSurfaceStyle = .liquidGlass,
        cornerStyle: FMCornerStyle = .concentric,
        hapticsEnabled: Bool = true,
        animationSpeed: Double = 1.0
    ) {
        self.accentColor = accentColor
        self.surfaceStyle = surfaceStyle
        self.cornerStyle = cornerStyle
        self.hapticsEnabled = hapticsEnabled
        self.animationSpeed = max(0.1, min(animationSpeed, 3.0))
    }

    public static let `default` = FMTheme()

    public static let vibrant = FMTheme(
        accentColor: FMColor.indigo,
        surfaceStyle: .liquidGlass,
        cornerStyle: .concentric
    )

    public static let frostedClassic = FMTheme(
        accentColor: FMColor.blue,
        surfaceStyle: .frosted,
        cornerStyle: .continuous
    )
}

/// Semantic color palette combining iOS vibrancy with macOS dark/light/inactive/high-contrast fidelity.
public enum FMColor {
    // MARK: - iOS High-Saturation Semantic Hues
    public static let blue = Color(red: 0.04, green: 0.52, blue: 1.0)
    public static let indigo = Color(red: 0.35, green: 0.34, blue: 0.84)
    public static let purple = Color(red: 0.69, green: 0.32, blue: 0.87)
    public static let pink = Color(red: 1.0, green: 0.22, blue: 0.37)
    public static let red = Color(red: 1.0, green: 0.27, blue: 0.23)
    public static let orange = Color(red: 1.0, green: 0.58, blue: 0.0)
    public static let yellow = Color(red: 1.0, green: 0.80, blue: 0.0)
    public static let green = Color(red: 0.19, green: 0.82, blue: 0.35)
    public static let mint = Color(red: 0.0, green: 0.78, blue: 0.75)
    public static let teal = Color(red: 0.19, green: 0.69, blue: 0.78)

    // MARK: - Dynamic Surface Tokens
    /// Clean Apple first-party macOS detail canvas (#1C1C1E dark / #FFFFFF light).
    public static func canvasBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.114, green: 0.114, blue: 0.122)
            : Color.white
    }

    /// Subtle darker/frosted sidebar surface creating clear depth against the detail canvas.
    public static func sidebarBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.088, green: 0.090, blue: 0.098)
            : Color(red: 0.955, green: 0.958, blue: 0.968)
    }

    /// Native macOS restrained translucent neutral selection pill for sidebars and lists.
    public static func sidebarSelection(_ scheme: ColorScheme, activeState: ControlActiveState = .active) -> Color {
        if activeState == .inactive {
            return scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.045)
        }
        return scheme == .dark ? Color.white.opacity(0.115) : Color.black.opacity(0.075)
    }

    public static func groupedBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.095, green: 0.098, blue: 0.108)
            : Color(red: 0.945, green: 0.95, blue: 0.968)
    }

    public static func elevatedSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.052)
            : Color.black.opacity(0.028)
    }

    public static func elevatedOpaqueSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.155, green: 0.157, blue: 0.168)
            : Color(red: 0.975, green: 0.977, blue: 0.985)
    }

    public static func controlFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.085)
            : Color.black.opacity(0.055)
    }

    public static func controlHoverFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.13)
            : Color.black.opacity(0.09)
    }

    public static func separator(_ scheme: ColorScheme, highContrast: Bool = false) -> Color {
        if highContrast {
            return scheme == .dark ? Color.white.opacity(0.26) : Color.black.opacity(0.22)
        }
        return scheme == .dark ? Color.white.opacity(0.085) : Color.black.opacity(0.08)
    }

    public static func hairlineHighlight(_ scheme: ColorScheme, highContrast: Bool = false) -> Color {
        if highContrast {
            return scheme == .dark ? Color.white.opacity(0.28) : Color.black.opacity(0.20)
        }
        return scheme == .dark ? Color.white.opacity(0.085) : Color.black.opacity(0.065)
    }

    /// Gracefully desaturates accent colors when the hosting macOS window is inactive.
    public static func adaptiveAccent(
        _ accent: Color,
        activeState: ControlActiveState,
        scheme: ColorScheme
    ) -> Color {
        guard activeState != .inactive else {
            return scheme == .dark
                ? Color.white.opacity(0.28)
                : Color.black.opacity(0.24)
        }
        return accent
    }
}

private struct FMThemeKey: EnvironmentKey {
    static let defaultValue = FMTheme.default
}

public extension EnvironmentValues {
    /// Active `FluidMacUI` theme configuration.
    var fmTheme: FMTheme {
        get { self[FMThemeKey.self] }
        set { self[FMThemeKey.self] = newValue }
    }
}

public extension View {
    /// Injects a custom `FMTheme` into the view hierarchy.
    func fmTheme(_ theme: FMTheme) -> some View {
        environment(\.fmTheme, theme)
    }
}
