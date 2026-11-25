import Foundation
import Testing
@testable import FluidMacUI

@Suite("Controls v1.0 Logic & Formatting Tests")
struct ControlsV1Tests {
    // MARK: - FMSpinner Metrics

    @Test("Spinner sizes scale monotonically for dimensions and stroke widths")
    func spinnerSizeMonotonicScaling() {
        #expect(FMSpinnerSize.small.dimension == 14)
        #expect(FMSpinnerSize.regular.dimension == 20)
        #expect(FMSpinnerSize.large.dimension == 32)
        #expect(FMSpinnerSize.small.strokeWidth < FMSpinnerSize.regular.strokeWidth)
        #expect(FMSpinnerSize.regular.strokeWidth < FMSpinnerSize.large.strokeWidth)
    }

    // MARK: - FMRadioGroupMath

    @Test("Radio group stepping clamps to endpoints and handles missing or empty lists")
    func radioGroupStepping() {
        let items = ["compact", "regular", "comfortable"]
        #expect(FMRadioGroupMath.steppedValue(from: "compact", in: items, delta: -1) == "compact")
        #expect(FMRadioGroupMath.steppedValue(from: "compact", in: items, delta: 1) == "regular")
        #expect(FMRadioGroupMath.steppedValue(from: "comfortable", in: items, delta: 1) == "comfortable")
        #expect(FMRadioGroupMath.steppedValue(from: "unknown", in: items, delta: 1) == "compact")
        #expect(FMRadioGroupMath.steppedValue(from: "unknown", in: items, delta: -1) == "comfortable")
        #expect(FMRadioGroupMath.steppedValue(from: "a", in: [String](), delta: 1) == nil)
    }

    // MARK: - FMComboBoxMath

    @Test("Combo box filtering ranks prefix matches ahead of substring matches case-insensitively")
    func comboBoxFilteringOrder() {
        let branches = ["release/swift", "main", "SwiftUI-v2", "feature/swift-6", "swift-tools"]
        let matches = FMComboBoxMath.filter(branches, query: "  SWIFT ") { $0 }

        #expect(matches == ["SwiftUI-v2", "swift-tools", "release/swift", "feature/swift-6"])
        #expect(FMComboBoxMath.filter(branches, query: "") { $0 } == branches)
        #expect(FMComboBoxMath.filter(branches, query: "nonexistent") { $0 }.isEmpty)
    }

    @Test("Combo box selection toggling handles single-select replacement and multi-select toggle")
    func comboBoxSelectionToggling() {
        let single = FMComboBoxMath.toggleSelection("b", in: ["a"], allowsMultiple: false)
        #expect(single == ["b"])

        let added = FMComboBoxMath.toggleSelection("b", in: ["a"], allowsMultiple: true)
        #expect(added == ["a", "b"])

        let removed = FMComboBoxMath.toggleSelection("a", in: added, allowsMultiple: true)
        #expect(removed == ["b"])

        #expect(FMComboBoxMath.clampedHighlightIndex(-3, count: 5) == 0)
        #expect(FMComboBoxMath.clampedHighlightIndex(99, count: 5) == 4)
        #expect(FMComboBoxMath.clampedHighlightIndex(2, count: 0) == 0)
    }

    // MARK: - FMFormattedFieldMath (NumberField & OTPField)

    @Test("Numeric sanitizer enforces single decimal point and leading negative sign rules")
    func numericSanitization() {
        #expect(FMFormattedFieldMath.sanitizeNumeric("-12.3.4abc", allowsDecimal: true, allowsNegative: true) == "-12.34")
        #expect(FMFormattedFieldMath.sanitizeNumeric("--42-9", allowsDecimal: false, allowsNegative: true) == "-429")
        #expect(FMFormattedFieldMath.sanitizeNumeric("-99.5", allowsDecimal: true, allowsNegative: false) == "99.5")
        #expect(FMFormattedFieldMath.sanitizeNumeric("12.34", allowsDecimal: false, allowsNegative: false) == "1234")
        #expect(FMFormattedFieldMath.sanitizeNumeric("12-34", allowsDecimal: false, allowsNegative: true) == "1234")
    }

