import SwiftUI
import AppKit

// MARK: - Shortcut Models & Pure Formatting Math

/// Keyboard modifier flags for `FMKeyShortcut`, formatted in canonical Apple symbol order (`⌃ ⌥ ⇧ ⌘`).
public struct FMKeyModifiers: OptionSet, Hashable, Sendable, Codable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let control = FMKeyModifiers(rawValue: 1 << 0)
    public static let option  = FMKeyModifiers(rawValue: 1 << 1)
    public static let shift   = FMKeyModifiers(rawValue: 1 << 2)
    public static let command = FMKeyModifiers(rawValue: 1 << 3)

    /// Converts AppKit `NSEvent.ModifierFlags` into `FMKeyModifiers`.
    public init(nsEventFlags flags: NSEvent.ModifierFlags) {
        var result: FMKeyModifiers = []
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.command) { result.insert(.command) }
        self = result
    }

    /// Canonical Apple glyph sequence: `⌃`, `⌥`, `⇧`, `⌘`.
    public var symbols: [String] {
        var result: [String] = []
        if contains(.control) { result.append("⌃") }
        if contains(.option)  { result.append("⌥") }
        if contains(.shift)   { result.append("⇧") }
        if contains(.command) { result.append("⌘") }
        return result
    }

    /// Whether at least one primary shortcut modifier (`⌘`, `⌃`, or `⌥`) is active.
    public var hasPrimaryModifier: Bool {
        contains(.command) || contains(.control) || contains(.option)
    }
}

/// Pure key normalization and validation helpers for `FMKeyShortcut` and `FMShortcutRecorder`.
public enum FMShortcutMath {
    /// Normalizes a raw key string into a clean Apple display label (e.g. `"k"` -> `"K"`, `" "` -> `"Space"`).
    public static func normalizeKey(_ raw: String) -> String {
        switch raw {
        case " ":
            return "Space"
        case "\r", "\n":
            return "↩"
        case "\t":
            return "⇥"
        default:
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return "" }
            let upper = trimmed.uppercased()
            if isFunctionKey(upper) {
                return upper
            }
            if trimmed.count == 1 {
                return upper
            }
            return trimmed
        }
    }

    /// Returns `true` for standard macOS function keys `F1` through `F12`.
    public static func isFunctionKey(_ key: String) -> Bool {
        let upper = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard upper.hasPrefix("F"), let num = Int(upper.dropFirst()) else {
            return false
        }
        return (1...12).contains(num)
    }

    /// Translates an AppKit virtual key code and `charactersIgnoringModifiers` into a normalized key label.
    public static func keyLabel(for keyCode: UInt16, charactersIgnoringModifiers: String?) -> String? {
        switch keyCode {
        case 36, 76: return "↩"
        case 48: return "⇥"
        case 49: return "Space"
        case 51: return "⌫"
        case 117: return "⌦"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 122: return "F1"
        case 120: return "F2"
        case 99:  return "F3"
        case 118: return "F4"
        case 96:  return "F5"
        case 97:  return "F6"
        case 98:  return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        case 53:  return nil // Escape cancels recording
        // Bare modifier keyCodes
        case 54, 55, 56, 57, 58, 59, 60, 61, 62, 63:
            return nil
        default:
            guard let chars = charactersIgnoringModifiers, !chars.isEmpty else {
                return nil
            }
            let normalized = normalizeKey(chars)
            return normalized.isEmpty ? nil : normalized
        }
    }
}

/// Serializable macOS keyboard shortcut descriptor rendered with `FMKeycap`.
public struct FMKeyShortcut: Hashable, Sendable, Codable {
    public var key: String
    public var modifiers: FMKeyModifiers

    /// Creates a keyboard shortcut with normalized key text and modifier flags.
    public init(key: String, modifiers: FMKeyModifiers) {
        self.key = FMShortcutMath.normalizeKey(key)
        self.modifiers = modifiers
    }

