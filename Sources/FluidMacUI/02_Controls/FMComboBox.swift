import SwiftUI

/// Pure search filtering and selection state helpers for `FMComboBox`.
public enum FMComboBoxMath {
    /// Filters `items` by `query`, placing case-insensitive prefix matches before substring matches
    /// while preserving original relative order within each group.
    public static func filter<T>(_ items: [T], query: String, label: (T) -> String) -> [T] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return items }

        var prefixMatches: [T] = []
        var substringMatches: [T] = []
        for item in items {
            let text = label(item).lowercased()
            if text.hasPrefix(trimmed) {
                prefixMatches.append(item)
            } else if text.contains(trimmed) {
                substringMatches.append(item)
            }
        }
        return prefixMatches + substringMatches
    }

    /// Toggles `item` in `current` for multi-select, or replaces selection with `[item]` for single-select.
    public static func toggleSelection<T: Hashable>(
        _ item: T,
        in current: Set<T>,
        allowsMultiple: Bool
    ) -> Set<T> {
        if allowsMultiple {
            var next = current
            if next.contains(item) {
                next.remove(item)
            } else {
                next.insert(item)
            }
            return next
        } else {
            return [item]
        }
    }

    /// Safely clamps a keyboard highlight index into `0..<count` (returning `0` if empty).
    public static func clampedHighlightIndex(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(index, 0), count - 1)
    }
}

