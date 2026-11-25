import SwiftUI

/// Segment entry in `FMBreadcrumbBar`.
public struct FMBreadcrumbItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let icon: String?

    public init(id: String? = nil, title: String, icon: String? = nil) {
        self.id = id ?? title
        self.title = title
        self.icon = icon
    }
}

/// Finder-style interactive hierarchical path breadcrumb bar with hover pill highlights.
public struct FMBreadcrumbBar: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private let items: [FMBreadcrumbItem]
    private let onSelect: (FMBreadcrumbItem) -> Void

    @State private var hoveredID: String?
    @FocusState private var focusedID: String?

    public init(
        items: [FMBreadcrumbItem],
        onSelect: @escaping (FMBreadcrumbItem) -> Void
    ) {
        self.items = items
        self.onSelect = onSelect
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let isLast = index == items.count - 1
                    let isHovered = hoveredID == item.id && !isLast

                    Button {
                        guard !isLast else { return }
                        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                        onSelect(item)
                    } label: {
                        HStack(spacing: 5) {
                            if let icon = item.icon {
                                Image(systemName: icon)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            Text(item.title)
                                .font(.system(size: 13, weight: isLast ? .semibold : .regular))
                                .lineLimit(1)
                        }
                        .foregroundStyle(isLast ? Color.primary : Color.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            isHovered ? FMColor.controlFill(colorScheme) : .clear,
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .focused($focusedID, equals: item.id)
                    .focusEffectDisabled()
                    .fmFocusRing(isFocused: focusedID == item.id, cornerRadius: 7)
                    .disabled(isLast)
                    .onHover { hovering in
                        hoveredID = hovering ? item.id : (hoveredID == item.id ? nil : hoveredID)
                    }

                    if !isLast {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .fmAnimation(.micro, value: hoveredID)
    }
}
