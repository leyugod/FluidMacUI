import SwiftUI

/// FluidMacUI semantic typography hierarchy featuring iOS-inspired rounded headers
/// and monospaced-digit numeric styles for jitter-free dynamic readouts.
public extension Font {
    /// Large navigation title (28pt bold rounded).
    static let fmLargeTitle: Font = .system(size: 28, weight: .bold, design: .rounded)

    /// Primary section / modal title (20pt bold rounded).
    static let fmTitle: Font = .system(size: 20, weight: .bold, design: .rounded)

    /// Secondary card title (16pt semibold rounded).
    static let fmTitle2: Font = .system(size: 16, weight: .semibold, design: .rounded)

    /// Emphasized row or control label (14pt semibold).
    static let fmHeadline: Font = .system(size: 14, weight: .semibold, design: .default)

    /// Standard body copy (13.5pt regular).
    static let fmBody: Font = .system(size: 13.5, weight: .regular, design: .default)

    /// Control button label (13.5pt medium rounded).
    static let fmControl: Font = .system(size: 13.5, weight: .medium, design: .rounded)

    /// Secondary descriptive text (12.5pt regular).
    static let fmSubheadline: Font = .system(size: 12.5, weight: .regular, design: .default)

    /// Footnote / group footer copy (11.5pt regular).
    static let fmFootnote: Font = .system(size: 11.5, weight: .regular, design: .default)

    /// Micro badge / uppercase header label (11pt semibold).
    static let fmCaption: Font = .system(size: 11, weight: .semibold, design: .rounded)

    /// Monospaced technical text (12pt medium monospaced).
    static let fmMono: Font = .system(size: 12, weight: .medium, design: .monospaced)

    /// Tabular numeric readout that prevents horizontal jitter during animated updates.
    static func fmNumeric(size: CGFloat = 14, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}
