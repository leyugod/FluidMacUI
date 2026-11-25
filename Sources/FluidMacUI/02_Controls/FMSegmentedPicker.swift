import SwiftUI

/// Fluid segmented control with matched-geometry gliding selection indicator,
/// keyboard arrow navigation, icon + text composition, and Liquid Glass polish.
public struct FMSegmentedPicker<Option: Hashable, LabelView: View>: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    @Namespace private var thumbNamespace
    @State private var hoveredOption: Option?
    @FocusState private var isFocused: Bool

    @Binding private var selection: Option
    private let options: [Option]
    private let label: (Option) -> LabelView

    public init(
        selection: Binding<Option>,
        options: [Option],
        @ViewBuilder label: @escaping (Option) -> LabelView
    ) {
        self._selection = selection
        self.options = options
        self.label = label
    }

    public var body: some View {
        let radius = FMCornerRadius.control * density.cornerScale
        let trackShape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let thumbRadius = max(6, radius - 3)

        HStack(spacing: 3) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection == option
                let isHovered = hoveredOption == option && !isSelected

                Button {
                    select(option)
                } label: {
                    label(option)
                        .font(.fmControl)
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, FMSpacing.sm)
                        .frame(maxWidth: .infinity)
                        .frame(height: density.controlHeight - 6)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: thumbRadius, style: .continuous)
                                    .fill(
                                        colorScheme == .dark
                                            ? Color.white.opacity(0.18)
                                            : Color.white
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: thumbRadius, style: .continuous)
                                            .strokeBorder(
                                                FMColor.hairlineHighlight(colorScheme),
                                                lineWidth: 0.5
                                            )
                                    }
                                    .shadow(
                                        color: Color.black.opacity(colorScheme == .dark ? 0.26 : 0.08),
                                        radius: 4,
                                        y: 1.5
                                    )
                                    .matchedGeometryEffect(id: "fm-segment-thumb", in: thumbNamespace)
                            } else if isHovered {
                                RoundedRectangle(cornerRadius: thumbRadius, style: .continuous)
                                    .fill(FMColor.controlFill(colorScheme))
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: thumbRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .onHover { hovering in
                    hoveredOption = hovering ? option : (hoveredOption == option ? nil : hoveredOption)
                }
            }
        }
        .padding(3)
        .background(FMColor.controlFill(colorScheme), in: trackShape)
        .overlay {
            trackShape.strokeBorder(FMColor.hairlineHighlight(colorScheme), lineWidth: 0.5)
        }
        .opacity(isEnabled ? 1.0 : 0.45)
        .focusable(isEnabled)
        .focused($isFocused)
        .focusEffectDisabled()
        .fmFocusRing(isFocused: isFocused, cornerRadius: FMCornerRadius.control)
        .onKeyPress(.leftArrow) {
            stepSelection(by: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            stepSelection(by: 1)
            return .handled
        }
        .fmAnimation(.navigation, value: selection)
        .fmAnimation(.micro, value: hoveredOption)
    }

    private func select(_ option: Option) {
        guard isEnabled, selection != option else { return }
        selection = option
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
    }

    private func stepSelection(by delta: Int) {
        guard let index = options.firstIndex(of: selection) else { return }
        let target = max(0, min(options.count - 1, index + delta))
        select(options[target])
    }
}

public extension FMSegmentedPicker where Option: CustomStringConvertible, LabelView == Text {
    init(selection: Binding<Option>, options: [Option]) {
        self.init(selection: selection, options: options) { option in
            Text(option.description)
        }
    }
}
