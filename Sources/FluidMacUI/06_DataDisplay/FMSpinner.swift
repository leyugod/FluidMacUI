import SwiftUI

/// Visual style for `FMSpinner`.
public enum FMSpinnerStyle: Sendable, Hashable {
    /// Continuous fluid gradient-tailed ring spinner.
    case ring
    /// Classic Apple-style 8-petal radial activity indicator.
    case petals
}

/// Standardized diameter presets for `FMSpinner`.
public enum FMSpinnerSize: Sendable, Hashable {
    /// 14pt diameter (ideal for inline buttons, HUD capsules, and status bars).
    case small
    /// 20pt diameter (default for inline loading rows and forms).
    case regular
    /// 32pt diameter (ideal for empty states and centered loading overlays).
    case large

    /// Outer square dimension in points.
    public var dimension: CGFloat {
        switch self {
        case .small: 14
        case .regular: 20
        case .large: 32
        }
    }

    /// Calibrated stroke thickness for `.ring` style.
    public var strokeWidth: CGFloat {
        switch self {
        case .small: 2.0
        case .regular: 2.5
        case .large: 3.25
        }
    }
}

/// Pure-SwiftUI activity indicator replacing AppKit's legacy `NSProgressIndicator`.
///
/// Supports continuous `.ring` and 8-petal `.petals` styles, respects `FMTheme.animationSpeed`,
/// and automatically pauses rendering when Reduce Motion is enabled or the hosting window is inactive.
public struct FMSpinner: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let style: FMSpinnerStyle
    private let size: FMSpinnerSize
    private let tint: Color?

    /// Creates a pure-SwiftUI activity spinner.
    /// - Parameters:
    ///   - style: Visual style (`.ring` or `.petals`).
    ///   - size: Semantic diameter preset (`.small`, `.regular`, `.large`).
    ///   - tint: Optional custom tint color. Defaults to the active adaptive theme accent.
    public init(
        style: FMSpinnerStyle = .ring,
        size: FMSpinnerSize = .regular,
        tint: Color? = nil
    ) {
        self.style = style
        self.size = size
        self.tint = tint
    }

    private var resolvedColor: Color {
        if let tint {
            return activeState == .inactive ? tint.opacity(0.55) : tint
        }
        return FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
    }

    private var isPaused: Bool {
        reduceMotion || activeState == .inactive
    }

    public var body: some View {
        TimelineView(.animation(paused: isPaused)) { context in
            let cycleDuration = max(0.25, 0.95 / max(0.1, theme.animationSpeed))
            let phase = isPaused
                ? 0.0
                : context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: cycleDuration) / cycleDuration

            switch style {
            case .ring:
                ringBody(phase: phase)
            case .petals:
                petalsBody(phase: phase)
            }
        }
        .frame(width: size.dimension, height: size.dimension)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }

    private func ringBody(phase: Double) -> some View {
        let color = resolvedColor
        let strokeWidth = size.strokeWidth

        return ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: strokeWidth)

            Circle()
                .trim(from: 0.08, to: 0.72)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: color.opacity(0.05), location: 0.08),
                            .init(color: color, location: 0.72)
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(reduceMotion ? -45 : phase * 360.0))
        }
    }

    private func petalsBody(phase: Double) -> some View {
        let count = 8
        let color = resolvedColor
        let dim = size.dimension
        let petalWidth = max(1.6, dim * 0.13)
        let petalLength = dim * 0.28
        let offsetY = -(dim * 0.34)
        let activeHead = phase * Double(count)

        return ZStack {
            ForEach(0..<count, id: \.self) { index in
                let opacity = petalOpacity(index: index, count: count, head: activeHead)
                Capsule(style: .continuous)
                    .fill(color.opacity(opacity))
                    .frame(width: petalWidth, height: petalLength)
                    .offset(y: offsetY)
                    .rotationEffect(.degrees(Double(index) * (360.0 / Double(count))))
            }
        }
    }

    private func petalOpacity(index: Int, count: Int, head: Double) -> Double {
        if reduceMotion {
            return 0.25 + 0.65 * (Double(index) / Double(max(1, count - 1)))
        }
        var distance = head - Double(index)
        if distance < 0 { distance += Double(count) }
        let normalized = 1.0 - (distance / Double(count))
        return 0.16 + 0.84 * pow(max(0, min(1, normalized)), 1.6)
    }
}
