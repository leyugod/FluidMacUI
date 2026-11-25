import SwiftUI

/// 4pt mathematical spacing scale for consistent macOS rhythm.
public enum FMSpacing {
    /// 4 pt
    public static let xxs: CGFloat = 4
    /// 8 pt
    public static let xs: CGFloat = 8
    /// 12 pt
    public static let sm: CGFloat = 12
    /// 16 pt
    public static let md: CGFloat = 16
    /// 22 pt
    public static let lg: CGFloat = 22
    /// 28 pt
    public static let xl: CGFloat = 28
    /// 36 pt
    public static let xxl: CGFloat = 36
}

/// Environment-driven control density allowing FluidMacUI components to adapt smoothly
/// from dense MenuBar panels & inspectors to spacious iPadOS-style dashboards.
public enum FMDensity: String, CaseIterable, Sendable, Hashable, Identifiable {
    case compact
    case regular
    case comfortable

    public var id: String { rawValue }

    /// Display name for Showcase & settings controls.
    public var displayName: String {
        switch self {
        case .compact: "紧凑"
        case .regular: "标准"
        case .comfortable: "舒展"
        }
    }

    /// Standard control height (buttons, inputs, segmented controls).
    public var controlHeight: CGFloat {
        switch self {
        case .compact: 30
        case .regular: 36
        case .comfortable: 42
        }
    }

    /// Minimum height for `FMRow` list items.
    public var rowMinHeight: CGFloat {
        switch self {
        case .compact: 38
        case .regular: 48
        case .comfortable: 56
        }
    }

    /// Dimensions of the iOS-proportioned `FMToggleStyle` capsule.
    public var toggleSize: CGSize {
        switch self {
        case .compact: CGSize(width: 40, height: 24)
        case .regular: CGSize(width: 48, height: 29)
        case .comfortable: CGSize(width: 52, height: 32)
        }
    }

    /// Side length of `FMIconBadge`.
    public var iconBadgeSize: CGFloat {
        switch self {
        case .compact: 24
        case .regular: 30
        case .comfortable: 34
        }
    }

    /// Horizontal internal padding for rows and cards.
    public var horizontalPadding: CGFloat {
        switch self {
        case .compact: 12
        case .regular: 16
        case .comfortable: 20
        }
    }

    /// Vertical internal padding for rows and cards.
    public var verticalPadding: CGFloat {
        switch self {
        case .compact: 8
        case .regular: 12
        case .comfortable: 15
        }
    }

    /// Corner radius multiplier applied to semantic radii.
    public var cornerScale: CGFloat {
        switch self {
        case .compact: 0.85
        case .regular: 1.0
        case .comfortable: 1.1
        }
    }
}

private struct FMDensityKey: EnvironmentKey {
    static let defaultValue: FMDensity = .regular
}

public extension EnvironmentValues {
    /// Current `FluidMacUI` layout density.
    var fmDensity: FMDensity {
        get { self[FMDensityKey.self] }
        set { self[FMDensityKey.self] = newValue }
    }
}

public extension View {
    /// Sets the `FluidMacUI` density preset for this view hierarchy.
    func fmDensity(_ density: FMDensity) -> some View {
        environment(\.fmDensity, density)
    }
}
