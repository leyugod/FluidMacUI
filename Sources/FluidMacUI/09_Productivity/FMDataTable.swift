import SwiftUI

/// Column sizing rule for `FMDataTable`.
public enum FMColumnWidth: Sendable, Hashable {
    case fixed(CGFloat)
    case flexible(min: CGFloat = 80)
}

/// Column definition inside `FMDataTable`.
public struct FMTableColumn<Row>: Identifiable {
    public let id: String
    public let title: String
    public let width: FMColumnWidth
    public let alignment: Alignment
    public let comparator: ((Row, Row) -> ComparisonResult)?
    let cellBuilder: (Row) -> AnyView

    public init<Cell: View>(
        id: String? = nil,
        title: String,
        width: FMColumnWidth = .flexible(),
        alignment: Alignment = .leading,
        sortBy comparator: ((Row, Row) -> ComparisonResult)? = nil,
        @ViewBuilder cell: @escaping (Row) -> Cell
    ) {
        self.id = id ?? title
        self.title = title
        self.width = width
        self.alignment = alignment
        self.comparator = comparator
        self.cellBuilder = { AnyView(cell($0)) }
    }
}

/// Sort direction for `FMDataTable`.
public enum FMSortDirection: Sendable, Hashable {
    case ascending
    case descending

    public mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }
}

/// Pure row selection logic supporting single click, `⌘`-toggle, and `⇧`-range selection (unit-tested).
public enum FMTableSelectionMath {
    public static func updatedSelection<ID: Hashable>(
        current: Set<ID>,
        orderedIDs: [ID],
        clickedID: ID,
        anchorID: ID?,
        allowsMultiple: Bool,
        isCommandHeld: Bool,
        isShiftHeld: Bool
    ) -> (selection: Set<ID>, newAnchor: ID?) {
        if allowsMultiple && isShiftHeld,
           let anchorID,
           let start = orderedIDs.firstIndex(of: anchorID),
           let end = orderedIDs.firstIndex(of: clickedID) {
            let lower = min(start, end)
            let upper = max(start, end)
            return (Set(orderedIDs[lower...upper]), anchorID)
        }
        if allowsMultiple && isCommandHeld {
            var next = current
            if next.contains(clickedID) {
                next.remove(clickedID)
            } else {
                next.insert(clickedID)
            }
            return (next, clickedID)
        }
        if allowsMultiple && current.contains(clickedID) && current.count == 1 {
            return ([], nil)
        }
        return ([clickedID], clickedID)
    }
}

