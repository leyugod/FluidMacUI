import SwiftUI

/// Icon rendering mode inside `FMSidebarSplitView`.
public enum FMSidebarIconStyle: Sendable, Hashable {
    /// Native macOS refined SF Symbol icon (matches App Store, Finder, Mail).
    case symbol
    /// iOS Settings-style squircle `FMIconBadge`.
    case badge
}

/// Descriptor for a single item inside `FMSidebarSplitView`.
public struct FMSidebarItem<Selection: Hashable>: Identifiable {
    public let id: Selection
    public let title: String
    public let icon: String
    public let iconColor: Color?
    public let badge: String?

    public init(
        id: Selection,
        title: String,
        icon: String,
        iconColor: Color? = nil,
        badge: String? = nil
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.badge = badge
    }
}

/// Optional grouped section inside `FMSidebarSplitView`.
public struct FMSidebarSection<Selection: Hashable>: Identifiable {
    public let id: String
    public let title: String?
    public let items: [FMSidebarItem<Selection>]

    public init(
        id: String? = nil,
        title: String? = nil,
        items: [FMSidebarItem<Selection>]
    ) {
        self.id = id ?? title ?? UUID().uuidString
        self.title = title
        self.items = items
    }
}

private struct FMLeadingToolbarInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

public extension EnvironmentValues {
    /// Extra leading clearance required by detail toolbars (e.g., when the sidebar is collapsed
    /// and the traffic lights + sidebar expand button occupy the top-left corner).
    var fmLeadingToolbarInset: CGFloat {
        get { self[FMLeadingToolbarInsetKey.self] }
        set { self[FMLeadingToolbarInsetKey.self] = newValue }
    }
}

/// Compact capsule search field tailored for the top of macOS sidebars (directly below traffic lights).
public struct FMSidebarSearchField: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.fmTheme) private var theme
    @Environment(\.controlActiveState) private var activeState

    @Binding private var text: String
    private let placeholder: String

    @FocusState private var isFocused: Bool
    @State private var didAppear = false

    public init(text: Binding<String>, placeholder: String = "Search") {
        self._text = text
        self.placeholder = placeholder
    }

    public var body: some View {
        let accent = FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
        let activeFocus = isFocused && didAppear

        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFocused)
                .focusEffectDisabled()
                .onKeyPress(.escape) {
                    text = ""
                    isFocused = false
                    return .handled
                }

            if !text.isEmpty {
                Button {
                    text = ""
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
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            colorScheme == .dark ? Color.white.opacity(0.095) : Color.black.opacity(0.065),
            in: Capsule(style: .continuous)
        )
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(
                    activeFocus ? accent.opacity(0.75) : FMColor.hairlineHighlight(colorScheme),
                    lineWidth: activeFocus ? 1.25 : 0.5
                )
        }
        .task {
            // Prevent macOS from auto-focusing the sidebar search bar with a ring on initial window launch.
            isFocused = false
            didAppear = true
        }
        .fmAnimation(.micro, value: activeFocus)
    }
}

