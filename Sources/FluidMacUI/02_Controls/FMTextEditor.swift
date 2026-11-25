import SwiftUI

/// Multi-line rounded fluid text editor with placeholder copy, optional character limit badge,
/// and clean focus glow without native AppKit scroll-view borders.
public struct FMTextEditor: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.isEnabled) private var isEnabled

    @Binding private var text: String
    private let placeholder: String
    private let minHeight: CGFloat
    private let maxCharacters: Int?

    @FocusState private var isFocused: Bool
    @State private var isHovered = false

    public init(
        _ placeholder: String,
        text: Binding<String>,
        minHeight: CGFloat = 96,
        maxCharacters: Int? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.minHeight = minHeight
        self.maxCharacters = maxCharacters
    }

    public var body: some View {
        let radius = FMCornerRadius.control * density.cornerScale
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let accent = FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
        let isOverLimit = maxCharacters.map { text.count > $0 } ?? false
        let borderColor = isOverLimit ? FMColor.red : (isFocused ? accent : FMColor.hairlineHighlight(colorScheme))

        VStack(alignment: .trailing, spacing: 4) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.fmBody)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $text)
                    .font(.fmBody)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .focused($isFocused)
                    .focusEffectDisabled()
            }
            .frame(minHeight: minHeight)
            .background(
                isFocused
                    ? FMColor.elevatedSurface(colorScheme)
                    : (isHovered ? FMColor.controlHoverFill(colorScheme) : FMColor.controlFill(colorScheme)),
                in: shape
            )
            .overlay {
                shape.strokeBorder(
                    borderColor.opacity(isFocused || isOverLimit ? 0.85 : 1.0),
                    lineWidth: isFocused || isOverLimit ? 1.5 : 0.75
                )
            }
            .shadow(color: (isFocused || isOverLimit) ? borderColor.opacity(0.16) : .clear, radius: 6)
            .opacity(isEnabled ? 1.0 : 0.45)
            .onHover { isHovered = $0 }
            .fmAnimation(.micro, value: isFocused)
            .fmAnimation(.micro, value: isHovered)

            if let maxCharacters {
                Text("\(text.count) / \(maxCharacters)")
                    .font(.fmNumeric(size: 11, weight: .medium))
                    .foregroundStyle(isOverLimit ? FMColor.red : .secondary)
                    .padding(.trailing, 4)
            }
        }
    }
}
