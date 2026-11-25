import SwiftUI

/// Rounded iOS-style text input free of AppKit's harsh native rectangular box and blue focus frame,
/// featuring optional leading icon, animated clear button, and validation shake state.
public struct FMTextField: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding private var text: String
    private let placeholder: String
    private let icon: String?
    private let errorMessage: String?
    private let showsClearButton: Bool
    private let onSubmit: (() -> Void)?

    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    @State private var shakePhase: CGFloat = 0
    @State private var shakeTask: Task<Void, Never>?

    public init(
        _ placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        errorMessage: String? = nil,
        showsClearButton: Bool = true,
        onSubmit: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.errorMessage = errorMessage
        self.showsClearButton = showsClearButton
        self.onSubmit = onSubmit
    }

    private var hasError: Bool {
        if let errorMessage, !errorMessage.isEmpty { return true }
        return false
    }

    public var body: some View {
        let radius = FMCornerRadius.control * density.cornerScale
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let borderColor: Color = hasError
            ? FMColor.red
            : (isFocused
                ? FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
                : FMColor.hairlineHighlight(colorScheme))

        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: FMSpacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(isFocused ? borderColor : .secondary)
                }

                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.fmBody)
                    .focused($isFocused)
                    .focusEffectDisabled()
                    .onSubmit {
                        onSubmit?()
                    }

                if showsClearButton && !text.isEmpty && isEnabled {
                    Button {
                        text = ""
                        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .accessibilityLabel("Clear text")
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .padding(.horizontal, FMSpacing.sm)
            .frame(height: density.controlHeight)
            .background(
                isFocused
                    ? FMColor.elevatedSurface(colorScheme)
                    : (isHovered ? FMColor.controlHoverFill(colorScheme) : FMColor.controlFill(colorScheme)),
                in: shape
            )
            .overlay {
                shape.strokeBorder(
                    borderColor.opacity(isFocused || hasError ? 0.85 : 1.0),
                    lineWidth: isFocused || hasError ? 1.5 : 0.75
                )
            }
            .shadow(
                color: (isFocused || hasError) ? borderColor.opacity(0.18) : .clear,
                radius: 6
            )
            .offset(x: shakePhase)
            .opacity(isEnabled ? 1.0 : 0.45)
            .onHover { isHovered = $0 }
            .fmAnimation(.micro, value: isFocused)
            .fmAnimation(.micro, value: isHovered)
            .fmAnimation(.micro, value: text.isEmpty)
            .onChange(of: errorMessage) { _, newValue in
                if let newValue, !newValue.isEmpty {
                    triggerShake()
                }
            }

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.fmFootnote)
                    .foregroundStyle(FMColor.red)
                    .padding(.leading, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .fmAnimation(.micro, value: hasError)
        .onDisappear {
            shakeTask?.cancel()
            shakeTask = nil
        }
    }

    private func triggerShake() {
        FMHaptics.perform(.generic, enabled: theme.hapticsEnabled)
        guard !reduceMotion else { return }
        shakeTask?.cancel()
        let resetAnim = FMSpring.animation(.micro, reduceMotion: reduceMotion, speed: theme.animationSpeed)
        withAnimation(.linear(duration: 0.055)) { shakePhase = -6 }
        shakeTask = Task {
            try? await Task.sleep(for: .milliseconds(55))
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: 0.055)) { shakePhase = 6 }
            try? await Task.sleep(for: .milliseconds(55))
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: 0.055)) { shakePhase = -4 }
            try? await Task.sleep(for: .milliseconds(55))
            guard !Task.isCancelled else { return }
            withAnimation(resetAnim) { shakePhase = 0 }
        }
    }
}

/// Password / secret input field with animated visibility toggle, optional validation error state,
/// and focus preservation across reveal toggles.
public struct FMSecureField: View {
    private enum FieldFocus: Hashable {
        case masked
        case revealed
    }

    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.isEnabled) private var isEnabled

    @Binding private var text: String
    private let placeholder: String
    private let icon: String?
    private let errorMessage: String?
    private let onSubmit: (() -> Void)?

    @State private var isRevealed = false
    @State private var isHovered = false
    @FocusState private var focusedField: FieldFocus?

    private var isFocused: Bool { focusedField != nil }
    private var hasError: Bool {
        if let errorMessage, !errorMessage.isEmpty { return true }
        return false
    }

    public init(
        _ placeholder: String,
        text: Binding<String>,
        icon: String? = "lock.fill",
        errorMessage: String? = nil,
        onSubmit: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.errorMessage = errorMessage
        self.onSubmit = onSubmit
    }

    public var body: some View {
        let radius = FMCornerRadius.control * density.cornerScale
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let accent = FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
        let borderColor = hasError ? FMColor.red : (isFocused ? accent : FMColor.hairlineHighlight(colorScheme))

        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: FMSpacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(isFocused || hasError ? borderColor : .secondary)
                }

                Group {
                    if isRevealed {
                        TextField(placeholder, text: $text)
                            .focused($focusedField, equals: .revealed)
                    } else {
                        SecureField(placeholder, text: $text)
                            .focused($focusedField, equals: .masked)
                    }
                }
                .textFieldStyle(.plain)
                .font(.fmBody)
                .focusEffectDisabled()
                .onSubmit {
                    onSubmit?()
                }

                Button {
                    let wasFocused = isFocused
                    isRevealed.toggle()
                    FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                    if wasFocused {
                        focusedField = isRevealed ? .revealed : .masked
                    }
                } label: {
                    Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 13.5))
                        .foregroundStyle(.secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
            }
            .padding(.horizontal, FMSpacing.sm)
            .frame(height: density.controlHeight)
            .background(
                isFocused
                    ? FMColor.elevatedSurface(colorScheme)
                    : (isHovered ? FMColor.controlHoverFill(colorScheme) : FMColor.controlFill(colorScheme)),
                in: shape
            )
            .overlay {
                shape.strokeBorder(
                    borderColor.opacity(isFocused || hasError ? 0.85 : 1.0),
                    lineWidth: isFocused || hasError ? 1.5 : 0.75
                )
            }
            .shadow(color: (isFocused || hasError) ? borderColor.opacity(0.18) : .clear, radius: 6)
            .opacity(isEnabled ? 1.0 : 0.45)
            .onHover { isHovered = $0 }
            .fmAnimation(.micro, value: isFocused)
            .fmAnimation(.micro, value: isHovered)

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.fmFootnote)
                    .foregroundStyle(FMColor.red)
                    .padding(.leading, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .fmAnimation(.micro, value: hasError)
    }
}
