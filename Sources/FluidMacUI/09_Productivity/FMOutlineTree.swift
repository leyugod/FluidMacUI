import SwiftUI
import AppKit

/// Hierarchical tree node model for `FMOutlineTree`.
public struct FMOutlineNode<ID: Hashable & Sendable>: Identifiable, Sendable {
    public let id: ID
    public let title: String
    public let subtitle: String?
    public let icon: String?
    public let iconColor: Color?
    public let badge: String?
    /// `nil` represents a leaf item; `[]` represents an empty container/folder.
    public let children: [FMOutlineNode<ID>]?

    /// Creates an outline tree node.
    public init(
        id: ID,
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color? = nil,
        badge: String? = nil,
        children: [FMOutlineNode<ID>]? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.badge = badge
        self.children = children
    }

    /// Returns `true` when the node represents a container (even if currently empty).
    public var isContainer: Bool {
        children != nil
    }

    /// Returns `true` when the node has one or more child nodes to disclose.
    public var hasChildren: Bool {
        !(children?.isEmpty ?? true)
    }
}

/// Flattened visible row produced by `FMOutlineTreeMath.flatten(_:expanded:)`.
public struct FMFlattenedOutlineRow<ID: Hashable & Sendable>: Identifiable, Sendable {
    public let id: ID
    public let node: FMOutlineNode<ID>
    public let depth: Int
    public let isExpandable: Bool
    public let isExpanded: Bool
    public let parentID: ID?

    public init(
        id: ID,
        node: FMOutlineNode<ID>,
        depth: Int,
        isExpandable: Bool,
        isExpanded: Bool,
        parentID: ID?
    ) {
        self.id = id
        self.node = node
        self.depth = depth
        self.isExpandable = isExpandable
        self.isExpanded = isExpanded
        self.parentID = parentID
    }
}

/// Pure, testable tree flattening and keyboard navigation helpers for `FMOutlineTree`.
public enum FMOutlineTreeMath {
    /// Flattens a forest of outline nodes into depth-first visible rows based on `expanded` IDs.
    public static func flatten<ID: Hashable & Sendable>(
        _ roots: [FMOutlineNode<ID>],
        expanded: Set<ID>
    ) -> [FMFlattenedOutlineRow<ID>] {
        var result: [FMFlattenedOutlineRow<ID>] = []
        result.reserveCapacity(roots.count)
        appendNodes(roots, depth: 0, parentID: nil, expanded: expanded, into: &result)
        return result
    }

    private static func appendNodes<ID: Hashable & Sendable>(
        _ nodes: [FMOutlineNode<ID>],
        depth: Int,
        parentID: ID?,
        expanded: Set<ID>,
        into result: inout [FMFlattenedOutlineRow<ID>]
    ) {
        for node in nodes {
            let isExpandable = node.hasChildren
            let isExpanded = isExpandable && expanded.contains(node.id)
            result.append(
                FMFlattenedOutlineRow(
                    id: node.id,
                    node: node,
                    depth: depth,
                    isExpandable: isExpandable,
                    isExpanded: isExpanded,
                    parentID: parentID
                )
            )
            if isExpanded, let children = node.children {
                appendNodes(children, depth: depth + 1, parentID: node.id, expanded: expanded, into: &result)
            }
        }
    }

    /// Computes the next selected row ID when stepping by `delta` (`-1` for up, `+1` for down).
    public static func nextSelection<ID: Hashable & Sendable>(
        from current: ID?,
        in rows: [FMFlattenedOutlineRow<ID>],
        delta: Int
    ) -> ID? {
        guard !rows.isEmpty else { return nil }
        guard let current, let currentIndex = rows.firstIndex(where: { $0.id == current }) else {
            return delta < 0 ? rows.last?.id : rows.first?.id
        }
        let targetIndex = min(max(currentIndex + delta, 0), rows.count - 1)
        return rows[targetIndex].id
    }

    /// Toggles expansion state for a node ID.
    public static func toggleExpanded<ID: Hashable & Sendable>(
        _ id: ID,
        in expanded: Set<ID>
    ) -> Set<ID> {
        var updated = expanded
        if updated.contains(id) {
            updated.remove(id)
        } else {
            updated.insert(id)
        }
        return updated
    }

