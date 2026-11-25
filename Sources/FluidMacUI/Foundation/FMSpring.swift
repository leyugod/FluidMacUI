import SwiftUI

/// Four-tier physical spring choreography calibrated for macOS pointer & trackpad ergonomics.
public enum FMSpringLevel: Sendable, Hashable {
    /// Tactile micro-interactions: button press squish, toggle thumb stretch, hover lift.
    case micro
    /// Navigation push/pop parallax and segmented indicator gliding.
    case navigation
    /// Bottom sheets, Dynamic HUD morphing, alerts, and accordion expansion.
    case modal
    /// Direct manipulation tracking during drag or two-finger swipe gestures.
    case interactive

    public var response: Double {
        switch self {
        case .micro: 0.22
        case .navigation: 0.36
        case .modal: 0.42
        case .interactive: 0.15
        }
    }

    public var dampingFraction: Double {
        switch self {
        case .micro: 0.68
        case .navigation: 0.84
        case .modal: 0.78
        case .interactive: 0.86
        }
    }

    public var reducedMotionDuration: Double {
        switch self {
        case .micro: 0.12
        case .navigation: 0.18
        case .modal: 0.20
        case .interactive: 0.08
        }
    }
}

/// Static spring factory honoring `accessibilityReduceMotion` and `FMTheme.animationSpeed`.
public enum FMSpring {
    public static var micro: Animation {
        .spring(response: FMSpringLevel.micro.response, dampingFraction: FMSpringLevel.micro.dampingFraction)
    }

    public static var navigation: Animation {
        .spring(response: FMSpringLevel.navigation.response, dampingFraction: FMSpringLevel.navigation.dampingFraction)
    }

    public static var modal: Animation {
        .spring(response: FMSpringLevel.modal.response, dampingFraction: FMSpringLevel.modal.dampingFraction)
    }

    public static var interactive: Animation {
        .spring(response: FMSpringLevel.interactive.response, dampingFraction: FMSpringLevel.interactive.dampingFraction)
    }

    /// Resolves the appropriate animation curve accounting for accessibility and lab playback speed.
    public static func animation(
        _ level: FMSpringLevel,
        reduceMotion: Bool = false,
        speed: Double = 1.0
    ) -> Animation {
        let clampedSpeed = max(0.1, min(speed, 3.0))
        if reduceMotion {
            return .easeOut(duration: level.reducedMotionDuration / clampedSpeed)
        }
        return .spring(
            response: level.response / clampedSpeed,
            dampingFraction: level.dampingFraction
        )
    }
}

private struct FMAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.fmTheme) private var theme

    let level: FMSpringLevel
    let value: V

    func body(content: Content) -> some View {
        content.animation(
            FMSpring.animation(level, reduceMotion: reduceMotion, speed: theme.animationSpeed),
            value: value
        )
    }
}

public extension View {
    /// Applies a `FluidMacUI` spring animation that automatically respects
    /// Reduce Motion and the active `FMTheme.animationSpeed`.
    func fmAnimation<V: Equatable>(_ level: FMSpringLevel, value: V) -> some View {
        modifier(FMAnimationModifier(level: level, value: value))
    }
}
