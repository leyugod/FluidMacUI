import SwiftUI

/// Floating bottom Liquid Glass bulk-action capsule bar that springs into view
/// whenever one or more items are selected in a list, table, or gallery.
public struct FMSelectionActionBar<Actions: View>: View {
    @Environment(\.fmTheme) private var theme

    private let selectedCount: Int
    private let unitLabel: String
    private let onClear: () -> Void
    private let actions: Actions

    public init(
        selectedCount: Int,
        unitLabel: String = "项",
        onClear: @escaping () -> Void,
        @ViewBuilder actions: () -> Actions
    ) {
        self.selectedCount = selectedCount
        self.unitLabel = unitLabel
        self.onClear = onClear
        self.actions = actions()
    }

    public var body: some View {
        Group {
            if selectedCount > 0 {
                HStack(spacing: FMSpacing.sm) {
                    Button {
                        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                        onClear()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .accessibilityLabel("Clear selection")

                    Text("已选 \(selectedCount) \(unitLabel)")
                        .font(.fmNumeric(size: 13, weight: .semibold))
                        .contentTransition(.numericText(value: Double(selectedCount)))

                    FMHairlineDivider(.vertical)
                        .frame(height: 18)

                    actions
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .fmGlassSurface(.regular, isCapsule: true, showShadow: true)
                .transition(.move(edge: .bottom).combined(with: .scale(scale: 0.92)).combined(with: .opacity))
            }
        }
        .fmAnimation(.modal, value: selectedCount > 0)
        .fmAnimation(.micro, value: selectedCount)
    }
}
