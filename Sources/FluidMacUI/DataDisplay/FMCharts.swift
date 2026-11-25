import SwiftUI

// MARK: - Chart Math Utilities

/// Pure, deterministic math helpers for `FMGauge` and `FMSparkline`.
public enum FMChartMath {
    /// Normalizes `value` into the closed `0...1` unit interval relative to `range`.
    ///
    /// Non-finite inputs and degenerate ranges are handled safely without producing `NaN`.
    public static func normalized(_ value: Double, in range: ClosedRange<Double>) -> Double {
        if value.isNaN { return 0 }
        if value == .infinity { return 1 }
        if value == -.infinity { return 0 }

        let span = range.upperBound - range.lowerBound
        guard span > 0, span.isFinite else {
            return value > range.lowerBound ? 1 : 0
        }

        let raw = (value - range.lowerBound) / span
        return min(max(raw, 0), 1)
    }

    /// Returns the finite minimum and maximum values in `values`, or `nil` if no finite values exist.
    public static func minMax(_ values: [Double]) -> (min: Double, max: Double)? {
        var low = Double.infinity
        var high = -Double.infinity
        var found = false

        for value in values where value.isFinite {
            if value < low { low = value }
            if value > high { high = value }
            found = true
        }

        return found ? (low, high) : nil
    }

    /// Normalizes a series of values into `0...1` `CGFloat` heights suitable for sparkline rendering.
    ///
    /// - Empty arrays return `[]`.
    /// - Constant (flat) arrays or single-point arrays return `0.5` for each element so the line
    ///   renders centered vertically rather than collapsing to an edge.
    public static func normalizedPoints(_ values: [Double]) -> [CGFloat] {
        guard !values.isEmpty else { return [] }
        guard let bounds = minMax(values) else {
            return Array(repeating: 0.5, count: values.count)
        }

        let span = bounds.max - bounds.min
        guard span > 0, span.isFinite else {
            return Array(repeating: 0.5, count: values.count)
        }

        return values.map { value in
            if value.isNaN || value == -.infinity { return 0 }
            if value == .infinity { return 1 }
            let ratio = (value - bounds.min) / span
            return CGFloat(min(max(ratio, 0), 1))
        }
    }

    /// Maps a normalized horizontal position (`0...1`) to the nearest data index for `count` items.
    public static func nearestIndex(forNormalizedX x: CGFloat, count: Int) -> Int? {
        guard count > 0, x.isFinite else { return nil }
        if count == 1 { return 0 }
        let clampedX = min(max(x, 0), 1)
        let rawIndex = Int((clampedX * CGFloat(count - 1)).rounded())
        return min(max(rawIndex, 0), count - 1)
    }

    /// Projects normalized `0...1` values into canvas points inside `size` with optional `inset`.
    ///
    /// Higher normalized values map to smaller SwiftUI `y` coordinates (top of canvas).
    public static func canvasPoints(
        normalizedValues: [CGFloat],
        in size: CGSize,
        inset: CGFloat = 0
    ) -> [CGPoint] {
        guard !normalizedValues.isEmpty, size.width > 0, size.height > 0 else { return [] }

        let horizontalInset = min(max(inset, 0), size.width * 0.5)
        let verticalInset = min(max(inset, 0), size.height * 0.5)
        let usableWidth = max(0, size.width - horizontalInset * 2)
        let usableHeight = max(0, size.height - verticalInset * 2)

        if normalizedValues.count == 1 {
            let clampedY = min(max(normalizedValues[0], 0), 1)
            let y = verticalInset + (1 - clampedY) * usableHeight
            return [CGPoint(x: size.width * 0.5, y: y)]
        }

        let stepX = usableWidth / CGFloat(normalizedValues.count - 1)
        return normalizedValues.enumerated().map { index, value in
            let clampedY = min(max(value, 0), 1)
            let x = horizontalInset + CGFloat(index) * stepX
            let y = verticalInset + (1 - clampedY) * usableHeight
            return CGPoint(x: x, y: y)
        }
    }
}

