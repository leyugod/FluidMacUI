import SwiftUI

/// Crisp 0.5pt native macOS hairline divider adapting automatically to Dark/Light and High Contrast modes.
public struct FMHairlineDivider: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    private let axis: Axis
    private let inset: CGFloat

    public init(_ axis: Axis = .horizontal, inset: CGFloat = 0) {
        self.axis = axis
        self.inset = inset
    }

    public var body: some View {
        let thickness: CGFloat = contrast == .increased ? 1.0 : 0.5
        let color = FMColor.separator(colorScheme, highContrast: contrast == .increased)

        switch axis {
        case .horizontal:
            Rectangle()
                .fill(color)
                .frame(height: thickness)
                .padding(.horizontal, inset)
        case .vertical:
            Rectangle()
                .fill(color)
                .frame(width: thickness)
                .padding(.vertical, inset)
        }
    }
}

/// Editorial section header directly on the clean native canvas (matching App Store's
/// `What's New`, `Also Included In`, and `Preview` sections) without heavy box borders.
public struct FMSectionHeader<Trailing: View>: View {
    private let title: String
    private let subtitle: String?
    private let showTopDivider: Bool
    private let trailing: Trailing

    public init(
        _ title: String,
        subtitle: String? = nil,
        showTopDivider: Bool = false,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showTopDivider = showTopDivider
        self.trailing = trailing()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FMSpacing.sm) {
            if showTopDivider {
                FMHairlineDivider()
                    .padding(.bottom, 4)
            }

            HStack(alignment: .firstTextBaseline, spacing: FMSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.fmSubheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: FMSpacing.sm)

                trailing
            }
        }
    }
}

public extension FMSectionHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil, showTopDivider: Bool = false) {
        self.init(title, subtitle: subtitle, showTopDivider: showTopDivider) {
            EmptyView()
        }
    }
}

private struct FMSectionActionLink: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @FocusState private var isFocused: Bool

    let title: String
    let action: () -> Void

    var body: some View {
        let accent = FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 13.5, weight: .medium))
            .foregroundStyle(accent)
            .focused($isFocused)
            .focusEffectDisabled()
            .fmFocusRing(isFocused: isFocused, cornerRadius: 6)
    }
}

public extension FMSectionHeader where Trailing == AnyView {
    /// Convenience initializer with an Apple-style theme-adaptive accent link button on the trailing edge.
    init(
        _ title: String,
        subtitle: String? = nil,
        showTopDivider: Bool = false,
        actionTitle: String,
        action: @escaping () -> Void
    ) {
        self.init(title, subtitle: subtitle, showTopDivider: showTopDivider) {
            AnyView(FMSectionActionLink(title: actionTitle, action: action))
        }
    }
}