    /// Keycap tokens in canonical Apple order (`⌃`, `⌥`, `⇧`, `⌘`, `<Key>`).
    public var keycapTokens: [String] {
        guard !key.isEmpty else { return modifiers.symbols }
        return modifiers.symbols + [key]
    }

    /// Concatenated human-readable string (e.g. `"⌃⌥⌘K"`).
    public var displayString: String {
        keycapTokens.joined()
    }

    /// Returns `true` when the shortcut has a non-empty key and either `⌘`/`⌃`/`⌥` or a function key (`F1`–`F12`).
    public var isValid: Bool {
        guard !key.isEmpty else { return false }
        return modifiers.hasPrimaryModifier || FMShortcutMath.isFunctionKey(key)
    }
}

// MARK: - FMShortcutRecorder

/// Native macOS keyboard shortcut recorder with click-to-record capture, pulsing accent state,
/// `FMKeycap` display, `Esc` cancel, `⌫` clear, and optional conflict validation.
public struct FMShortcutRecorder: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.isEnabled) private var isEnabled

    @Binding private var shortcut: FMKeyShortcut?
    private let placeholder: String
    private let validator: ((FMKeyShortcut) -> String?)?

    @State private var isRecording = false
    @State private var isHovered = false
    @State private var validationMessage: String?
    @FocusState private var isFocused: Bool

    /// Creates a keyboard shortcut recorder.
    /// - Parameters:
    ///   - shortcut: Binding to the recorded shortcut (or `nil` when unset).
    ///   - placeholder: Prompt shown when no shortcut is recorded.
    ///   - validator: Optional closure returning an error/conflict description to reject a shortcut.
    public init(
        shortcut: Binding<FMKeyShortcut?>,
        placeholder: String = "Record Shortcut",
        validator: ((FMKeyShortcut) -> String?)? = nil
    ) {
        self._shortcut = shortcut
        self.placeholder = placeholder
        self.validator = validator
    }

    private var accent: Color {
        FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
    }

    public var body: some View {
        let radius = FMCornerRadius.control * density.cornerScale
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let hasError = validationMessage != nil

        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: FMSpacing.xs) {
                Button {
                    toggleRecording()
                } label: {
                    HStack(spacing: FMSpacing.xs) {
                        if isRecording {
                            Circle()
                                .fill(accent)
                                .frame(width: 7, height: 7)

                            Text("Press shortcut...")
                                .font(.fmControl)
                                .foregroundStyle(accent)
                                .lineLimit(1)
                        } else if let shortcut {
                            FMKeycap(keys: shortcut.keycapTokens)
                        } else {
                            Image(systemName: "keyboard")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(.secondary)

                            Text(placeholder)
                                .font(.fmControl)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: FMSpacing.xs)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .accessibilityLabel(accessibilityTitle)
                .accessibilityHint(isRecording ? "Press a key combination, Escape to cancel, or Delete to clear." : "Activate to record a keyboard shortcut.")

                if isRecording {
                    Button {
                        stopRecording()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13.5))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .accessibilityLabel("Cancel recording")
                } else if shortcut != nil && isEnabled {
                    Button {
                        shortcut = nil
                        validationMessage = nil
                        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13.5))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .accessibilityLabel("Clear shortcut")
                }
            }
            .padding(.horizontal, FMSpacing.sm)
            .frame(minWidth: 180, minHeight: density.controlHeight)
            .background(surfaceFill, in: shape)
            .overlay {
                shape.strokeBorder(
                    hasError
                        ? FMColor.red.opacity(0.9)
                        : (isRecording ? accent.opacity(0.9) : FMColor.hairlineHighlight(colorScheme)),
                    lineWidth: (isRecording || hasError) ? 1.5 : 0.75
                )
            }
            .shadow(
                color: isRecording ? accent.opacity(0.24) : (hasError ? FMColor.red.opacity(0.18) : .clear),
                radius: 7
            )
            .background {
                FMShortcutMonitorBridge(
                    isRecording: isRecording,
                    onKeyDown: handleRecordedEvent
                )
                .frame(width: 0, height: 0)
            }
            .opacity(isEnabled ? 1.0 : 0.45)
            .focusable(isEnabled)
            .focused($isFocused)
            .focusEffectDisabled()
            .fmFocusRing(isFocused: isFocused, cornerRadius: FMCornerRadius.control)
            .onKeyPress(.return) {
                if !isRecording {
                    toggleRecording()
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.space) {
                if !isRecording {
                    toggleRecording()
                    return .handled
                }
                return .ignored
            }
            .onHover { isHovered = $0 }
            .onChange(of: activeState) { _, state in
                if state == .inactive && isRecording {
                    stopRecording()
                }
            }
            .onDisappear {
                isRecording = false
            }
            .fmAnimation(.micro, value: isRecording)
            .fmAnimation(.micro, value: isHovered)

            if let validationMessage, !validationMessage.isEmpty {
                Text(validationMessage)
                    .font(.fmFootnote)
                    .foregroundStyle(FMColor.red)
                    .padding(.leading, 4)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .fmAnimation(.micro, value: validationMessage)
    }

    private var surfaceFill: Color {
        if reduceTransparency {
            return FMColor.elevatedOpaqueSurface(colorScheme)
        }
        if isRecording {
            return accent.opacity(colorScheme == .dark ? 0.14 : 0.08)
        }
        return isHovered ? FMColor.controlHoverFill(colorScheme) : FMColor.controlFill(colorScheme)
    }

    private var accessibilityTitle: String {
        if isRecording {
            return "Recording shortcut"
        }
        if let shortcut {
            return "Shortcut \(shortcut.displayString)"
        }
        return placeholder
    }

    private func toggleRecording() {
        guard isEnabled else { return }
        validationMessage = nil
        isRecording.toggle()
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
    }

    private func stopRecording() {
        isRecording = false
        validationMessage = nil
    }

    private func handleRecordedEvent(_ event: NSEvent) -> Bool {
        guard isRecording else { return false }

        let modifiers = FMKeyModifiers(nsEventFlags: event.modifierFlags)

        // Escape cancels recording
        if event.keyCode == 53 && modifiers.isEmpty {
            stopRecording()
            FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
            return true
        }

        // Bare Backspace / Forward Delete clears the existing shortcut
        if (event.keyCode == 51 || event.keyCode == 117) && modifiers.isEmpty {
            shortcut = nil
            stopRecording()
            FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
            return true
        }

        guard let key = FMShortcutMath.keyLabel(
            for: event.keyCode,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers
        ) else {
            return false
        }

        let candidate = FMKeyShortcut(key: key, modifiers: modifiers)
        guard candidate.isValid else {
            validationMessage = "Include ⌘, ⌃, ⌥, or use F1–F12."
            FMHaptics.perform(.generic, enabled: theme.hapticsEnabled)
            return true
        }

        if let conflict = validator?(candidate), !conflict.isEmpty {
            validationMessage = conflict
            FMHaptics.perform(.generic, enabled: theme.hapticsEnabled)
            return true
        }

        shortcut = candidate
        validationMessage = nil
        isRecording = false
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
        return true
    }
}

// MARK: - Leak-Proof Local KeyDown Monitor Bridge

private struct FMShortcutMonitorBridge: NSViewRepresentable {
    let isRecording: Bool
    let onKeyDown: (NSEvent) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(onKeyDown: onKeyDown)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.update(isRecording: isRecording, onKeyDown: onKeyDown)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(isRecording: isRecording, onKeyDown: onKeyDown)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stopMonitoring()
    }

    final class Coordinator {
        private var monitor: Any?
        private var onKeyDown: (NSEvent) -> Bool

        init(onKeyDown: @escaping (NSEvent) -> Bool) {
            self.onKeyDown = onKeyDown
        }

        func update(isRecording: Bool, onKeyDown: @escaping (NSEvent) -> Bool) {
            self.onKeyDown = onKeyDown
            if isRecording {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }

        private func startMonitoring() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return self.onKeyDown(event) ? nil : event
            }
        }

        func stopMonitoring() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        isolated deinit {
            stopMonitoring()
        }
    }
}