/// Searchable single-select and multi-select autocomplete picker with glass popover,
/// keyboard navigation (`↑`/`↓`/`↵`/`Esc`), capsule chips, and haptic feedback.
public struct FMComboBox<Option: Hashable>: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.isEnabled) private var isEnabled

    private let options: [Option]
    private let placeholder: String
    private let searchPlaceholder: String
    private let titleProvider: (Option) -> String
    private let iconProvider: ((Option) -> String?)?
    private let allowsMultiple: Bool
    private let getSelection: () -> Set<Option>
    private let setSelection: (Set<Option>) -> Void

    @State private var isExpanded = false
    @State private var isHovered = false
    @State private var query = ""
    @State private var highlightedIndex = 0
    @State private var hoveredOption: Option?
    @FocusState private var isTriggerFocused: Bool
    @FocusState private var isSearchFocused: Bool

    /// Creates a single-select searchable combo box.
    public init(
        selection: Binding<Option?>,
        options: [Option],
        placeholder: String = "Select...",
        searchPlaceholder: String = "Filter options...",
        title: @escaping (Option) -> String,
        icon: ((Option) -> String?)? = nil
    ) {
        self.options = options
        self.placeholder = placeholder
        self.searchPlaceholder = searchPlaceholder
        self.titleProvider = title
        self.iconProvider = icon
        self.allowsMultiple = false
        self.getSelection = {
            if let value = selection.wrappedValue {
                return [value]
            }
            return []
        }
        self.setSelection = { next in
            selection.wrappedValue = next.first
        }
    }

    /// Creates a multi-select searchable combo box with removable capsule chips.
    public init(
        selection: Binding<Set<Option>>,
        options: [Option],
        placeholder: String = "Select items...",
        searchPlaceholder: String = "Filter options...",
        title: @escaping (Option) -> String,
        icon: ((Option) -> String?)? = nil
    ) {
        self.options = options
        self.placeholder = placeholder
        self.searchPlaceholder = searchPlaceholder
        self.titleProvider = title
        self.iconProvider = icon
        self.allowsMultiple = true
        self.getSelection = { selection.wrappedValue }
        self.setSelection = { selection.wrappedValue = $0 }
    }

    private var accent: Color {
        FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
    }

    private var selectedSet: Set<Option> {
        getSelection()
    }

    private var orderedSelectedOptions: [Option] {
        options.filter { selectedSet.contains($0) }
    }

    private var filteredOptions: [Option] {
        FMComboBoxMath.filter(options, query: query, label: titleProvider)
    }

    public var body: some View {
        let radius = FMCornerRadius.control * density.cornerScale
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let triggerFill: Color = {
            if reduceTransparency {
                return FMColor.elevatedOpaqueSurface(colorScheme)
            }
            return (isHovered || isExpanded) ? FMColor.controlHoverFill(colorScheme) : FMColor.controlFill(colorScheme)
        }()

        HStack(spacing: FMSpacing.xs) {
            triggerContent

            Spacer(minLength: 4)

            if !selectedSet.isEmpty && isEnabled {
                Button {
                    clearSelection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .accessibilityLabel("Clear selection")
            }

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, FMSpacing.sm)
        .frame(minHeight: density.controlHeight)
        .background(triggerFill, in: shape)
        .overlay {
            shape.strokeBorder(
                isExpanded ? accent.opacity(0.75) : FMColor.hairlineHighlight(colorScheme),
                lineWidth: isExpanded ? 1.25 : 0.75
            )
        }
        .contentShape(shape)
        .onTapGesture {
            toggleExpanded()
        }
        .opacity(isEnabled ? 1.0 : 0.45)
        .focusable(isEnabled)
        .focused($isTriggerFocused)
        .focusEffectDisabled()
        .fmFocusRing(isFocused: isTriggerFocused, cornerRadius: FMCornerRadius.control)
        .onKeyPress(keys: [.return, .space]) { _ in
            toggleExpanded()
            return .handled
        }
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(placeholder)
        .accessibilityValue(triggerAccessibilityValue)
        .fmAnimation(.micro, value: isExpanded)
        .fmAnimation(.micro, value: isHovered)
        .popover(isPresented: $isExpanded, arrowEdge: .bottom) {
            popoverContent
                .frame(width: 272)
                .onAppear {
                    query = ""
                    highlightedIndex = 0
                    isSearchFocused = true
                }
        }
    }

    private var triggerAccessibilityValue: String {
        let selected = orderedSelectedOptions
        if selected.isEmpty { return "None selected" }
        return selected.map(titleProvider).joined(separator: ", ")
    }

    @ViewBuilder
    private var triggerContent: some View {
        let selected = orderedSelectedOptions
        if selected.isEmpty {
            Text(placeholder)
                .font(.fmControl)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else if !allowsMultiple, let first = selected.first {
            HStack(spacing: FMSpacing.xs) {
                if let icon = iconProvider?(first) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                }
                Text(titleProvider(first))
                    .font(.fmControl)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        } else {
            HStack(spacing: 4) {
                ForEach(Array(selected.prefix(3)), id: \.self) { item in
                    HStack(spacing: 3) {
                        Text(titleProvider(item))
                            .font(.fmCaption)
                            .foregroundStyle(accent)
                            .lineLimit(1)

                        if isEnabled {
                            Button {
                                toggleOption(item)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundStyle(accent.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                            .focusEffectDisabled()
                            .accessibilityLabel("Remove \(titleProvider(item))")
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(accent.opacity(colorScheme == .dark ? 0.22 : 0.12), in: Capsule(style: .continuous))
                }

                if selected.count > 3 {
                    Text("+\(selected.count - 3)")
                        .font(.fmCaption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(FMColor.controlFill(colorScheme), in: Capsule(style: .continuous))
                }
            }
        }
    }

    private var popoverContent: some View {
        let items = filteredOptions

        return VStack(spacing: 0) {
            // Search header
            HStack(spacing: FMSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField(searchPlaceholder, text: $query)
                    .textFieldStyle(.plain)
                    .font(.fmBody)
                    .focused($isSearchFocused)
                    .focusEffectDisabled()
                    .onSubmit {
                        selectHighlighted()
                    }

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, FMSpacing.sm)
            .frame(height: 36)

            Rectangle()
                .fill(FMColor.separator(colorScheme))
                .frame(height: 0.75)

            if items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundStyle(.tertiary)
                    Text("No matching options")
                        .font(.fmFootnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(items.enumerated()), id: \.offset) { index, option in
                                let isSelected = selectedSet.contains(option)
                                let isHighlighted = index == highlightedIndex || hoveredOption == option

                                Button {
                                    toggleOption(option)
                                    if !allowsMultiple {
                                        isExpanded = false
                                    }
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
                                            .lineLimit(1)

                                        Spacer(minLength: FMSpacing.sm)

                                        if isSelected {
                                            Image(systemName: allowsMultiple ? "checkmark.circle.fill" : "checkmark")
                                                .font(.system(size: allowsMultiple ? 14 : 12, weight: .bold))
                                                .foregroundStyle(accent)
                                        }
                                    }
                                    .padding(.horizontal, FMSpacing.sm)
                                    .frame(height: max(30, density.controlHeight - 4))
                                    .background(
                                        isHighlighted
                                            ? accent.opacity(colorScheme == .dark ? 0.20 : 0.12)
                                            : (isSelected ? FMColor.controlFill(colorScheme) : .clear),
                                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .focusEffectDisabled()
                                .id(index)
                                .accessibilityLabel(titleProvider(option))
                                .accessibilityAddTraits(isSelected ? .isSelected : [])
                                .onHover { hovering in
                                    if hovering {
                                        hoveredOption = option
                                        highlightedIndex = index
                                    } else if hoveredOption == option {
                                        hoveredOption = nil
                                    }
                                }
                            }
                        }
                        .padding(6)
                    }
                    .frame(maxHeight: 260)
                    .onChange(of: query) { _, _ in
                        highlightedIndex = 0
                    }
                    .onChange(of: highlightedIndex) { _, newIndex in
                        withAnimation(nil) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }

            if allowsMultiple && !selectedSet.isEmpty {
                Rectangle()
                    .fill(FMColor.separator(colorScheme))
                    .frame(height: 0.75)

                HStack {
                    Text("\(selectedSet.count) selected")
                        .font(.fmFootnote)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Clear all") {
                        clearSelection()
                    }
                    .buttonStyle(.plain)
                    .font(.fmCaption)
                    .foregroundStyle(accent)
                    .focusEffectDisabled()
                }
                .padding(.horizontal, FMSpacing.sm)
                .frame(height: 32)
            }
        }
        .onKeyPress(.downArrow) {
            let count = filteredOptions.count
            guard count > 0 else { return .ignored }
            highlightedIndex = FMComboBoxMath.clampedHighlightIndex(highlightedIndex + 1, count: count)
            return .handled
        }
        .onKeyPress(.upArrow) {
            let count = filteredOptions.count
            guard count > 0 else { return .ignored }
            highlightedIndex = FMComboBoxMath.clampedHighlightIndex(highlightedIndex - 1, count: count)
            return .handled
        }
        .onKeyPress(.escape) {
            isExpanded = false
            return .handled
        }
    }

    private func toggleExpanded() {
        guard isEnabled else { return }
        isExpanded.toggle()
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
    }

    private func toggleOption(_ option: Option) {
        let next = FMComboBoxMath.toggleSelection(option, in: selectedSet, allowsMultiple: allowsMultiple)
        setSelection(next)
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
    }

    private func selectHighlighted() {
        let items = filteredOptions
        guard !items.isEmpty else { return }
        let idx = FMComboBoxMath.clampedHighlightIndex(highlightedIndex, count: items.count)
        toggleOption(items[idx])
        if !allowsMultiple {
            isExpanded = false
        }
    }

    private func clearSelection() {
        setSelection([])
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
    }
}

public extension FMComboBox where Option: CustomStringConvertible {
    /// Convenience single-select initializer using `CustomStringConvertible.description`.
    init(
        selection: Binding<Option?>,
        options: [Option],
        placeholder: String = "Select...",
        searchPlaceholder: String = "Filter options..."
    ) {
        self.init(
            selection: selection,
            options: options,
            placeholder: placeholder,
            searchPlaceholder: searchPlaceholder,
            title: { $0.description }
        )
    }

    /// Convenience multi-select initializer using `CustomStringConvertible.description`.
    init(
        selection: Binding<Set<Option>>,
        options: [Option],
        placeholder: String = "Select items...",
        searchPlaceholder: String = "Filter options..."
    ) {
        self.init(
            selection: selection,
            options: options,
            placeholder: placeholder,
            searchPlaceholder: searchPlaceholder,
            title: { $0.description }
        )
    }
}
