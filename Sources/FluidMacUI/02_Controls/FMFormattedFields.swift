import SwiftUI

// MARK: - Formatted Field Math Helpers

/// Pure sanitization, clamping, stepping, and OTP distribution helpers for `FMNumberField` and `FMOTPField`.
public enum FMFormattedFieldMath {
    /// Sanitizes raw user text into a valid numeric string with optional single leading `-` and single `.`.
    public static func sanitizeNumeric(
        _ raw: String,
        allowsDecimal: Bool,
        allowsNegative: Bool
    ) -> String {
        var result = ""
        var hasDecimal = false
        var hasDigitsOrSign = false

        for ch in raw {
            if ch.isASCII && ch.isNumber {
                result.append(ch)
                hasDigitsOrSign = true
            } else if ch == "-", allowsNegative, !hasDigitsOrSign {
                result.append(ch)
                hasDigitsOrSign = true
            } else if ch == ".", allowsDecimal, !hasDecimal {
                result.append(ch)
                hasDecimal = true
                hasDigitsOrSign = true
            }
        }
        return result
    }

    /// Clamps `value` to `range` when `range` is provided.
    public static func clamp(_ value: Double, to range: ClosedRange<Double>?) -> Double {
        guard let range else { return value }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    /// Formats `value` using fixed decimal `precision`, normalizing `-0` to `0`.
    public static func formatNumber(_ value: Double, precision: Int) -> String {
        let safePrecision = min(max(precision, 0), 10)
        let factor = pow(10.0, Double(safePrecision))
        var rounded = (value * factor).rounded() / factor
        if rounded == 0 { rounded = 0 } // avoid "-0"
        return String(format: "%.\(safePrecision)f", rounded)
    }

    /// Steps `value` by `delta`, rounds to `precision` decimal places to eliminate floating-point drift, and clamps to `range`.
    public static func stepped(
        _ value: Double,
        delta: Double,
        in range: ClosedRange<Double>?,
        precision: Int
    ) -> Double {
        let safePrecision = min(max(precision, 0), 10)
        let factor = pow(10.0, Double(safePrecision))
        let raw = value + delta
        let rounded = (raw * factor).rounded() / factor
        return clamp(rounded == 0 ? 0 : rounded, to: range)
    }

    /// Filters and distributes pasted or typed OTP text into an exact `length`-element array of single-character slots.
    public static func distributeOTP(
        _ pasted: String,
        length: Int,
        alphanumeric: Bool
    ) -> [String] {
        let safeLength = max(1, length)
        let filtered: [Character] = pasted.compactMap { ch in
            guard ch.isASCII else { return nil }
            if ch.isNumber { return ch }
            if alphanumeric && ch.isLetter { return Character(ch.uppercased()) }
            return nil
        }

        var slots = Array(repeating: "", count: safeLength)
        for index in 0..<min(safeLength, filtered.count) {
            slots[index] = String(filtered[index])
        }
        return slots
    }

    /// Produces a clean, length-capped OTP code string from raw input.
    public static func sanitizedOTPCode(
        _ raw: String,
        length: Int,
        alphanumeric: Bool
    ) -> String {
        distributeOTP(raw, length: length, alphanumeric: alphanumeric).joined()
    }
}

// MARK: - FMNumberField

/// Formatted numeric/currency/port input field with monospaced digits, optional prefix/suffix,
/// live sanitization, range clamping, and `↑`/`↓` keyboard stepping (with `Shift` 10× multiplier).
public struct FMNumberField: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.isEnabled) private var isEnabled

    @Binding private var value: Double
    private let placeholder: String
    private let range: ClosedRange<Double>?
    private let step: Double
    private let precision: Int
    private let prefix: String?
    private let suffix: String?
    private let showsStepperArrows: Bool

    @State private var text: String
    @State private var isHovered = false
    @State private var hoveredArrow: String?
    @FocusState private var isFocused: Bool

    /// Creates a formatted numeric field.
    public init(
        _ placeholder: String = "0",
        value: Binding<Double>,
        range: ClosedRange<Double>? = nil,
        step: Double = 1,
        precision: Int = 0,
        prefix: String? = nil,
        suffix: String? = nil,
        showsStepperArrows: Bool = true
    ) {
        self.placeholder = placeholder
        self._value = value
        self.range = range
        self.step = step
        self.precision = max(0, precision)
        self.prefix = prefix
        self.suffix = suffix
        self.showsStepperArrows = showsStepperArrows
        let initial = FMFormattedFieldMath.clamp(value.wrappedValue, to: range)
        self._text = State(initialValue: FMFormattedFieldMath.formatNumber(initial, precision: max(0, precision)))
    }

    private var accent: Color {
        FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
    }

    private var allowsDecimal: Bool {
        precision > 0
    }

    private var allowsNegative: Bool {
        guard let range else { return true }
        return range.lowerBound < 0
    }

    private var canIncrement: Bool {
        guard isEnabled else { return false }
        guard let range else { return true }
        return value < range.upperBound
    }

    private var canDecrement: Bool {
        guard isEnabled else { return false }
        guard let range else { return true }
        return value > range.lowerBound
    }

    public var body: some View {
        let radius = FMCornerRadius.control * density.cornerScale
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let backgroundColor: Color = {
            if reduceTransparency {
                return FMColor.elevatedOpaqueSurface(colorScheme)
            }
            if isFocused {
                return FMColor.elevatedSurface(colorScheme)
            }
            return isHovered ? FMColor.controlHoverFill(colorScheme) : FMColor.controlFill(colorScheme)
        }()

        HStack(spacing: FMSpacing.xxs) {
            if let prefix, !prefix.isEmpty {
                Text(prefix)
                    .font(.fmNumeric(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.fmNumeric(size: 13.5, weight: .medium))
                .foregroundStyle(.primary)
                .focused($isFocused)
                .focusEffectDisabled()
                .onChange(of: text) { _, newValue in
                    guard isFocused else { return }
                    let cleaned = FMFormattedFieldMath.sanitizeNumeric(
                        newValue,
                        allowsDecimal: allowsDecimal,
                        allowsNegative: allowsNegative
                    )
                    if cleaned != newValue {
                        text = cleaned
                    }
                    if let parsed = Double(cleaned) {
                        value = FMFormattedFieldMath.clamp(parsed, to: range)
                    }
                }
                .onSubmit {
                    commitText()
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        commitText()
                    }
                }
                .onChange(of: value) { _, newValue in
                    if !isFocused {
                        text = FMFormattedFieldMath.formatNumber(newValue, precision: precision)
                    }
                }

            if let suffix, !suffix.isEmpty {
                Text(suffix)
                    .font(.fmNumeric(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.trailing, showsStepperArrows ? 2 : 0)
            }

            if showsStepperArrows {
                stepperArrows
            }
        }
        .padding(.leading, FMSpacing.sm)
        .padding(.trailing, showsStepperArrows ? 4 : FMSpacing.sm)
        .frame(height: density.controlHeight)
        .background(backgroundColor, in: shape)
        .overlay {
            shape.strokeBorder(
                isFocused ? accent.opacity(0.85) : FMColor.hairlineHighlight(colorScheme),
                lineWidth: isFocused ? 1.5 : 0.75
            )
        }
        .fmFocusRing(isFocused: isFocused, cornerRadius: FMCornerRadius.control)
        .opacity(isEnabled ? 1.0 : 0.45)
        .onHover { isHovered = $0 }
        .onKeyPress(keys: [.upArrow, .downArrow]) { press in
            let multiplier: Double = press.modifiers.contains(.shift) ? 10 : 1
            let sign: Double = press.key == .upArrow ? 1 : -1
            applyStep(delta: sign * step * multiplier)
            return .handled
        }
        .fmAnimation(.micro, value: isFocused)
        .fmAnimation(.micro, value: isHovered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(placeholder)
        .accessibilityValue(formattedAccessibilityValue)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                applyStep(delta: step)
            case .decrement:
                applyStep(delta: -step)
            @unknown default:
                break
            }
        }
    }

    private var stepperArrows: some View {
        let halfHeight = max(12, (density.controlHeight - 8) / 2)
        return VStack(spacing: 1) {
            Button {
                applyStep(delta: step)
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(canIncrement ? .primary : .tertiary)
                    .frame(width: 22, height: halfHeight)
                    .background(
                        hoveredArrow == "up" && canIncrement ? FMColor.controlHoverFill(colorScheme) : .clear,
                        in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .disabled(!canIncrement)
            .accessibilityLabel("Increase value")
            .onHover { hoveredArrow = $0 ? "up" : (hoveredArrow == "up" ? nil : hoveredArrow) }

            Button {
                applyStep(delta: -step)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(canDecrement ? .primary : .tertiary)
                    .frame(width: 22, height: halfHeight)
                    .background(
                        hoveredArrow == "down" && canDecrement ? FMColor.controlHoverFill(colorScheme) : .clear,
                        in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .disabled(!canDecrement)
            .accessibilityLabel("Decrease value")
            .onHover { hoveredArrow = $0 ? "down" : (hoveredArrow == "down" ? nil : hoveredArrow) }
        }
    }

    private func applyStep(delta: Double) {
        guard isEnabled else { return }
        let next = FMFormattedFieldMath.stepped(value, delta: delta, in: range, precision: precision)
        if next != value {
            value = next
            text = FMFormattedFieldMath.formatNumber(next, precision: precision)
            FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
        }
    }

    private func commitText() {
        let cleaned = FMFormattedFieldMath.sanitizeNumeric(
            text,
            allowsDecimal: allowsDecimal,
            allowsNegative: allowsNegative
        )
        let parsed = Double(cleaned) ?? value
        let clamped = FMFormattedFieldMath.clamp(parsed, to: range)
        value = clamped
        text = FMFormattedFieldMath.formatNumber(clamped, precision: precision)
    }

    private var formattedAccessibilityValue: String {
        let num = FMFormattedFieldMath.formatNumber(value, precision: precision)
        return "\(prefix ?? "")\(num)\(suffix ?? "")"
    }
}

// MARK: - FMOTPField

/// Segmented one-time verification code / PIN input with automatic slot advancement,
/// full-code `⌘V` paste distribution, backspace retreat, and Reduce-Motion-safe error shake.
public struct FMOTPField: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.isEnabled) private var isEnabled

    @Binding private var code: String
    private let length: Int
    private let alphanumeric: Bool
    private let isError: Bool
    private let onComplete: ((String) -> Void)?

    @FocusState private var isFocused: Bool
    @State private var shakeOffset: CGFloat = 0
    @State private var lastCompletedCode: String?

    /// Creates a segmented OTP / verification code input.
    public init(
        code: Binding<String>,
        length: Int = 6,
        alphanumeric: Bool = false,
        isError: Bool = false,
        onComplete: ((String) -> Void)? = nil
    ) {
        self._code = code
        self.length = max(1, min(length, 12))
        self.alphanumeric = alphanumeric
        self.isError = isError
        self.onComplete = onComplete
    }

    private var accent: Color {
        FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
    }

    private var slots: [String] {
        FMFormattedFieldMath.distributeOTP(code, length: length, alphanumeric: alphanumeric)
    }

    private var activeSlotIndex: Int {
        min(FMFormattedFieldMath.sanitizedOTPCode(code, length: length, alphanumeric: alphanumeric).count, length - 1)
    }

    private var boxWidth: CGFloat {
        switch density {
        case .compact: 34
        case .regular: 40
        case .comfortable: 46
        }
    }

    private var boxHeight: CGFloat {
        switch density {
        case .compact: 40
        case .regular: 46
        case .comfortable: 52
        }
    }

    public var body: some View {
        let currentSlots = slots

        ZStack {
            // Underlying native text input captures typing, backspace, and ⌘V paste seamlessly
            TextField("", text: Binding(
                get: { code },
                set: { handleInput($0) }
            ))
            .textFieldStyle(.plain)
            .focused($isFocused)
            .focusEffectDisabled()
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .allowsHitTesting(false)
            .accessibilityLabel("Verification code")
            .accessibilityValue(code.isEmpty ? "Empty" : code.map(String.init).joined(separator: " "))

            HStack(spacing: FMSpacing.xs) {
                ForEach(0..<length, id: \.self) { index in
                    otpCell(
                        character: currentSlots[index],
                        isActive: isFocused && index == activeSlotIndex
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard isEnabled else { return }
                isFocused = true
            }
        }
        .offset(x: shakeOffset)
        .opacity(isEnabled ? 1.0 : 0.45)
        .fmAnimation(.micro, value: isFocused)
        .fmAnimation(.micro, value: isError)
        .fmAnimation(.micro, value: code)
        .onChange(of: isError) { _, nowError in
            if nowError {
                triggerErrorFeedback()
            }
        }
    }

    private func otpCell(character: String, isActive: Bool) -> some View {
        let radius = FMCornerRadius.control * density.cornerScale
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let isFilled = !character.isEmpty

        let borderColor: Color = {
            if isError { return FMColor.red }
            if isActive { return accent }
            if isFilled { return FMColor.separator(colorScheme, highContrast: true) }
            return FMColor.hairlineHighlight(colorScheme)
        }()

        let fillColor: Color = {
            if reduceTransparency {
                return FMColor.elevatedOpaqueSurface(colorScheme)
            }
            return isActive ? FMColor.elevatedSurface(colorScheme) : FMColor.controlFill(colorScheme)
        }()

        return ZStack {
            shape.fill(fillColor)

            if isFilled {
                Text(character)
                    .font(.fmNumeric(size: density == .compact ? 17 : 20, weight: .bold))
                    .foregroundStyle(.primary)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.72).combined(with: .opacity))
            } else if isActive {
                Capsule(style: .continuous)
                    .fill(accent)
                    .frame(width: 2, height: boxHeight * 0.44)
            }
        }
        .frame(width: boxWidth, height: boxHeight)
        .overlay {
            shape.strokeBorder(
                borderColor.opacity(isActive || isError ? 0.9 : 1.0),
                lineWidth: isActive || isError ? 1.6 : 0.75
            )
        }
        .shadow(
            color: (isActive || isError) ? borderColor.opacity(0.22) : .clear,
            radius: 6
        )
    }

    private func handleInput(_ raw: String) {
        let sanitized = FMFormattedFieldMath.sanitizedOTPCode(
            raw,
            length: length,
            alphanumeric: alphanumeric
        )
        let grew = sanitized.count > code.count
        code = sanitized
        if grew {
            FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
        }
        if sanitized.count == length {
            if lastCompletedCode != sanitized {
                lastCompletedCode = sanitized
                onComplete?(sanitized)
            }
        } else {
            lastCompletedCode = nil
        }
    }

    private func triggerErrorFeedback() {
        FMHaptics.perform(.generic, enabled: theme.hapticsEnabled)
        guard !reduceMotion else { return }
        let speed = max(0.1, theme.animationSpeed)
        let stepMs = Int((55.0 / speed).rounded())
        withAnimation(.linear(duration: 0.055 / speed)) { shakeOffset = -6 }
        Task {
            try? await Task.sleep(for: .milliseconds(stepMs))
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: 0.055 / speed)) { shakeOffset = 6 }
            try? await Task.sleep(for: .milliseconds(stepMs))
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: 0.055 / speed)) { shakeOffset = -4 }
            try? await Task.sleep(for: .milliseconds(stepMs))
            guard !Task.isCancelled else { return }
            withAnimation(FMSpring.animation(.micro, reduceMotion: reduceMotion, speed: speed)) {
                shakeOffset = 0
            }
        }
    }
}