    /// Handles Finder/Xcode right-arrow behavior: expands a collapsed branch, or descends to its first child if already expanded.
    public static func expandOrDescend<ID: Hashable & Sendable>(
        from current: ID?,
        in rows: [FMFlattenedOutlineRow<ID>],
        expanded: Set<ID>
    ) -> (selection: ID?, expanded: Set<ID>) {
        guard !rows.isEmpty else { return (nil, expanded) }
        guard let current, let index = rows.firstIndex(where: { $0.id == current }) else {
            return (rows.first?.id, expanded)
        }
        let row = rows[index]
        guard row.isExpandable else {
            return (current, expanded)
        }
        if !row.isExpanded {
            var updated = expanded
            updated.insert(row.id)
            return (current, updated)
        }
        let nextIndex = index + 1
        if nextIndex < rows.count, rows[nextIndex].parentID == row.id {
            return (rows[nextIndex].id, expanded)
        }
        return (current, expanded)
    }

    /// Handles Finder/Xcode left-arrow behavior: collapses an expanded branch, or ascends to the parent row.
    public static func collapseOrAscend<ID: Hashable & Sendable>(
        from current: ID?,
        in rows: [FMFlattenedOutlineRow<ID>],
        expanded: Set<ID>
    ) -> (selection: ID?, expanded: Set<ID>) {
        guard !rows.isEmpty else { return (nil, expanded) }
        guard let current, let index = rows.firstIndex(where: { $0.id == current }) else {
            return (rows.first?.id, expanded)
        }
        let row = rows[index]
        if row.isExpandable && row.isExpanded {
            var updated = expanded
            updated.remove(row.id)
            return (current, updated)
        }
        if let parentID = row.parentID {
            return (parentID, expanded)
        }
        return (current, expanded)
    }

    /// Returns the set of all expandable node IDs across the entire forest.
    public static func allExpandableIDs<ID: Hashable & Sendable>(
        in roots: [FMOutlineNode<ID>]
    ) -> Set<ID> {
        var ids = Set<ID>()
        collectExpandableIDs(roots, into: &ids)
        return ids
    }

    private static func collectExpandableIDs<ID: Hashable & Sendable>(
        _ nodes: [FMOutlineNode<ID>],
        into ids: inout Set<ID>
    ) {
        for node in nodes {
            if node.hasChildren, let children = node.children {
                ids.insert(node.id)
                collectExpandableIDs(children, into: &ids)
            }
        }
    }

    /// Returns all ancestor IDs needed to reveal `targetID` in the tree.
    public static func ancestorIDs<ID: Hashable & Sendable>(
        of targetID: ID,
        in roots: [FMOutlineNode<ID>]
    ) -> Set<ID> {
        var path: [ID] = []
        if findAncestors(of: targetID, in: roots, path: &path) {
            return Set(path)
        }
        return []
    }

    private static func findAncestors<ID: Hashable & Sendable>(
        of targetID: ID,
        in nodes: [FMOutlineNode<ID>],
        path: inout [ID]
    ) -> Bool {
        for node in nodes {
            if node.id == targetID {
                return true
            }
            if let children = node.children, !children.isEmpty {
                path.append(node.id)
                if findAncestors(of: targetID, in: children, path: &path) {
                    return true
                }
                path.removeLast()
            }
        }
        return false
    }
}

