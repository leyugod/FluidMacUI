import SwiftUI

/// Multi-line editorial text block with clean line clamping and an inline accent `more / less` toggle
/// (matching App Store's "What's New" and release notes presentation).
public struct FMExpandableText: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState

    private let text: String
    private let collapsedLineLimit: Int
    private let moreTitle: String
    private let lessTitle: String

    @State private var isExpanded = false
    @State private var isTruncated = false
    @FocusState private var isToggleFocused: Bool

    public init(
        _ text: String,
        lineLimit: Int = 3,
        moreTitle: String = "more",
        lessTitle: String = "less"
    ) {
        self.text = text
        self.collapsedLineLimit = max(1, lineLimit)
        self.moreTitle = moreTitle
        self.lessTitle = lessTitle
    }

    public var body: some View {
        let accent = FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)

        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.fmBody)
                .foregroundStyle(.primary.opacity(0.9))
                .lineSpacing(3)
                .lineLimit(isExpanded ? nil : collapsedLineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    GeometryReader { clampedProxy in
                        Text(text)
                            .font(.fmBody)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .background {
                                GeometryReader { fullProxy in
                                    Color.clear
                                        .onAppear {
                                            if !isExpanded {
                                                isTruncated = fullProxy.size.height > clampedProxy.size.height + 1
                                            }
                                        }
                                        .onChange(of: clampedProxy.size.width) { _, _ in
                                            if !isExpanded {
                                                isTruncated = fullProxy.size.height > clampedProxy.size.height + 1
                                            }
                                        }
                                }
                            }
                            .hidden()
                    }
                }

            if isTruncated || isExpanded {
                HStack {
                    Spacer()
                    Button(isExpanded ? lessTitle : moreTitle) {
                        isExpanded.toggle()
                        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(accent)
                    .focused($isToggleFocused)
                    .focusEffectDisabled()
                    .fmFocusRing(isFocused: isToggleFocused, cornerRadius: 6)
                }
            }
        }
        .fmAnimation(.modal, value: isExpanded)
    }
}
