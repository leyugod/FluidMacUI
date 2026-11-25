import SwiftUI

/// Multi-option fluid dropdown selector with glass menu popover, hover row highlight,
/// checkmark indicator, and haptic selection feedback.
public struct FMDropdownPicker<Option: Hashable>: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.isEnabled) private var isEnabled

    @Binding private var selection: Option
    private let options: [Option]
    private let titleProvider: (Option) -> String
    private let iconProvider: ((Option) -> String?)?

    @State private var isExpanded = false
    @State private var isHovered = false
    @State private var hoveredMenuOption: Option?
    @State private var highlightedIndex: Int = 0
    @FocusState private var isFocused: Bool
    @FocusState private var isMenuFocused: Bool

    public init(
        selection: Binding<Option>,
        options: [Option],
        title: @escaping (Option) -> String,
        icon: ((Option) -> String?)? = nil
    ) {
        self._selection = selection
        self.options = options
        self.titleProvider = title
        self.iconProvider = icon
    }

    public var body: some View {
        let radius = FMCornerRadius.control * density.cornerScale
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let accent = FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)

        Button {
            isExpanded.toggle()
            FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
        } label: {
            HStack(spacing: FMSpacing.xs) {
                if let icon = iconProvider?(selection) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                }

                Text(titleProvider(selection))
                    .font(.fmControl)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: FMSpacing.xs)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, FMSpacing.sm)
            .frame(height: density.controlHeight)
            .background(
                isHovered || isExpanded ? FMColor.controlHoverFill(colorScheme) : FMColor.controlFill(colorScheme),
                in: shape
            )
            .overlay {
                shape.strokeBorder(
                    isExpanded ? accent.opacity(0.75) : FMColor.hairlineHighlight(colorScheme),
                    lineWidth: isExpanded ? 1.25 : 0.75
                )
            }
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1.0 : 0.45)
        .focused($isFocused)
        .focusEffectDisabled()
        .fmFocusRing(isFocused: isFocused, cornerRadius: FMCornerRadius.control)
        .onHover { isHovered = $0 }
        .fmAnimation(.micro, value: isExpanded)
        .fmAnimation(.micro, value: isHovered)
        .popover(isPresented: $isExpanded, arrowEdge: .bottom) {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 3) {
                        ForEach(Array(options.enumerated()), id: \.element) { index, option in
                            let isSelected = option == selection
                            let rowHighlighted = hoveredMenuOption == option || highlightedIndex == index

                            Button {
                                selection = option
                                isExpanded = false
                                FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                            } label: {
                                HStack(spacing: FMSpacing.xs) {
                                    if let icon = iconProvider?(option) {
                                        Image(systemName: icon)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(isSelected ? accent : .secondary)
                                            .frame(width: 18)
                                    }

                                    Text(titleProvider(option))
                                        .font(.fmBody)
                                        .foregroundStyle(.primary)

                                    Spacer(minLength: FMSpacing.md)

                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(accent)
                                    }
                                }
                                .padding(.horizontal, FMSpacing.sm)
                                .frame(height: max(30, density.controlHeight - 4))
                                .background(
                                    rowHighlighted ? accent.opacity(0.14) : (isSelected ? FMColor.controlFill(colorScheme) : .clear),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                                .contentShape(Rectangle())
                            }
                            .id(option)
                            .buttonStyle(.plain)
                            .focusEffectDisabled()
                            .onHover { hovering in
                                hoveredMenuOption = hovering ? option : (hoveredMenuOption == option ? nil : hoveredMenuOption)
                                if hovering { highlightedIndex = index }
                            }
                        }
                    }
                    .padding(6)
                }
                .frame(minWidth: 180, maxHeight: 280)
                .focusable()
                .focused($isMenuFocused)
                .focusEffectDisabled()
                .onAppear {
                    highlightedIndex = options.firstIndex(of: selection) ?? 0
                    isMenuFocused = true
                }
                .onKeyPress(.upArrow) {
                    guard !options.isEmpty else { return .ignored }
                    highlightedIndex = (highlightedIndex - 1 + options.count) % options.count
                    scrollProxy.scrollTo(options[highlightedIndex])
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    guard !options.isEmpty else { return .ignored }
                    highlightedIndex = (highlightedIndex + 1) % options.count
                    scrollProxy.scrollTo(options[highlightedIndex])
                    return .handled
                }
                .onKeyPress(.return) {
                    guard options.indices.contains(highlightedIndex) else { return .ignored }
                    selection = options[highlightedIndex]
                    isExpanded = false
                    FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                    return .handled
                }
                .onKeyPress(.escape) {
                    isExpanded = false
                    return .handled
                }
            }
        }
    }
}

public extension FMDropdownPicker where Option: CustomStringConvertible {
    init(selection: Binding<Option>, options: [Option]) {
        self.init(selection: selection, options: options, title: { $0.description })
    }
}