    @Test("Numeric clamping, stepping, and formatting prevent floating-point drift and negative zero")
    func numericClampingAndFormatting() {
        #expect(FMFormattedFieldMath.clamp(-10, to: 0...100) == 0)
        #expect(FMFormattedFieldMath.clamp(250, to: 0...100) == 100)
        #expect(FMFormattedFieldMath.clamp(42, to: nil) == 42)

        let stepped = FMFormattedFieldMath.stepped(0.1, delta: 0.2, in: 0...1, precision: 2)
        #expect(stepped == 0.3)
        #expect(FMFormattedFieldMath.formatNumber(-0.0001, precision: 2) == "0.00")
        #expect(FMFormattedFieldMath.formatNumber(12.345, precision: 2) == "12.35")
    }

    @Test("OTP distribution filters invalid characters, uppercases alphanumeric input, and pads to exact length")
    func otpDistribution() {
        let numericSlots = FMFormattedFieldMath.distributeOTP("12-34 5678", length: 6, alphanumeric: false)
        #expect(numericSlots == ["1", "2", "3", "4", "5", "6"])

        let shortNumeric = FMFormattedFieldMath.distributeOTP("a9b2", length: 4, alphanumeric: false)
        #expect(shortNumeric == ["9", "2", "", ""])

        let alphaSlots = FMFormattedFieldMath.distributeOTP("ab-4z!", length: 6, alphanumeric: true)
        #expect(alphaSlots == ["A", "B", "4", "Z", "", ""])

        #expect(FMFormattedFieldMath.sanitizedOTPCode("  7 4-9 1 ", length: 6, alphanumeric: false) == "7491")
    }

    // MARK: - FMKeyShortcut & FMShortcutMath

    @Test("Keyboard shortcuts order modifiers canonically and validate primary modifiers or function keys")
    func shortcutFormattingAndValidation() throws {
        let combo = FMKeyShortcut(key: "k", modifiers: [.command, .shift, .control, .option])
        #expect(combo.key == "K")
        #expect(combo.keycapTokens == ["⌃", "⌥", "⇧", "⌘", "K"])
        #expect(combo.displayString == "⌃⌥⇧⌘K")
        #expect(combo.isValid)

        let shiftOnly = FMKeyShortcut(key: "a", modifiers: [.shift])
        #expect(!shiftOnly.isValid)

        let bareLetter = FMKeyShortcut(key: "a", modifiers: [])
        #expect(!bareLetter.isValid)

        let fnKey = FMKeyShortcut(key: "f5", modifiers: [])
        #expect(fnKey.key == "F5")
        #expect(fnKey.isValid)
        #expect(FMShortcutMath.isFunctionKey("F12"))
        #expect(!FMShortcutMath.isFunctionKey("F13"))
        #expect(!FMShortcutMath.isFunctionKey("F0"))

        let spaceCombo = FMKeyShortcut(key: " ", modifiers: [.command])
        #expect(spaceCombo.keycapTokens == ["⌘", "Space"])
        #expect(spaceCombo.isValid)

        // Codable round-trip
        let encoded = try JSONEncoder().encode(combo)
        let decoded = try JSONDecoder().decode(FMKeyShortcut.self, from: encoded)
        #expect(decoded == combo)
    }

    @Test("Shortcut keyCode mapping resolves special keys and ignores Escape and bare modifiers")
    func shortcutKeyCodeMapping() {
        #expect(FMShortcutMath.keyLabel(for: 36, charactersIgnoringModifiers: "\r") == "↩")
        #expect(FMShortcutMath.keyLabel(for: 49, charactersIgnoringModifiers: " ") == "Space")
        #expect(FMShortcutMath.keyLabel(for: 122, charactersIgnoringModifiers: nil) == "F1")
        #expect(FMShortcutMath.keyLabel(for: 111, charactersIgnoringModifiers: nil) == "F12")
        #expect(FMShortcutMath.keyLabel(for: 53, charactersIgnoringModifiers: nil) == nil) // Escape
        #expect(FMShortcutMath.keyLabel(for: 55, charactersIgnoringModifiers: nil) == nil) // Command modifier
        #expect(FMShortcutMath.keyLabel(for: 40, charactersIgnoringModifiers: "k") == "K")
    }
}
