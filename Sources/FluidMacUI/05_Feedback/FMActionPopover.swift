import SwiftUI

/// Entry inside a `FMActionPopover` context menu.
public enum FMActionMenuItem: Identifiable {
    case action(
        id: UUID = UUID(),
        title: String,
        icon: String? = nil,
        shortcut: String? = nil,
        isDestructive: Bool = false,
        handler: () -> Void
    )
    case divider(id: UUID = UUID())

    public var id: UUID {
        switch self {
        case .action(let id, _, _, _, _, _): id
        case .divider(let id): id
        }
    }
}

/// Anchored iOS `UIMenu`-inspired spring-scaling glass context popover with hover highlight,
/// shortcut keycap labels, and destructive action support.
public struct FMActionPopoverModifier: ViewModifier {
    @Environment(\.fmTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @Binding private var isPresented: Bool
    private let anchor: UnitPoint
    private let items: [FMActionMenuItem]

    @State private var hoveredID: UUID?

    public init(
        isPresented: Binding<Bool>,
        anchor: UnitPoint = .topTrailing,
        items: [FMActionMenuItem]
    ) {
        self._isPresented = isPresented
        self.anchor = anchor
        self.items = items
    }

    public func body(content: Content) -> some View {
        content
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(items) { item in
                        switch item {
                        case .divider:
                            Divider()
                                .padding(.vertical, 3)
                                .padding(.horizontal, 6)

                        case .action(let id, let title, let icon, let shortcut, let isDestructive, let handler):
                            let isHovered = hoveredID == id
                            Button {
                                FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                                isPresented = false
                                handler()
                            } label: {
                                HStack(spacing: FMSpacing.xs) {
                                    if let icon {
                                        Image(systemName: icon)
                                            .font(.system(size: 13, weight: .medium))
                                            .frame(width: 18)
                                    }

                                    Text(title)
                                        .font(.fmBody)

                                    Spacer(minLength: FMSpacing.md)

                                    if let shortcut, !shortcut.isEmpty {
                                        Text(shortcut)
                                            .font(.fmMono)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .foregroundStyle(isDestructive ? FMColor.red : .primary)
                                .padding(.horizontal, FMSpacing.sm)
                                .frame(height: 32)
                                .background(
                                    isHovered
                                        ? (isDestructive ? FMColor.red.opacity(0.14) : theme.accentColor.opacity(0.14))
                                        : .clear,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .focusEffectDisabled()
                            .onHover { hovering in
                                hoveredID = hovering ? id : (hoveredID == id ? nil : hoveredID)
                            }
                        }
                    }
                }
                .padding(6)
                .frame(minWidth: 200)
                .scaleEffect(isPresented ? 1.0 : 0.85, anchor: anchor)
                .fmAnimation(.micro, value: isPresented)
            }
    }
}

public extension View {
    /// Attaches a FluidMacUI anchored glass action menu popover to this view.
    func fmActionPopover(
        isPresented: Binding<Bool>,
        anchor: UnitPoint = .topTrailing,
        items: [FMActionMenuItem]
    ) -> some View {
        modifier(
            FMActionPopoverModifier(
                isPresented: isPresented,
                anchor: anchor,
                items: items
            )
        )
    }
}
