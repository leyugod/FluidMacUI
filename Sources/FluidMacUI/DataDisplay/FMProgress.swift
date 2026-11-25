import SwiftUI

/// iOS Activity / Fitness-inspired circular progress ring with gradient stroke,
/// round end-caps, spring value interpolation, and optional centered percentage readout.
public struct FMProgressRing: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let progress: Double?
    private let lineWidth: CGFloat
    private let size: CGFloat
    private let colors: [Color]?
    private let showsLabel: Bool

    @State private var spinAngle: Double = 0

    public init(
        progress: Double?,
        size: CGFloat = 56,
        lineWidth: CGFloat = 6,
        colors: [Color]? = nil,
        showsLabel: Bool = true
    ) {
        self.progress = progress.map { min(max($0, 0), 1) }
        self.size = size
        self.lineWidth = lineWidth
        self.colors = colors
        self.showsLabel = showsLabel
    }

    public var body: some View {
        let baseAccent = FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
        let gradientColors = colors ?? [baseAccent.opacity(0.75), baseAccent]

        ZStack {
            Circle()
                .stroke(FMColor.controlFill(colorScheme), lineWidth: lineWidth)

            if let progress {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: gradientColors,
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .fmAnimation(.navigation, value: progress)

                if showsLabel {
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.fmNumeric(size: max(10, size * 0.23), weight: .bold))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText(value: progress))
                        .fmAnimation(.micro, value: progress)
                }
            } else {
                Circle()
                    .trim(from: 0.08, to: 0.72)
                    .stroke(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(spinAngle))
                    .onChange(of: !reduceMotion && activeState != .inactive, initial: true) { _, shouldAnimate in
                        if shouldAnimate {
                            spinAngle = 0
                            withAnimation(.linear(duration: 1.05).repeatForever(autoreverses: false)) {
                                spinAngle = 360
                            }
                        } else {
                            withAnimation(.easeOut(duration: 0.15)) {
                                spinAngle = 0
                            }
                        }
                    }
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Progress")
        .accessibilityValue(progress.map { "\(Int(($0 * 100).rounded())) percent" } ?? "Loading")
    }
}

/// Capsule linear progress bar with smooth gradient fill, spring interpolation,
/// and indeterminate gliding pulse.
public struct FMProgressBar: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let progress: Double?
    private let height: CGFloat
    private let colors: [Color]?

    @State private var indeterminatePhase: CGFloat = -0.35

    public init(
        progress: Double?,
        height: CGFloat = 8,
        colors: [Color]? = nil
    ) {
        self.progress = progress.map { min(max($0, 0), 1) }
        self.height = height
        self.colors = colors
    }

    public var body: some View {
        let baseAccent = FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
        let gradientColors = colors ?? [baseAccent.opacity(0.82), baseAccent]

        GeometryReader { proxy in
            let width = max(1, proxy.size.width)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(FMColor.controlFill(colorScheme))

                if let progress {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(progress > 0 ? height : 0, width * progress))
                        .fmAnimation(.navigation, value: progress)
                } else {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.clear, baseAccent, .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width * 0.42)
                        .offset(x: width * indeterminatePhase)
                        .onChange(of: !reduceMotion && activeState != .inactive, initial: true) { _, shouldAnimate in
                            if shouldAnimate {
                                indeterminatePhase = -0.35
                                withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: false)) {
                                    indeterminatePhase = 1.05
                                }
                            } else {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    indeterminatePhase = 0.29
                                }
                            }
                        }
                }
            }
            .clipShape(Capsule(style: .continuous))
        }
        .frame(height: height)
        .accessibilityLabel("Progress")
        .accessibilityValue(progress.map { "\(Int(($0 * 100).rounded())) percent" } ?? "Loading")
    }
}
