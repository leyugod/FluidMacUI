import SwiftUI

/// Visual presentation style for `FMSlider`.
public enum FMSliderStyle: Sendable, Hashable {
    /// Classic iOS circular thumb slider with subtle hover & drag magnification.
    case standard
    /// iOS Control Center wide-body capsule fill slider that expands subtly during drag.
    case controlCenterCapsule
}

/// Pure calculation helpers for `FMSlider` (tested independently).
public enum FMSliderMath {
    public static func progress(value: Double, in range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(max((value - range.lowerBound) / span, 0), 1)
    }

    /// Maps a horizontal pointer coordinate to normalized progress `0...1`, accounting for
    /// circular thumb half-width insets when `thumbDiameter > 0`.
    public static func progress(
        locationX: CGFloat,
        trackWidth: CGFloat,
        thumbDiameter: CGFloat = 0
    ) -> Double {
        let usable = max(1, trackWidth - thumbDiameter)
        let adjusted = locationX - thumbDiameter * 0.5
        return min(max(Double(adjusted / usable), 0), 1)
    }

    public static func value(
        forProgress progress: Double,
        in range: ClosedRange<Double>,
        step: Double? = nil
    ) -> Double {
        let clamped = min(max(progress, 0), 1)
        let raw = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
        guard let step, step > 0 else {
            return raw
        }
        let steps = ((raw - range.lowerBound) / step).rounded()
        let snapped = range.lowerBound + steps * step
        return min(max(snapped, range.lowerBound), range.upperBound)
    }
}

/// Tactile fluid slider supporting standard circular thumb and Control Center capsule styles,
/// optional step snapping with Force Touch detent haptics, and keyboard arrow adjustments.
public struct FMSlider: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.isEnabled) private var isEnabled

    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let step: Double?
    private let style: FMSliderStyle
    private let tint: Color?
    private let icon: String?

    @State private var isDragging = false
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    public init(
        value: Binding<Double>,
        in range: ClosedRange<Double> = 0...1,
        step: Double? = nil,
        style: FMSliderStyle = .standard,
        tint: Color? = nil,
        icon: String? = nil
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.style = style
        self.tint = tint
        self.icon = icon
    }

    private var accent: Color {
        FMColor.adaptiveAccent(
            tint ?? theme.accentColor,
            activeState: activeState,
            scheme: colorScheme
        )
    }

    public var body: some View {
        let progress = FMSliderMath.progress(value: value, in: range)

        GeometryReader { proxy in
            let width = max(1, proxy.size.width)

            Group {
                switch style {
                case .standard:
                    standardTrack(width: width, progress: progress)
                case .controlCenterCapsule:
                    capsuleTrack(width: width, progress: progress)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard isEnabled else { return }
                        isDragging = true
                        let thumbInset: CGFloat = style == .standard ? 18 : 0
                        let ratio = FMSliderMath.progress(
                            locationX: gesture.location.x,
                            trackWidth: width,
                            thumbDiameter: thumbInset
                        )
                        updateValue(forProgress: ratio)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(height: style == .controlCenterCapsule ? max(24, density.controlHeight - 6) : 26)
        .opacity(isEnabled ? 1.0 : 0.45)
        .focusable(isEnabled)
        .focused($isFocused)
        .focusEffectDisabled()
        .fmFocusRing(isFocused: isFocused, isCapsule: true, color: tint)
        .onKeyPress(.leftArrow) {
            nudge(by: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            nudge(by: 1)
            return .handled
        }
        .onHover { isHovered = $0 }
        .fmAnimation(.micro, value: isDragging)
        .fmAnimation(.micro, value: isHovered)
        .accessibilityElement(children: .ignore)
        .accessibilityValue("\(Int((progress * 100).rounded()))%")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: nudge(by: 1)
            case .decrement: nudge(by: -1)
            @unknown default: break
            }
        }
    }

    @ViewBuilder
    private func standardTrack(width: CGFloat, progress: Double) -> some View {
        let trackHeight: CGFloat = isDragging ? 6 : 5
        let thumbDiameter: CGFloat = isDragging ? 20 : (isHovered ? 19 : 17)
        let usableWidth = max(1, width - thumbDiameter)
        let thumbOffset = CGFloat(progress) * usableWidth

        ZStack(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(FMColor.controlFill(colorScheme))
                .frame(height: trackHeight)

            Capsule(style: .continuous)
                .fill(accent)
                .frame(width: max(trackHeight, thumbOffset + thumbDiameter * 0.5), height: trackHeight)

            Circle()
                .fill(.white)
                .frame(width: thumbDiameter, height: thumbDiameter)
                .shadow(color: .black.opacity(0.22), radius: isDragging ? 5 : 3, y: 1.5)
                .overlay {
                    Circle().strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
                }
                .offset(x: thumbOffset)
        }
    }

    @ViewBuilder
    private func capsuleTrack(width: CGFloat, progress: Double) -> some View {
        let baseHeight = max(20, density.controlHeight - 10)
        let activeHeight = isDragging ? baseHeight + 3 : baseHeight
        let fillWidth = progress <= 0.001 ? 0 : max(activeHeight * 0.65, width * CGFloat(progress))

        ZStack(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(FMColor.controlFill(colorScheme))

            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.88), accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: min(width, fillWidth))

            if let icon {
                Image(systemName: icon)
                    .font(.system(size: activeHeight * 0.48, weight: .semibold))
                    .foregroundStyle(progress > 0.18 ? Color.white : Color.secondary)
                    .padding(.leading, 9)
            }
        }
        .frame(height: activeHeight)
        .clipShape(Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(FMColor.hairlineHighlight(colorScheme), lineWidth: 0.5)
        }
    }

    private func updateValue(forProgress ratio: Double) {
        let next = FMSliderMath.value(forProgress: ratio, in: range, step: step)
        if next != value {
            let hitBoundary = (next == range.lowerBound || next == range.upperBound)
            if step != nil || hitBoundary {
                FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
            }
            value = next
        }
    }

    private func nudge(by direction: Double) {
        guard isEnabled else { return }
        let delta = step ?? (range.upperBound - range.lowerBound) * 0.05
        let next = min(max(value + direction * delta, range.lowerBound), range.upperBound)
        if next != value {
            value = next
            FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
        }
    }
}