/// Native macOS fluid multi-column data table with sortable column headers,
/// hover row highlight, single/multi selection (`⌘`-click & `⇧`-range), keyboard arrows, and crisp hairline dividers.
public struct FMDataTable<Row: Identifiable>: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState

    private let rows: [Row]
    private let columns: [FMTableColumn<Row>]
    @Binding private var selection: Set<Row.ID>
    private let allowsMultipleSelection: Bool
    private let onDoubleClick: ((Row) -> Void)?

    @State private var sortColumnID: String?
    @State private var sortDirection: FMSortDirection = .ascending
    @State private var hoveredRowID: Row.ID?
    @State private var anchorRowID: Row.ID?
    @FocusState private var isTableFocused: Bool

    public init(
        rows: [Row],
        columns: [FMTableColumn<Row>],
        selection: Binding<Set<Row.ID>> = .constant([]),
        allowsMultipleSelection: Bool = true,
        onDoubleClick: ((Row) -> Void)? = nil
    ) {
        self.rows = rows
        self.columns = columns
        self._selection = selection
        self.allowsMultipleSelection = allowsMultipleSelection
        self.onDoubleClick = onDoubleClick
    }

    private var sortedRows: [Row] {
        guard let sortColumnID,
              let col = columns.first(where: { $0.id == sortColumnID }),
              let comparator = col.comparator else {
            return rows
        }
        return rows.sorted { lhs, rhs in
            let order = comparator(lhs, rhs)
            return sortDirection == .ascending ? order == .orderedAscending : order == .orderedDescending
        }
    }

    public var body: some View {
        let radius = FMCornerRadius.card * density.cornerScale
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        VStack(spacing: 0) {
            // Header row
            HStack(spacing: FMSpacing.sm) {
                ForEach(columns) { column in
                    headerCell(for: column)
                }
            }
            .padding(.horizontal, FMSpacing.md)
            .frame(height: 34)
            .background(FMColor.elevatedSurface(colorScheme))

            FMHairlineDivider()

            if sortedRows.isEmpty {
                Text("暂无数据")
                    .font(.fmSubheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(sortedRows.enumerated()), id: \.element.id) { index, row in
                        let isSelected = selection.contains(row.id)
                        let isHovered = hoveredRowID == row.id

                        HStack(spacing: FMSpacing.sm) {
                            ForEach(columns) { column in
                                column.cellBuilder(row)
                                    .modifier(FMColumnWidthModifier(width: column.width, alignment: column.alignment))
                            }
                        }
                        .padding(.horizontal, FMSpacing.md)
                        .frame(minHeight: max(36, density.rowMinHeight - 6))
                        .background(rowBackground(isSelected: isSelected, isHovered: isHovered, isEven: index % 2 == 1))
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            hoveredRowID = hovering ? row.id : (hoveredRowID == row.id ? nil : hoveredRowID)
                        }
                        .onTapGesture {
                            if NSApp.currentEvent?.clickCount == 2 {
                                selection = [row.id]
                                anchorRowID = row.id
                                onDoubleClick?(row)
                            } else {
                                handleSelection(rowID: row.id)
                            }
                        }

                        if index < sortedRows.count - 1 {
                            FMHairlineDivider(.horizontal, inset: FMSpacing.md)
                        }
                    }
                }
            }
        }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(FMColor.hairlineHighlight(colorScheme), lineWidth: 0.5)
        }
        .focusable()
        .focused($isTableFocused)
        .focusEffectDisabled()
        .fmFocusRing(isFocused: isTableFocused, cornerRadius: FMCornerRadius.card)
        .onKeyPress(.upArrow) {
            stepRowSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            stepRowSelection(by: 1)
            return .handled
        }
        .fmAnimation(.micro, value: selection)
        .fmAnimation(.micro, value: sortColumnID)
        .fmAnimation(.micro, value: sortDirection)
    }

    @ViewBuilder
    private func headerCell(for column: FMTableColumn<Row>) -> some View {
        let isSorted = sortColumnID == column.id
        let sortable = column.comparator != nil
        let accent = FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)

        Button {
            guard sortable else { return }
            if sortColumnID == column.id {
                sortDirection.toggle()
            } else {
                sortColumnID = column.id
                sortDirection = .ascending
            }
            FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
        } label: {
            HStack(spacing: 4) {
                Text(column.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(isSorted ? .primary : .secondary)

                if sortable && isSorted {
                    Image(systemName: sortDirection == .ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(accent)
                }
            }
            .modifier(FMColumnWidthModifier(width: column.width, alignment: column.alignment))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .disabled(!sortable)
    }

    private func rowBackground(isSelected: Bool, isHovered: Bool, isEven: Bool) -> Color {
        if isSelected {
            let accent = FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
            return accent.opacity(colorScheme == .dark ? 0.22 : 0.14)
        }
        if isHovered {
            return FMColor.controlFill(colorScheme).opacity(0.8)
        }
        return isEven ? FMColor.elevatedSurface(colorScheme).opacity(0.45) : .clear
    }

    private func handleSelection(rowID: Row.ID) {
        let flags = NSEvent.modifierFlags
        let result = FMTableSelectionMath.updatedSelection(
            current: selection,
            orderedIDs: sortedRows.map(\.id),
            clickedID: rowID,
            anchorID: anchorRowID,
            allowsMultiple: allowsMultipleSelection,
            isCommandHeld: flags.contains(.command),
            isShiftHeld: flags.contains(.shift)
        )
        selection = result.selection
        anchorRowID = result.newAnchor
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
    }

    private func stepRowSelection(by delta: Int) {
        let ids = sortedRows.map(\.id)
        guard !ids.isEmpty else { return }
        if let currentID = anchorRowID ?? selection.first,
           let currentIndex = ids.firstIndex(of: currentID) {
            let nextIndex = max(0, min(ids.count - 1, currentIndex + delta))
            let nextID = ids[nextIndex]
            selection = [nextID]
            anchorRowID = nextID
        } else {
            let firstID = delta >= 0 ? ids.first! : ids.last!
            selection = [firstID]
            anchorRowID = firstID
        }
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
    }
}

private struct FMColumnWidthModifier: ViewModifier {
    let width: FMColumnWidth
    let alignment: Alignment

    func body(content: Content) -> some View {
        switch width {
        case .fixed(let w):
            content.frame(width: w, alignment: alignment)
        case .flexible(let min):
            content.frame(minWidth: min, maxWidth: .infinity, alignment: alignment)
        }
    }
}