/// Native Finder / Xcode-inspired hierarchical outline browser featuring `LazyVStack` virtualized
/// row rendering, subtle indentation guides, spring-rotating disclosure chevrons, and full keyboard navigation.
public struct FMOutlineTree<ID: Hashable & Sendable>: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    private let roots: [FMOutlineNode<ID>]
    @Binding private var selection: ID?
    @Binding private var expandedIDs: Set<ID>
    private let showsIndentGuides: Bool
    private let onDoubleClick: ((FMOutlineNode<ID>) -> Void)?

    @State private var hoveredID: ID?
    @FocusState private var isFocused: Bool

    /// Creates a hierarchical outline tree view.
    /// - Parameters:
    ///   - roots: Top-level nodes of the tree.
    ///   - selection: Currently selected node identifier.
    ///   - expandedIDs: Set of currently expanded container node identifiers.
    ///   - showsIndentGuides: Whether to draw subtle vertical indentation guide hairlines.
    ///   - onDoubleClick: Optional handler invoked when double-clicking or pressing Return on a row.
    public init(
        roots: [FMOutlineNode<ID>],
        selection: Binding<ID?>,
        expandedIDs: Binding<Set<ID>>,
        showsIndentGuides: Bool = true,
        onDoubleClick: ((FMOutlineNode<ID>) -> Void)? = nil
    ) {
        self.roots = roots
        self._selection = selection
        self._expandedIDs = expandedIDs
        self.showsIndentGuides = showsIndentGuides
        self.onDoubleClick = onDoubleClick
    }

    private var rowHeight: CGFloat {
        switch density {
        case .compact: 24
        case .regular: 28
        case .comfortable: 32
        }
    }

    private var indentStep: CGFloat {
        switch density {
        case .compact: 14
        case .regular: 16
        case .comfortable: 18
        }
    }

    public var body: some View {
        let rows = FMOutlineTreeMath.flatten(roots, expanded: expandedIDs)

        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(rows) { row in
                        outlineRowView(row)
                            .id(row.id)
                    }
                }
                .padding(.vertical, FMSpacing.xxs)
                .padding(.horizontal, FMSpacing.xxs)
            }
            .onChange(of: selection) { _, newSelection in
                guard let newSelection else { return }
                let animation = FMSpring.animation(
                    .micro,
                    reduceMotion: reduceMotion,
                    speed: theme.animationSpeed
                )
                withAnimation(animation) {
                    proxy.scrollTo(newSelection, anchor: nil)
                }
            }
            .focusable(isEnabled)
            .focused($isFocused)
            .focusEffectDisabled()
            .fmFocusRing(isFocused: isFocused, cornerRadius: FMCornerRadius.control)
            .onKeyPress(.upArrow) {
                guard isEnabled else { return .ignored }
                moveSelection(delta: -1, in: rows)
                return .handled
            }
            .onKeyPress(.downArrow) {
                guard isEnabled else { return .ignored }
                moveSelection(delta: 1, in: rows)
                return .handled
            }
            .onKeyPress(.rightArrow) {
                guard isEnabled else { return .ignored }
                let next = FMOutlineTreeMath.expandOrDescend(
                    from: selection,
                    in: rows,
                    expanded: expandedIDs
                )
                applyKeyboardTransition(next)
                return .handled
            }
            .onKeyPress(.leftArrow) {
                guard isEnabled else { return .ignored }
                let next = FMOutlineTreeMath.collapseOrAscend(
                    from: selection,
                    in: rows,
                    expanded: expandedIDs
                )
                applyKeyboardTransition(next)
                return .handled
            }
            .onKeyPress(.space) {
                guard isEnabled,
                      let current = selection,
                      let row = rows.first(where: { $0.id == current }),
                      row.isExpandable
                else { return .ignored }
                toggleExpansion(for: row.id)
                return .handled
            }
            .onKeyPress(.return) {
                guard isEnabled,
                      let current = selection,
                      let row = rows.first(where: { $0.id == current })
                else { return .ignored }
                if let onDoubleClick {
                    FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                    onDoubleClick(row.node)
                } else if row.isExpandable {
                    toggleExpansion(for: row.id)
                }
                return .handled
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Outline tree")
        }
    }

    @ViewBuilder
    private func outlineRowView(_ row: FMFlattenedOutlineRow<ID>) -> some View {
        let isSelected = selection == row.id
        let isHovered = hoveredID == row.id
        let cornerRadius = FMCornerRadius.micro * density.cornerScale
        let leadingPad: CGFloat = 8
        let guideColor = FMColor.separator(colorScheme, highContrast: contrast == .increased)
            .opacity(contrast == .increased ? 0.9 : 0.72)

        HStack(spacing: 6) {
            // Disclosure chevron slot (always aligned across siblings)
            Group {
                if row.isExpandable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .rotationEffect(row.isExpanded ? .degrees(90) : .zero)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard isEnabled else { return }
                            isFocused = true
                            toggleExpansion(for: row.id)
                        }
                        .fmAnimation(.micro, value: row.isExpanded)
                } else {
                    Color.clear
                        .frame(width: 16, height: 16)
                }
            }

            if let icon = row.node.icon {
                Image(systemName: icon)
                    .font(.system(size: density == .compact ? 12 : 13, weight: .medium))
                    .foregroundStyle(resolveIconColor(for: row.node))
                    .frame(width: 16)
                    .accessibilityHidden(true)
            }

            Text(row.node.title)
                .font(.system(
                    size: density == .compact ? 12.5 : 13,
                    weight: isSelected ? .medium : .regular
                ))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            if let subtitle = row.node.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.fmFootnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: FMSpacing.xs)

            if let badge = row.node.badge, !badge.isEmpty {
                Text(badge)
                    .font(.fmNumeric(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background {
                        Capsule(style: .continuous)
                            .fill(FMColor.controlFill(colorScheme))
                    }
            }
        }
        .padding(.leading, leadingPad + CGFloat(row.depth) * indentStep)
        .padding(.trailing, FMSpacing.xs)
        .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .leading)
        .background(alignment: .leading) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(rowBackground(isSelected: isSelected, isHovered: isHovered))

                if showsIndentGuides && row.depth > 0 {
                    ZStack(alignment: .leading) {
                        ForEach(0..<row.depth, id: \.self) { level in
                            Rectangle()
                                .fill(guideColor)
                                .frame(width: contrast == .increased ? 1.0 : 0.5)
                                .offset(x: leadingPad + CGFloat(level) * indentStep + 7.5)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .opacity(isEnabled ? 1.0 : 0.45)
        .onHover { hovering in
            hoveredID = hovering ? row.id : (hoveredID == row.id ? nil : hoveredID)
        }
        .onTapGesture {
            guard isEnabled else { return }
            isFocused = true
            let clickCount = NSApp.currentEvent?.clickCount ?? 1
            if selection != row.id {
                selection = row.id
                FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
            }
            if clickCount >= 2 {
                if let onDoubleClick {
                    onDoubleClick(row.node)
                } else if row.isExpandable {
                    toggleExpansion(for: row.id)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: row.node))
        .accessibilityValue(accessibilityValue(for: row))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityAction {
            guard isEnabled else { return }
            selection = row.id
            if let onDoubleClick {
                onDoubleClick(row.node)
            }
        }
        .modifier(
            FMOutlineDisclosureAccessibilityModifier(
                isExpandable: row.isExpandable,
                isExpanded: row.isExpanded,
                isEnabled: isEnabled
            ) {
                toggleExpansion(for: row.id)
            }
        )
    }

    private func rowBackground(isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected {
            return FMColor.sidebarSelection(colorScheme, activeState: activeState)
        }
        if isHovered && isEnabled {
            return FMColor.controlFill(colorScheme).opacity(0.6)
        }
        return .clear
    }

    private func resolveIconColor(for node: FMOutlineNode<ID>) -> Color {
        if let iconColor = node.iconColor {
            return FMColor.adaptiveAccent(iconColor, activeState: activeState, scheme: colorScheme)
        }
        if node.isContainer {
            return FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
        }
        return .secondary
    }

    private func toggleExpansion(for id: ID) {
        let animation = FMSpring.animation(
            .micro,
            reduceMotion: reduceMotion,
            speed: theme.animationSpeed
        )
        withAnimation(animation) {
            expandedIDs = FMOutlineTreeMath.toggleExpanded(id, in: expandedIDs)
        }
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
    }

    private func moveSelection(delta: Int, in rows: [FMFlattenedOutlineRow<ID>]) {
        guard let next = FMOutlineTreeMath.nextSelection(from: selection, in: rows, delta: delta),
              next != selection
        else { return }
        selection = next
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
    }

    private func applyKeyboardTransition(_ next: (selection: ID?, expanded: Set<ID>)) {
        let changedExpansion = next.expanded != expandedIDs
        let changedSelection = next.selection != selection
        guard changedExpansion || changedSelection else { return }

        let animation = FMSpring.animation(
            .micro,
            reduceMotion: reduceMotion,
            speed: theme.animationSpeed
        )
        withAnimation(animation) {
            expandedIDs = next.expanded
            selection = next.selection
        }
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
    }

    private func accessibilityLabel(for node: FMOutlineNode<ID>) -> String {
        var parts = [node.title]
        if let subtitle = node.subtitle, !subtitle.isEmpty {
            parts.append(subtitle)
        }
        if let badge = node.badge, !badge.isEmpty {
            parts.append(badge)
        }
        return parts.joined(separator: ", ")
    }

    private func accessibilityValue(for row: FMFlattenedOutlineRow<ID>) -> String {
        let levelText = "Level \(row.depth + 1)"
        if row.isExpandable {
            return row.isExpanded ? "Expanded, \(levelText)" : "Collapsed, \(levelText)"
        }
        return levelText
    }
}

private struct FMOutlineDisclosureAccessibilityModifier: ViewModifier {
    let isExpandable: Bool
    let isExpanded: Bool
    let isEnabled: Bool
    let toggle: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isExpandable {
            content.accessibilityAction(named: isExpanded ? "Collapse" : "Expand") {
                guard isEnabled else { return }
                toggle()
            }
        } else {
            content
        }
    }
}
