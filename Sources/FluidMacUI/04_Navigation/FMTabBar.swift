import SwiftUI

/// Descriptor for a single tab item inside `FMTabBar`.
public struct FMTabItem<Selection: Hashable>: Identifiable {
    public let id: Selection
    public let title: String
    public let icon: String

    public init(id: Selection, title: String, icon: String) {
        self.id = id
        self.title = title
        self.icon = icon
    }
}

/// Floating glass capsule tab bar featuring Liquid Glass container unioning,
/// matched-geometry active pill glide, and SF Symbols bounce animations.
public struct FMTabBar<Selection: Hashable>: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState

    @Binding private var selection: Selection
    private let items: [FMTabItem<Selection>]

    @Namespace private var tabNamespace
    @State private var hoveredID: Selection?
    @FocusState private var isFocused: Bool

    public init(
        selection: Binding<Selection>,
        items: [FMTabItem<Selection>]
    ) {
        self._selection = selection
        self.items = items
    }

    public var body: some View {
        let accent = FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)

        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(items) { item in
                    let isSelected = selection == item.id
                    let isHovered = hoveredID == item.id && !isSelected

                    Button {
                        guard selection != item.id else { return }
                        selection = item.id
                        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 13.5, weight: .semibold))
                                .symbolEffect(.bounce, value: isSelected)

                            Text(item.title)
                                .font(.fmControl)
                                .lineLimit(1)
                        }
                        .foregroundStyle(isSelected ? accent : Color.secondary)
                        .padding(.horizontal, FMSpacing.md)
                        .frame(height: density.controlHeight)
                        .background {
                            if isSelected {
                                Capsule(style: .continuous)
                                    .fill(accent.opacity(colorScheme == .dark ? 0.24 : 0.14))
                                    .matchedGeometryEffect(id: "fm-tab-pill", in: tabNamespace)
                            } else if isHovered {
                                Capsule(style: .continuous)
                                    .fill(FMColor.controlFill(colorScheme))
                            }
                        }
                        .contentShape(Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .onHover { hovering in
                        hoveredID = hovering ? item.id : (hoveredID == item.id ? nil : hoveredID)
                    }
                }
            }
            .padding(5)
            .fmGlassSurface(.regular, isCapsule: true, showShadow: true)
        }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .fmFocusRing(isFocused: isFocused, isCapsule: true)
        .onKeyPress(.leftArrow) {
            stepTab(by: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            stepTab(by: 1)
            return .handled
        }
        .fmAnimation(.navigation, value: selection)
        .fmAnimation(.micro, value: hoveredID)
    }

    private func stepTab(by delta: Int) {
        guard let idx = items.firstIndex(where: { $0.id == selection }) else { return }
        let target = max(0, min(items.count - 1, idx + delta))
        let next = items[target].id
        guard next != selection else { return }
        selection = next
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
    }
}