// MARK: - Gauge Shapes

private struct FMGaugeArcShape: Shape {
    var startDegrees: Double
    var sweepDegrees: Double
    var progress: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    nonisolated func path(in rect: CGRect) -> Path {
        let clamped = min(max(progress, 0), 1)
        guard clamped > 0 else { return Path() }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = max(0, min(rect.width, rect.height) * 0.5)
        let endDegrees = startDegrees + sweepDegrees * clamped

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startDegrees),
            endAngle: .degrees(endDegrees),
            clockwise: false
        )
        return path
    }
}

// MARK: - FMGauge

/// Visual presentation style for `FMGauge`.
public enum FMGaugeStyle: Sendable, Hashable {
    /// 240-degree speedometer-style open arc with centered readout and bottom label.
    case arc
    /// Full 360-degree circular ring starting from 12 o'clock.
    case ring
    /// Compact horizontal linear capacity bar with header label and tabular readout.
    case linearCapacity
}

/// Pure-SwiftUI telemetry gauge featuring 240° arc, full ring, and linear capacity styles
/// with smooth spring interpolation, tabular numeric readouts, Reduce Motion / Reduce Transparency
/// adaptations, and complete VoiceOver accessibility.
public struct FMGauge: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let value: Double
    private let range: ClosedRange<Double>
    private let label: String?
    private let valueText: String?
    private let style: FMGaugeStyle
    private let size: CGFloat
    private let gradient: [Color]?

    public init(
        value: Double,
        in range: ClosedRange<Double> = 0...1,
        label: String? = nil,
        valueText: String? = nil,
        style: FMGaugeStyle = .arc,
        size: CGFloat = 84,
        gradient: [Color]? = nil
    ) {
        self.value = value
        self.range = range
        self.label = label
        self.valueText = valueText
        self.style = style
        self.size = max(36, size)
        self.gradient = gradient
    }

    private var normalizedValue: Double {
        FMChartMath.normalized(value, in: range)
    }

    private var displayValue: String {
        valueText ?? "\(Int((normalizedValue * 100).rounded()))%"
    }

    private var isHighContrast: Bool {
        contrast == .increased || reduceTransparency
    }

    private var trackColor: Color {
        if isHighContrast {
            return FMColor.separator(colorScheme, highContrast: true)
        }
        return FMColor.controlFill(colorScheme)
    }

    private var resolvedGradientColors: [Color] {
        let baseAccent = FMColor.adaptiveAccent(
            theme.accentColor,
            activeState: activeState,
            scheme: colorScheme
        )
        guard let gradient, !gradient.isEmpty else {
            return [baseAccent.opacity(0.78), baseAccent]
        }
        if gradient.count == 1 {
            return [gradient[0].opacity(0.8), gradient[0]]
        }
        return gradient
    }

    public var body: some View {
        Group {
            switch style {
            case .arc:
                arcGaugeBody
            case .ring:
                ringGaugeBody
            case .linearCapacity:
                linearGaugeBody
            }
        }
        .saturation(gradient != nil && activeState == .inactive ? 0.28 : 1.0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "Gauge")
        .accessibilityValue(displayValue)
    }

    private var arcGaugeBody: some View {
        let strokeWidth = max(5, size * 0.105)
        let startDegrees: Double = 150
        let sweepDegrees: Double = 240
        let colors = resolvedGradientColors

        return ZStack {
            FMGaugeArcShape(startDegrees: startDegrees, sweepDegrees: sweepDegrees, progress: 1)
                .stroke(
                    trackColor,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .padding(strokeWidth * 0.5)

            FMGaugeArcShape(
                startDegrees: startDegrees,
                sweepDegrees: sweepDegrees,
                progress: normalizedValue
            )
            .stroke(
                AngularGradient(
                    colors: colors,
                    center: .center,
                    startAngle: .degrees(startDegrees),
                    endAngle: .degrees(startDegrees + sweepDegrees)
                ),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
            )
            .padding(strokeWidth * 0.5)
            .fmAnimation(.navigation, value: normalizedValue)

            VStack(spacing: 1) {
                Text(displayValue)
                    .font(.fmNumeric(size: max(11, size * 0.22), weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .contentTransition(reduceMotion ? .identity : .numericText(value: normalizedValue))
                    .fmAnimation(.micro, value: normalizedValue)

                if let label, !label.isEmpty {
                    Text(label)
                        .font(.system(size: max(9.5, size * 0.125), weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .padding(.horizontal, strokeWidth + 4)
            .offset(y: size * 0.04)
        }
        .frame(width: size, height: size)
    }

    private var ringGaugeBody: some View {
        let strokeWidth = max(5, size * 0.105)
        let startDegrees: Double = -90
        let sweepDegrees: Double = 360
        let colors = resolvedGradientColors

        return ZStack {
            Circle()
                .stroke(trackColor, lineWidth: strokeWidth)
                .padding(strokeWidth * 0.5)

            FMGaugeArcShape(
                startDegrees: startDegrees,
                sweepDegrees: sweepDegrees,
                progress: normalizedValue
            )
            .stroke(
                AngularGradient(
                    colors: colors,
                    center: .center,
                    startAngle: .degrees(startDegrees),
                    endAngle: .degrees(startDegrees + sweepDegrees)
                ),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
            )
            .padding(strokeWidth * 0.5)
            .fmAnimation(.navigation, value: normalizedValue)

            VStack(spacing: 1) {
                Text(displayValue)
                    .font(.fmNumeric(size: max(11, size * 0.22), weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .contentTransition(reduceMotion ? .identity : .numericText(value: normalizedValue))
                    .fmAnimation(.micro, value: normalizedValue)

                if let label, !label.isEmpty {
                    Text(label)
                        .font(.system(size: max(9.5, size * 0.12), weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .padding(.horizontal, strokeWidth + 4)
        }
        .frame(width: size, height: size)
    }

    private var linearGaugeBody: some View {
        let barHeight: CGFloat = {
            switch density {
            case .compact: 6
            case .regular: 8
            case .comfortable: 10
            }
        }()
        let colors = resolvedGradientColors

        return VStack(alignment: .leading, spacing: FMSpacing.xxs + 2) {
            HStack(alignment: .firstTextBaseline, spacing: FMSpacing.xs) {
                if let label, !label.isEmpty {
                    Text(label)
                        .font(.fmCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: FMSpacing.xs)
                Text(displayValue)
                    .font(.fmNumeric(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .contentTransition(reduceMotion ? .identity : .numericText(value: normalizedValue))
                    .fmAnimation(.micro, value: normalizedValue)
            }

            GeometryReader { proxy in
                let width = max(1, proxy.size.width)
                let fillWidth: CGFloat = normalizedValue <= 0
                    ? 0
                    : max(barHeight, width * normalizedValue)

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(trackColor)

                    if fillWidth > 0 {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: colors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: min(width, fillWidth))
                            .fmAnimation(.navigation, value: normalizedValue)
                    }
                }
                .clipShape(Capsule(style: .continuous))
            }
            .frame(height: barHeight)
        }
        .frame(minWidth: size)
    }
}

// MARK: - FMSparkline

/// Pure-SwiftUI `Canvas` sparkline mini-chart with smooth clamped Catmull-Rom curves,
/// optional gradient area fill, interactive hover scrub readout pill, Reduce Motion /
/// Reduce Transparency support, and VoiceOver summary.
public struct FMSparkline: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let values: [Double]
    private let color: Color?
    private let lineWidth: CGFloat
    private let showsAreaFill: Bool
    private let showsHoverScrub: Bool
    private let valueFormatter: ((Double) -> String)?

    @State private var hoveredIndex: Int?

    public init(
        values: [Double],
        color: Color? = nil,
        lineWidth: CGFloat = 2,
        showsAreaFill: Bool = true,
        showsHoverScrub: Bool = true,
        valueFormatter: ((Double) -> String)? = nil
    ) {
        self.values = values
        self.color = color
        self.lineWidth = max(1, lineWidth)
        self.showsAreaFill = showsAreaFill
        self.showsHoverScrub = showsHoverScrub
        self.valueFormatter = valueFormatter
    }

    private var strokeInset: CGFloat {
        max(4, lineWidth * 2)
    }

    private var resolvedTint: Color {
        FMColor.adaptiveAccent(
            color ?? theme.accentColor,
            activeState: activeState,
            scheme: colorScheme
        )
    }

    private func format(_ value: Double) -> String {
        if let valueFormatter {
            return valueFormatter(value)
        }
        if value.rounded() == value, abs(value) < 1_000_000 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private var accessibilitySummary: String {
        guard let last = values.last, let bounds = FMChartMath.minMax(values) else {
            return "No data"
        }
        return "Latest \(format(last)), minimum \(format(bounds.min)), maximum \(format(bounds.max)), \(values.count) points"
    }

    public var body: some View {
        let tint = resolvedTint
        let normalized = FMChartMath.normalizedPoints(values)
        let isHighContrast = contrast == .increased || reduceTransparency

        GeometryReader { proxy in
            let size = proxy.size
            let points = FMChartMath.canvasPoints(
                normalizedValues: normalized,
                in: size,
                inset: strokeInset
            )

            ZStack(alignment: .topLeading) {
                Canvas { context, canvasSize in
                    let canvasPoints = FMChartMath.canvasPoints(
                        normalizedValues: normalized,
                        in: canvasSize,
                        inset: strokeInset
                    )
                    guard !canvasPoints.isEmpty else { return }

                    if canvasPoints.count == 1 {
                        let pt = canvasPoints[0]
                        let dotRect = CGRect(
                            x: pt.x - lineWidth * 1.5,
                            y: pt.y - lineWidth * 1.5,
                            width: lineWidth * 3,
                            height: lineWidth * 3
                        )
                        context.fill(Path(ellipseIn: dotRect), with: .color(tint))
                        return
                    }

                    let linePath = Self.smoothPath(
                        through: canvasPoints,
                        minY: strokeInset,
                        maxY: max(strokeInset, canvasSize.height - strokeInset)
                    )

                    if showsAreaFill, let first = canvasPoints.first, let last = canvasPoints.last {
                        var areaPath = linePath
                        let bottomY = canvasSize.height - strokeInset * 0.25
                        areaPath.addLine(to: CGPoint(x: last.x, y: bottomY))
                        areaPath.addLine(to: CGPoint(x: first.x, y: bottomY))
                        areaPath.closeSubpath()

                        let topOpacity: Double = reduceTransparency ? 0.26 : (colorScheme == .dark ? 0.28 : 0.20)
                        context.fill(
                            areaPath,
                            with: .linearGradient(
                                Gradient(colors: [tint.opacity(topOpacity), tint.opacity(0.0)]),
                                startPoint: CGPoint(x: canvasSize.width * 0.5, y: strokeInset),
                                endPoint: CGPoint(x: canvasSize.width * 0.5, y: bottomY)
                            )
                        )
                    }

                    context.stroke(
                        linePath,
                        with: .color(tint),
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )

                    if let hoveredIndex, canvasPoints.indices.contains(hoveredIndex) {
                        let activePoint = canvasPoints[hoveredIndex]

                        var guide = Path()
                        guide.move(to: CGPoint(x: activePoint.x, y: strokeInset * 0.5))
                        guide.addLine(to: CGPoint(x: activePoint.x, y: canvasSize.height - strokeInset * 0.5))
                        context.stroke(
                            guide,
                            with: .color(
                                FMColor.separator(colorScheme, highContrast: isHighContrast)
                                    .opacity(isHighContrast ? 1.0 : 0.85)
                            ),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                        )

                        let outerRadius = max(4.5, lineWidth * 2.1)
                        let outerRect = CGRect(
                            x: activePoint.x - outerRadius,
                            y: activePoint.y - outerRadius,
                            width: outerRadius * 2,
                            height: outerRadius * 2
                        )
                        context.fill(Path(ellipseIn: outerRect), with: .color(tint))

                        let innerRadius = max(2.2, lineWidth * 0.95)
                        let innerRect = CGRect(
                            x: activePoint.x - innerRadius,
                            y: activePoint.y - innerRadius,
                            width: innerRadius * 2,
                            height: innerRadius * 2
                        )
                        context.fill(
                            Path(ellipseIn: innerRect),
                            with: .color(FMColor.canvasBackground(colorScheme))
                        )
                    }
                }

                if showsHoverScrub,
                   let hoveredIndex,
                   values.indices.contains(hoveredIndex),
                   points.indices.contains(hoveredIndex)
                {
                    let activePoint = points[hoveredIndex]
                    let pillHalfWidth: CGFloat = 34
                    let clampedX = min(
                        max(activePoint.x, pillHalfWidth + 2),
                        max(pillHalfWidth + 2, size.width - pillHalfWidth - 2)
                    )

                    scrubPill(value: values[hoveredIndex], tint: tint, highContrast: isHighContrast)
                        .position(x: clampedX, y: 12)
                        .allowsHitTesting(false)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.92)))
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                guard showsHoverScrub, !values.isEmpty else {
                    hoveredIndex = nil
                    return
                }
                switch phase {
                case .active(let location):
                    let usableWidth = max(1, size.width - strokeInset * 2)
                    let normalizedX = (location.x - strokeInset) / usableWidth
                    let nextIndex = FMChartMath.nearestIndex(forNormalizedX: normalizedX, count: values.count)
                    if nextIndex != hoveredIndex {
                        withAnimation(
                            FMSpring.animation(.interactive, reduceMotion: reduceMotion, speed: theme.animationSpeed)
                        ) {
                            hoveredIndex = nextIndex
                        }
                        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                    }
                case .ended:
                    withAnimation(
                        FMSpring.animation(.micro, reduceMotion: reduceMotion, speed: theme.animationSpeed)
                    ) {
                        hoveredIndex = nil
                    }
                }
            }
        }
        .frame(minHeight: 32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sparkline")
        .accessibilityValue(accessibilitySummary)
    }

    private func scrubPill(value: Double, tint: Color, highContrast: Bool) -> some View {
        Text(format(value))
            .font(.fmNumeric(size: 10.5, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        reduceTransparency
                            ? AnyShapeStyle(FMColor.elevatedOpaqueSurface(colorScheme))
                            : AnyShapeStyle(.regularMaterial)
                    )
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        highContrast ? tint.opacity(0.8) : FMColor.separator(colorScheme, highContrast: true),
                        lineWidth: highContrast ? 1 : 0.5
                    )
            }
            .shadow(
                color: reduceTransparency ? .clear : Color.black.opacity(colorScheme == .dark ? 0.28 : 0.1),
                radius: 4,
                y: 2
            )
    }

    /// Generates a monotonic-clamped Catmull-Rom spline through `points` so curves remain smooth
    /// without overshooting the canvas vertical bounds.
    private static func smoothPath(through points: [CGPoint], minY: CGFloat, maxY: CGFloat) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)

        guard points.count > 2 else {
            if points.count == 2 {
                path.addLine(to: points[1])
            }
            return path
        }

        for index in 0..<(points.count - 1) {
            let p0 = index > 0 ? points[index - 1] : points[index]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = index + 2 < points.count ? points[index + 2] : points[index + 1]

            let c1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6.0,
                y: min(max(p1.y + (p2.y - p0.y) / 6.0, minY), maxY)
            )
            let c2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6.0,
                y: min(max(p2.y - (p3.y - p1.y) / 6.0, minY), maxY)
            )
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }
}
