import SwiftUI

/// Visual presentation style for `FMRadioGroup`.
public enum FMRadioGroupStyle: Sendable, Hashable {
    /// Compact inline circular radio indicator with title and optional subtitle.
    case inline
    /// Selectable continuous-curvature option cards with accent border and tint highlight.
    case card
}

/// Option descriptor for `FMRadioGroup`.
public struct FMRadioOption<Value: Hashable>: Identifiable {
    public let id: Value
    public let title: String
    public let subtitle: String?
    public let icon: String?

    /// Creates a radio option item.
    public init(
        id: Value,
        title: String,
        subtitle: String? = nil,
        icon: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
    }
}

/// Pure selection stepping helpers for `FMRadioGroup`.
public enum FMRadioGroupMath {
    /// Steps from `current` by `delta` within `values`, clamping cleanly to array bounds.
    public static func steppedValue<Value: Hashable>(
        from current: Value,
        in values: [Value],
        delta: Int
    ) -> Value? {
        guard !values.isEmpty else { return nil }
        guard let index = values.firstIndex(of: current) else {
            return delta >= 0 ? values.first : values.last
        }
        let target = min(max(index + delta, 0), values.count - 1)
        return values[target]
    }
}

/// Exclusive single-choice radio control supporting compact `.inline` rows and rich `.card` tiles,
/// spring concentric indicator animation, arrow-key navigation, and full VoiceOver traits.
public struct FMRadioGroup<Value: Hashable>: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.isEnabled) private var isEnabled

    @Binding private var selection: Value
    private let options: [FMRadioOption<Value>]
    private let style: FMRadioGroupStyle
    private let axis: Axis

    @State private var hoveredValue: Value?
    @FocusState private var isFocused: Bool

    /// Creates a radio group control.
    /// - Parameters:
    ///   - selection: Binding to the selected option value.
    ///   - options: Ordered list of selectable options.
    ///   - style: `.inline` or `.card` visual presentation.
    ///   - axis: `.vertical` stack or `.horizontal` row layout.
    public init(
        selection: Binding<Value>,
        options: [FMRadioOption<Value>],
        style: FMRadioGroupStyle = .inline,
        axis: Axis = .vertical
    ) {
        self._selection = selection
        self.options = options
        self.style = style
        self.axis = axis
    }

    private var accent: Color {
        FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
    }

    public var body: some View {
        let spacing: CGFloat = style == .card ? FMSpacing.xs : (axis == .horizontal ? FMSpacing.md : FMSpacing.xxs)

        Group {
            if axis == .vertical {
                VStack(alignment: .leading, spacing: spacing) {
                    optionViews
                }
            } else {
                HStack(alignment: .top, spacing: spacing) {
                    optionViews
                }
            }
        }
        .opacity(isEnabled ? 1.0 : 0.45)
        .focusable(isEnabled)
        .focused($isFocused)
        .focusEffectDisabled()
        .fmFocusRing(
            isFocused: isFocused,
            cornerRadius: style == .card ? FMCornerRadius.card : FMCornerRadius.control
        )
        .onKeyPress(.upArrow) {
            step(by: -1)
            return .handled
        }
        .onKeyPress(.leftArrow) {
            step(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            step(by: 1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            step(by: 1)
            return .handled
        }
        .fmAnimation(.micro, value: selection)
        .fmAnimation(.micro, value: hoveredValue)
    }

    @ViewBuilder
    private var optionViews: some View {
        ForEach(options) { option in
            let isSelected = selection == option.id
            let isHovered = hoveredValue == option.id

            Button {
                select(option.id)
            } label: {
                switch style {
                case .inline:
                    inlineRow(option: option, isSelected: isSelected, isHovered: isHovered)
                case .card:
                    cardRow(option: option, isSelected: isSelected, isHovered: isHovered)
                }
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .accessibilityLabel(
                option.subtitle.map { "\(option.title), \($0)" } ?? option.title
            )
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .onHover { hovering in
                hoveredValue = hovering ? option.id : (hoveredValue == option.id ? nil : hoveredValue)
            }
        }
    }

    private func inlineRow(option: FMRadioOption<Value>, isSelected: Bool, isHovered: Bool) -> some View {
        let radius = FMCornerRadius.micro * density.cornerScale
        return HStack(alignment: option.subtitle == nil ? .center : .top, spacing: FMSpacing.xs) {
            radioOrb(isSelected: isSelected, isHovered: isHovered)
                .padding(.top, option.subtitle == nil ? 0 : 1)

            if let icon = option.icon {
                Image(systemName: icon)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(isSelected ? accent : .secondary)
                    .frame(width: 18)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(option.title)
                    .font(.fmControl)
                    .foregroundStyle(.primary)

                if let subtitle = option.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.fmFootnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if axis == .vertical {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, FMSpacing.xs)
        .padding(.vertical, max(5, density.verticalPadding * 0.55))
        .background(
            isHovered ? FMColor.controlFill(colorScheme) : .clear,
            in: RoundedRectangle(cornerRadius: radius, style: .continuous)
        )
        .contentShape(Rectangle())
    }

    private func cardRow(option: FMRadioOption<Value>, isSelected: Bool, isHovered: Bool) -> some View {
        let radius = FMCornerRadius.card * density.cornerScale
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let baseFill: Color = {
            if isSelected {
                return reduceTransparency
                    ? FMColor.elevatedOpaqueSurface(colorScheme)
                    : accent.opacity(colorScheme == .dark ? 0.16 : 0.085)
            }
            if reduceTransparency {
                return FMColor.elevatedOpaqueSurface(colorScheme)
            }
            return isHovered ? FMColor.controlHoverFill(colorScheme) : FMColor.elevatedSurface(colorScheme)
        }()

        return HStack(alignment: .center, spacing: FMSpacing.sm) {
            if let icon = option.icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? accent : .secondary)
                    .frame(width: density.iconBadgeSize, height: density.iconBadgeSize)
                    .background(
                        (isSelected ? accent.opacity(0.16) : FMColor.controlFill(colorScheme)),
                        in: RoundedRectangle(cornerRadius: FMCornerRadius.micro, style: .continuous)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(option.title)
                    .font(.fmHeadline)
                    .foregroundStyle(.primary)

                if let subtitle = option.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.fmFootnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: FMSpacing.xs)

            radioOrb(isSelected: isSelected, isHovered: isHovered)
        }
        .padding(.horizontal, density.horizontalPadding)
        .padding(.vertical, density.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(baseFill, in: shape)
        .overlay {
            shape.strokeBorder(
                isSelected ? accent.opacity(0.85) : FMColor.hairlineHighlight(colorScheme),
                lineWidth: isSelected ? 1.5 : 0.75
            )
        }
        .shadow(
            color: isSelected ? accent.opacity(colorScheme == .dark ? 0.22 : 0.12) : .clear,
            radius: 8,
            y: 3
        )
        .contentShape(shape)
    }

    private func radioOrb(isSelected: Bool, isHovered: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isSelected ? accent : (isHovered ? FMColor.controlHoverFill(colorScheme) : FMColor.controlFill(colorScheme)))
                .frame(width: 18, height: 18)

            Circle()
                .strokeBorder(
                    isSelected ? accent : FMColor.separator(colorScheme, highContrast: true),
                    lineWidth: isSelected ? 0 : 1.1
                )
                .frame(width: 18, height: 18)

            Circle()
                .fill(.white)
                .frame(width: 7, height: 7)
                .scaleEffect(isSelected ? 1.0 : 0.01)
                .opacity(isSelected ? 1.0 : 0.0)
        }
        .shadow(color: isSelected ? accent.opacity(0.30) : .clear, radius: 4, y: 1)
    }

    private func select(_ value: Value) {
        guard isEnabled, selection != value else { return }
        selection = value
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
    }

    private func step(by delta: Int) {
        guard isEnabled else { return }
        if let next = FMRadioGroupMath.steppedValue(from: selection, in: options.map(\.id), delta: delta) {
            select(next)
        }
    }
}
