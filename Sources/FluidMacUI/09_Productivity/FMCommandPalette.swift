import SwiftUI

/// Command entry rendered inside `FMCommandPalette`.
public struct FMCommandItem: Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let icon: String
    public let group: String
    public let shortcut: [String]
    public let keywords: [String]
    public let action: () -> Void

    public init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String? = nil,
        icon: String = "command",
        group: String = "常规",
        shortcut: [String] = [],
        keywords: [String] = [],
        action: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.group = group
        self.shortcut = shortcut
        self.keywords = keywords
        self.action = action
    }
}

/// Ordered group of command items for section rendering in `FMCommandPalette`.
public struct FMCommandGroup: Identifiable {
    public let id: String
    public let title: String
    public let items: [FMCommandItem]

    public init(title: String, items: [FMCommandItem]) {
        self.id = title
        self.title = title
        self.items = items
    }
}

/// Pure fuzzy/substring search filter and stable grouping helpers for `FMCommandPalette` (unit-tested).
public enum FMCommandMatcher {
    public static func filter(_ commands: [FMCommandItem], query: String) -> [FMCommandItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return commands }
        return commands.filter { item in
            item.title.lowercased().contains(trimmed)
                || (item.subtitle?.lowercased().contains(trimmed) ?? false)
                || item.group.lowercased().contains(trimmed)
                || item.keywords.contains(where: { $0.lowercased().contains(trimmed) })
        }
    }

    /// Groups items by `FMCommandItem.group` while preserving first-seen group order.
    public static func grouped(_ commands: [FMCommandItem]) -> [FMCommandGroup] {
        var order: [String] = []
        var buckets: [String: [FMCommandItem]] = [:]
        for item in commands {
            if buckets[item.group] == nil {
                order.append(item.group)
                buckets[item.group] = []
            }
            buckets[item.group, default: []].append(item)
        }
        return order.compactMap { key in
            guard let items = buckets[key], !items.isEmpty else { return nil }
            return FMCommandGroup(title: key, items: items)
        }
    }
}

/// Spotlight / Linear-style `⌘K` floating Liquid Glass command palette with keyboard navigation,
/// grouped suggestions, shortcut keycaps, and haptic execution feedback.
public struct FMCommandPaletteModifier: ViewModifier {
    @Environment(\.fmTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding private var isPresented: Bool
    private let placeholder: String
    private let commands: [FMCommandItem]

    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var searchFocused: Bool

    public init(
        isPresented: Binding<Bool>,
        placeholder: String = "输入命令或搜索功能...",
        commands: [FMCommandItem]
    ) {
        self._isPresented = isPresented
        self.placeholder = placeholder
        self.commands = commands
    }

    private var filtered: [FMCommandItem] {
        FMCommandMatcher.filter(commands, query: query)
    }

    private var groupedFiltered: [FMCommandGroup] {
        FMCommandMatcher.grouped(filtered)
    }

    private var flattenedOrder: [FMCommandItem] {
        groupedFiltered.flatMap(\.items)
    }

    public func body(content: Content) -> some View {
        let accent = FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
        let groups = groupedFiltered
        let ordered = flattenedOrder
        let indexByID = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($0.element.id, $0.offset) })
        let showsGroupHeaders = groups.count > 1 || (groups.first?.title.isEmpty == false)