/// Clean single-row profile / account anchor for the bottom of a macOS sidebar (matching App Store & Settings).
public struct FMSidebarAccountFooter: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.fmTheme) private var theme

    private let name: String
    private let subtitle: String?
    private let systemIcon: String
    private let initials: String?
    private let action: (() -> Void)?

    @State private var isHovered = false

    public init(
        name: String,
        subtitle: String? = nil,
        systemIcon: String = "person.crop.circle.fill",
        initials: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.name = name
        self.subtitle = subtitle
        self.systemIcon = systemIcon
        self.initials = initials
        self.action = action
    }

    public var body: some View {
        Button {
            FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
            action?()
        } label: {
            HStack(spacing: 10) {
                if let initials, !initials.isEmpty {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [theme.accentColor.opacity(0.85), theme.accentColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                        .overlay {
                            Text(initials)
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                } else {
                    Image(systemName: systemIcon)
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                isHovered ? FMColor.controlFill(colorScheme) : .clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { isHovered = $0 }
        .fmAnimation(.micro, value: isHovered)
    }
}

/// Native macOS split view featuring a full-height Apple-native sidebar enclosing
/// the window traffic lights with a top-right sidebar collapse toggle on the same row
/// and automatic collapsed-state expand button beside traffic lights.
public struct FMSidebarSplitView<Selection: Hashable, SidebarFooter: View, Detail: View>: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.fmWindowState) private var windowState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @Binding private var selection: Selection
    @Binding private var isSidebarVisible: Bool
    private let showsSidebarToggle: Bool
    private let searchText: Binding<String>?
    private let searchPlaceholder: String
    private let iconStyle: FMSidebarIconStyle
    private let sidebarWidth: CGFloat
    private let headerTitle: String?
    private let sections: [FMSidebarSection<Selection>]
    private let sidebarFooter: SidebarFooter
    private let detail: Detail

    @Namespace private var selectionNamespace
    @State private var hoveredItem: Selection?
    @FocusState private var focusedItem: Selection?

    public init(
        selection: Binding<Selection>,
        isSidebarVisible: Binding<Bool> = .constant(true),
        showsSidebarToggle: Bool = true,
        searchText: Binding<String>? = nil,
        searchPlaceholder: String = "Search",
        iconStyle: FMSidebarIconStyle = .symbol,
        sidebarWidth: CGFloat = 224,
        headerTitle: String? = nil,
        sections: [FMSidebarSection<Selection>],
        @ViewBuilder sidebarFooter: () -> SidebarFooter,
        @ViewBuilder detail: () -> Detail
    ) {
        self._selection = selection
        self._isSidebarVisible = isSidebarVisible
        self.showsSidebarToggle = showsSidebarToggle
        self.searchText = searchText
        self.searchPlaceholder = searchPlaceholder
        self.iconStyle = iconStyle
        self.sidebarWidth = sidebarWidth
        self.headerTitle = headerTitle
        self.sections = sections
        self.sidebarFooter = sidebarFooter()
        self.detail = detail()
    }

    private var collapsedDetailLeadingInset: CGFloat {
        guard !isSidebarVisible else { return 0 }
        let traffic = windowState.isFullScreen ? 0 : windowState.trafficLightsWidth
        let toggleWidth: CGFloat = showsSidebarToggle ? 38 : 0
        return traffic + toggleWidth
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                if isSidebarVisible {
                    sidebarContainer
                        .frame(width: sidebarWidth)
                        .transition(.move(edge: .leading).combined(with: .opacity))

                    Rectangle()
                        .fill(FMColor.separator(colorScheme, highContrast: contrast == .increased))
                        .frame(width: contrast == .increased ? 1.0 : 0.5)
                        .ignoresSafeArea()
                }

                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environment(\.fmLeadingToolbarInset, collapsedDetailLeadingInset)
            }

            // When collapsed, place the sidebar expand toggle natively beside the macOS traffic lights.
            if !isSidebarVisible && showsSidebarToggle {
                HStack(spacing: 0) {
                    Spacer().frame(width: windowState.isFullScreen ? 14 : max(76, windowState.trafficLightsWidth))
                    FMToolbarButton(icon: "sidebar.left", diameter: 30) {
                        isSidebarVisible = true
                    }
                    .accessibilityLabel("Show Sidebar")
                    .fmTooltip("Show Sidebar", shortcut: ["⌥", "⌘", "S"], edge: .bottom)
                }
                .frame(height: 46)
                .zIndex(60)
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .fmAnimation(.navigation, value: isSidebarVisible)
    }

    @ViewBuilder
    private var sidebarContainer: some View {
        sidebarCoreContent
            .background {
                ZStack {
                    FMColor.sidebarBackground(colorScheme)
                    if !reduceTransparency {
                        Rectangle().fill(.ultraThinMaterial).opacity(colorScheme == .dark ? 0.35 : 0.55)
                    }
                }
                .ignoresSafeArea()
            }
    }

    @ViewBuilder
    private var sidebarCoreContent: some View {
        let accent = FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)

        VStack(alignment: .leading, spacing: 0) {
            // Top bar row aligned horizontally with the macOS red/yellow/green traffic lights (44pt height).
            ZStack {
                FMTitleBarDragArea()

                HStack(spacing: 6) {
                    Spacer()
                    if showsSidebarToggle {
                        sidebarCollapseButton
                            .padding(.trailing, 10)
                    }
                }
            }
            .frame(height: 44)

            if let headerTitle, !headerTitle.isEmpty {
                Text(headerTitle)
                    .font(.fmHeadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }

            if let searchText {
                FMSidebarSearchField(text: searchText, placeholder: searchPlaceholder)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: FMSpacing.md) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 2) {
                            if let title = section.title, !title.isEmpty {
                                Text(title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 12)
                                    .padding(.bottom, 3)
                            }

                            ForEach(section.items) { item in
                                sidebarRow(item: item, accent: accent)
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)

            sidebarFooter
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
                .padding(.top, 6)
        }
        .fmAnimation(.navigation, value: selection)
        .fmAnimation(.micro, value: hoveredItem)
    }

    private var sidebarCollapseButton: some View {
        SidebarToggleIconButton {
            FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
            isSidebarVisible = false
        }
        .accessibilityLabel("Hide Sidebar")
        .fmTooltip("Hide Sidebar", shortcut: ["⌥", "⌘", "S"], edge: .bottom)
    }

    @ViewBuilder
    private func sidebarRow(item: FMSidebarItem<Selection>, accent: Color) -> some View {
        let isSelected = selection == item.id
        let isHovered = hoveredItem == item.id && !isSelected
        let itemRadius: CGFloat = 8.5
        let symbolTint = FMColor.adaptiveAccent(
            item.iconColor ?? accent,
            activeState: activeState,
            scheme: colorScheme
        )

        Button {
            guard selection != item.id else { return }
            selection = item.id
            FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
        } label: {
            HStack(spacing: 10) {
                switch iconStyle {
                case .symbol:
                    Image(systemName: item.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(symbolTint)
                        .frame(width: 20, alignment: .center)

                case .badge:
                    FMIconBadge(item.icon, color: item.iconColor ?? accent, size: 22)
                }

                Text(item.title)
                    .font(.system(size: 13.5, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.86))
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let badge = item.badge, !badge.isEmpty {
                    Text(badge)
                        .font(.fmNumeric(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.primary.opacity(0.88) : Color.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1.5)
                        .background(
                            colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08),
                            in: Capsule(style: .continuous)
                        )
                }
            }
            .padding(.horizontal, 10)
            .frame(height: max(32, density.controlHeight - 3))
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: itemRadius, style: .continuous)
                        .fill(FMColor.sidebarSelection(colorScheme, activeState: activeState))
                        .matchedGeometryEffect(id: "fm-sidebar-selection", in: selectionNamespace)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: itemRadius, style: .continuous)
                        .fill(FMColor.controlFill(colorScheme).opacity(0.65))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: itemRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .focused($focusedItem, equals: item.id)
        .focusEffectDisabled()
        .fmFocusRing(isFocused: focusedItem == item.id, cornerRadius: itemRadius)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { hovering in
            hoveredItem = hovering ? item.id : (hoveredItem == item.id ? nil : hoveredItem)
        }
    }
}

private struct SidebarToggleIconButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var isPressed = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(isHovered ? Color.primary : Color.secondary)
                .frame(width: 28, height: 28)
                .background(
                    isHovered ? FMColor.controlFill(colorScheme) : .clear,
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .scaleEffect(isPressed ? 0.90 : 1.0)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .fmAnimation(.micro, value: isHovered)
        .fmAnimation(.micro, value: isPressed)
    }
}

public extension FMSidebarSplitView where SidebarFooter == EmptyView {
    init(
        selection: Binding<Selection>,
        isSidebarVisible: Binding<Bool> = .constant(true),
        showsSidebarToggle: Bool = true,
        searchText: Binding<String>? = nil,
        searchPlaceholder: String = "Search",
        iconStyle: FMSidebarIconStyle = .symbol,
        sidebarWidth: CGFloat = 224,
        headerTitle: String? = nil,
        sections: [FMSidebarSection<Selection>],
        @ViewBuilder detail: () -> Detail
    ) {
        self.init(
            selection: selection,
            isSidebarVisible: isSidebarVisible,
            showsSidebarToggle: showsSidebarToggle,
            searchText: searchText,
            searchPlaceholder: searchPlaceholder,
            iconStyle: iconStyle,
            sidebarWidth: sidebarWidth,
            headerTitle: headerTitle,
            sections: sections,
            sidebarFooter: { EmptyView() },
            detail: detail
        )
    }
}
