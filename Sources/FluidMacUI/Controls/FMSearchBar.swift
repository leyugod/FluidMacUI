import SwiftUI

/// Capsule/rounded iOS search bar with spring-sliding Cancel button,
/// clear action, and Escape-to-dismiss keyboard support.
public struct FMSearchBar: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState

    @Binding private var text: String
    private let placeholder: String
    private let cancelTitle: String
    private let isCapsule: Bool
    private let onSubmit: (() -> Void)?

    @FocusState private var isFocused: Bool
    @State private var isHovered = false

    public init(
        text: Binding<String>,
        placeholder: String = "搜索...",
        cancelTitle: String = "取消",
        isCapsule: Bool = true,
        onSubmit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.cancelTitle = cancelTitle
        self.isCapsule = isCapsule
        self.onSubmit = onSubmit
    }

    private var showsCancel: Bool {
        isFocused || !text.isEmpty
    }

    public var body: some View {
        let radius = FMCornerRadius.control * density.cornerScale
        let accent = FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)

        HStack(spacing: FMSpacing.xs) {
            HStack(spacing: FMSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(isFocused ? accent : .secondary)
                    .scaleEffect(isFocused ? 1.05 : 1.0)

                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.fmBody)
                    .focused($isFocused)
                    .focusEffectDisabled()
                    .onSubmit {
                        onSubmit?()
                    }
                    .onKeyPress(.escape) {
                        text = ""
                        isFocused = false
                        return .handled
                    }

                if !text.isEmpty {
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
                    .accessibilityLabel("Clear search")
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .padding(.horizontal, FMSpacing.sm)
            .frame(height: density.controlHeight)
            .background {
                let fill = isFocused
                    ? FMColor.elevatedSurface(colorScheme)
                    : (isHovered ? FMColor.controlHoverFill(colorScheme) : FMColor.controlFill(colorScheme))
                if isCapsule {
                    Capsule(style: .continuous).fill(fill)
                } else {
                    RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
                }
            }
            .overlay {
                let stroke = isFocused ? accent.opacity(0.85) : FMColor.hairlineHighlight(colorScheme)
                let width: CGFloat = isFocused ? 1.5 : 0.75
                if isCapsule {
                    Capsule(style: .continuous).strokeBorder(stroke, lineWidth: width)
                } else {
                    RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(stroke, lineWidth: width)
                }
            }
            .shadow(color: isFocused ? accent.opacity(0.16) : .clear, radius: 6)
            .onHover { isHovered = $0 }

            if showsCancel {
                Button(cancelTitle) {
                    text = ""
                    isFocused = false
                    FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                }
                .buttonStyle(.fmGhost)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .fmAnimation(.navigation, value: showsCancel)
        .fmAnimation(.micro, value: isFocused)
        .fmAnimation(.micro, value: text.isEmpty)
    }
}