        ZStack {
            content

            if isPresented {
                Color.black.opacity(colorScheme == .dark ? 0.45 : 0.22)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }
                    .transition(.opacity)
                    .zIndex(850)

                VStack(spacing: 0) {
                    Spacer().frame(height: 84)

                    VStack(spacing: 0) {
                        HStack(spacing: FMSpacing.sm) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.secondary)

                            TextField(placeholder, text: $query)
                                .textFieldStyle(.plain)
                                .font(.system(size: 16, weight: .regular))
                                .focused($searchFocused)
                                .focusEffectDisabled()
                                .onSubmit { executeSelected() }

                            FMKeycap("Esc")
                        }
                        .padding(.horizontal, FMSpacing.md)
                        .frame(height: 52)

                        FMHairlineDivider()

                        if ordered.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.tertiary)
                                Text("未找到匹配「\(query)」的命令")
                                    .font(.fmSubheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                        } else {
                            ScrollViewReader { scrollProxy in
                                ScrollView {
                                    LazyVStack(alignment: .leading, spacing: 2) {
                                        ForEach(groups) { group in
                                            if showsGroupHeaders {
                                                Text(group.title)
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundStyle(.tertiary)
                                                    .padding(.horizontal, 12)
                                                    .padding(.top, 8)
                                                    .padding(.bottom, 3)
                                            }

                                            ForEach(group.items) { item in
                                                let index = indexByID[item.id] ?? 0
                                                let isSelected = index == selectedIndex
                                                Button {
                                                    execute(item)
                                                } label: {
                                                    HStack(spacing: FMSpacing.sm) {
                                                        Image(systemName: item.icon)
                                                            .font(.system(size: 14, weight: .medium))
                                                            .foregroundStyle(isSelected ? accent : .secondary)
                                                            .frame(width: 22)

                                                        VStack(alignment: .leading, spacing: 1) {
                                                            Text(item.title)
                                                                .font(.fmBody)
                                                                .foregroundStyle(.primary)
                                                            if let subtitle = item.subtitle, !subtitle.isEmpty {
                                                                Text(subtitle)
                                                                    .font(.fmFootnote)
                                                                    .foregroundStyle(.secondary)
                                                            }
                                                        }

                                                        Spacer()

                                                        if !item.shortcut.isEmpty {
                                                            FMKeycap(keys: item.shortcut)
                                                        }
                                                    }
                                                    .padding(.horizontal, 12)
                                                    .frame(height: 40)
                                                    .background(
                                                        isSelected ? FMColor.sidebarSelection(colorScheme, activeState: activeState) : .clear,
                                                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                                                    )
                                                    .contentShape(Rectangle())
                                                }
                                                .id(item.id)
                                                .buttonStyle(.plain)
                                                .focusEffectDisabled()
                                                .onHover { hovering in
                                                    if hovering { selectedIndex = index }
                                                }
                                            }
                                        }
                                    }
                                    .padding(8)
                                }
                                .frame(maxHeight: 320)
                                .onChange(of: selectedIndex) { _, newIndex in
                                    if ordered.indices.contains(newIndex) {
                                        scrollProxy.scrollTo(ordered[newIndex].id)
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: 560)
                    .fmGlassSurface(.regular, cornerRadius: 18, showShadow: true)
                    .onKeyPress(.upArrow) {
                        moveSelection(by: -1)
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        moveSelection(by: 1)
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        dismiss()
                        return .handled
                    }
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.96, anchor: .top).combined(with: .opacity))

                    Spacer()
                }
                .zIndex(860)
                .background {
                    Button("") { dismiss() }
                        .keyboardShortcut(.escape, modifiers: [])
                        .opacity(0)
                        .frame(width: 0, height: 0)
                        .accessibilityHidden(true)
                }
            }
        }
        .fmAnimation(.micro, value: isPresented)
        .onChange(of: isPresented) { _, presented in
            if presented {
                query = ""
                selectedIndex = 0
                searchFocused = true
                FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
            }
        }
        .onChange(of: query) { _, _ in
            selectedIndex = 0
        }
    }

    private func moveSelection(by delta: Int) {
        let count = flattenedOrder.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + delta + count) % count
    }

    private func executeSelected() {
        let ordered = flattenedOrder
        guard ordered.indices.contains(selectedIndex) else { return }
        execute(ordered[selectedIndex])
    }

    private func execute(_ item: FMCommandItem) {
        FMHaptics.perform(.levelChange, enabled: theme.hapticsEnabled)
        isPresented = false
        item.action()
    }

    private func dismiss() {
        isPresented = false
    }
}

public extension View {
    /// Attaches a `⌘K`-ready Spotlight-style Liquid Glass command palette overlay.
    func fmCommandPalette(
        isPresented: Binding<Bool>,
        placeholder: String = "输入命令或搜索功能...",
        commands: [FMCommandItem]
    ) -> some View {
        modifier(
            FMCommandPaletteModifier(
                isPresented: isPresented,
                placeholder: placeholder,
                commands: commands
            )
        )
    }
}
