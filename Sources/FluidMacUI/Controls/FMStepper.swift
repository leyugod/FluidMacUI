import SwiftUI

/// Pure stepping & clamping logic for `FMStepper` (tested independently).
public enum FMStepperMath {
    public static func stepped(
        from value: Int,
        delta: Int,
        in range: ClosedRange<Int>
    ) -> Int {
        min(max(value + delta, range.lowerBound), range.upperBound)
    }
}

/// Capsule dual-action stepper with independent left/right press squish,
/// continuous accelerated long-press repeat, and monospaced rolling numeric readout.
public struct FMStepper: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    @Binding private var value: Int
    private let range: ClosedRange<Int>
    private let step: Int
    private let showsValue: Bool
    private let suffix: String

    @State private var isDecrementPressed = false
    @State private var isIncrementPressed = false
    @State private var repeatTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    public init(
        value: Binding<Int>,
        in range: ClosedRange<Int> = 0...100,
        step: Int = 1,
        showsValue: Bool = true,
        suffix: String = ""
    ) {
        self._value = value
        self.range = range
        self.step = max(1, step)
        self.showsValue = showsValue
        self.suffix = suffix
    }

    public var body: some View {
        let canDecrement = isEnabled && value > range.lowerBound
        let canIncrement = isEnabled && value < range.upperBound

        HStack(spacing: 0) {
            stepperHalf(
                systemName: "minus",
                enabled: canDecrement,
                isPressed: $isDecrementPressed,
                delta: -step
            )

            if showsValue {
                Divider()
                    .frame(height: density.controlHeight * 0.45)

                Text("\(value)\(suffix)")
                    .font(.fmNumeric(size: 13, weight: .semibold))
                    .contentTransition(.numericText(value: Double(value)))
                    .frame(minWidth: 42)
                    .padding(.horizontal, FMSpacing.xs)
                    .fmAnimation(.micro, value: value)

                Divider()
                    .frame(height: density.controlHeight * 0.45)
            } else {
                Divider()
                    .frame(height: density.controlHeight * 0.45)
            }

            stepperHalf(
                systemName: "plus",
                enabled: canIncrement,
                isPressed: $isIncrementPressed,
                delta: step
            )
        }
        .frame(height: density.controlHeight)
        .background(FMColor.controlFill(colorScheme), in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(FMColor.hairlineHighlight(colorScheme), lineWidth: 0.5)
        }
        .opacity(isEnabled ? 1.0 : 0.45)
        .focusable(isEnabled)
        .focused($isFocused)
        .focusEffectDisabled()
        .fmFocusRing(isFocused: isFocused, isCapsule: true)
        .onKeyPress(.upArrow) {
            applyStep(step)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            applyStep(step)
            return .handled
        }
        .onKeyPress(.downArrow) {
            applyStep(-step)
            return .handled
        }
        .onKeyPress(.leftArrow) {
            applyStep(-step)
            return .handled
        }
        .accessibilityElement(children: .ignore)
        .accessibilityValue("\(value)\(suffix)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: applyStep(step)
            case .decrement: applyStep(-step)
            @unknown default: break
            }
        }
        .onDisappear {
            repeatTask?.cancel()
            repeatTask = nil
        }
    }

    @ViewBuilder
    private func stepperHalf(
        systemName: String,
        enabled: Bool,
        isPressed: Binding<Bool>,
        delta: Int
    ) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.35))
            .frame(width: density.controlHeight + 2, height: density.controlHeight)
            .scaleEffect(isPressed.wrappedValue ? 0.84 : 1.0)
            .background(
                isPressed.wrappedValue ? FMColor.controlHoverFill(colorScheme) : .clear,
                in: Capsule(style: .continuous)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard enabled, !isPressed.wrappedValue else { return }
                        isPressed.wrappedValue = true
                        applyStep(delta)
                        startRepeating(delta)
                    }
                    .onEnded { _ in
                        isPressed.wrappedValue = false
                        repeatTask?.cancel()
                        repeatTask = nil
                    }
            )
            .fmAnimation(.micro, value: isPressed.wrappedValue)
    }

    @discardableResult
    private func applyStep(_ delta: Int) -> Bool {
        let next = FMStepperMath.stepped(from: value, delta: delta, in: range)
        guard next != value else { return false }
        value = next
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
        return true
    }

    private func startRepeating(_ delta: Int) {
        repeatTask?.cancel()
        repeatTask = Task {
            try? await Task.sleep(for: .milliseconds(380))
            var intervalMs = 130
            while !Task.isCancelled {
                if !applyStep(delta) {
                    break
                }
                try? await Task.sleep(for: .milliseconds(intervalMs))
                intervalMs = max(45, intervalMs - 10)
            }
        }
    }
}
