import SwiftUI

/// Presentation style for `FMNavigationStack`'s top navigation chrome.
public enum FMNavigationHeaderStyle: Sendable, Hashable {
    /// Apple macOS 26 App Store / Music style: transparent floating circular glass `<` & toolbar buttons
    /// flush at the top edge (`y = 0`, `46pt` height); content blurs beneath on scroll and title fades in.
    case floating
    /// Always shows a compact centered title in the top toolbar bar.
    case inline
    /// Shows an editorial large title that collapses into the top toolbar bar as you scroll.
    case large
}

/// Type-erased route entry managed by `FMNavigationController`.
public struct FMNavigationEntry: Identifiable {
    public let id: UUID
    public let title: String
    public let subtitle: String?
    public let routeKey: AnyHashable?
    let makeView: () -> AnyView

    public init<V: View>(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        routeKey: AnyHashable? = nil,
        @ViewBuilder content: @escaping () -> V
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.routeKey = routeKey
        self.makeView = { AnyView(content()) }
    }
}

/// Observable router powering `FMNavigationStack` with push, pop, popToRoot,
/// and interactive trackpad swipe-back progress tracking.
@Observable
public final class FMNavigationController {
    public private(set) var entries: [FMNavigationEntry] = []
    public var swipeOffset: CGFloat = 0
    public var isSwipingBack: Bool = false

    public init() {}

    /// Number of pushed destinations above the root view.
    public var depth: Int { entries.count }

    /// Whether there is at least one destination that can be popped.
    public var canPop: Bool { !entries.isEmpty }

    /// Title of the currently visible top destination, or nil if at root.
    public var topTitle: String? { entries.last?.title }

    /// Pushes a new SwiftUI destination onto the navigation stack.
    @discardableResult
    public func push<V: View>(
        title: String,
        subtitle: String? = nil,
        routeKey: AnyHashable? = nil,
        @ViewBuilder content: @escaping () -> V
    ) -> UUID {
        let entry = FMNavigationEntry(
            title: title,
            subtitle: subtitle,
            routeKey: routeKey,
            content: content
        )
        entries.append(entry)
        return entry.id
    }

    /// Pops the top-most destination if available.
    @discardableResult
    public func pop() -> FMNavigationEntry? {
        guard !entries.isEmpty else { return nil }
        return entries.removeLast()
    }

    /// Pops up to `count` destinations.
    public func pop(count: Int) {
        guard count > 0, !entries.isEmpty else { return }
        let removeCount = min(count, entries.count)
        entries.removeLast(removeCount)
    }

    /// Pops all destinations back to the root view.
    public func popToRoot() {
        guard !entries.isEmpty else { return }
        entries.removeAll()
    }

    /// Replaces the top destination or pushes if currently at root.
    @discardableResult
    public func replaceTop<V: View>(
        title: String,
        subtitle: String? = nil,
        routeKey: AnyHashable? = nil,
        @ViewBuilder content: @escaping () -> V
    ) -> UUID {
        if !entries.isEmpty {
            entries.removeLast()
        }
        return push(title: title, subtitle: subtitle, routeKey: routeKey, content: content)
    }

    /// Evaluates whether a trackpad swipe release should commit the pop transition.
    public static func shouldCommitSwipeBack(
        translation: CGFloat,
        velocity: CGFloat,
        containerWidth: CGFloat
    ) -> Bool {
        let width = max(1, containerWidth)
        return translation > width * 0.28 || (translation > 48 && velocity > 320)
    }
}

private struct FMNavigationControllerKey: EnvironmentKey {
    static let defaultValue = FMNavigationController()
}

private struct FMSwipeBackDisabledKey: EnvironmentKey {
    static let defaultValue = false
}

/// Upward preference key allowing nested horizontal carousels or canvases to disable
/// parent `FMNavigationStack` trackpad swipe-back gestures.
public struct FMSwipeBackDisabledPreferenceKey: PreferenceKey {
    public static let defaultValue: Bool = false

    public static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

public extension EnvironmentValues {
    /// Nearest `FMNavigationStack`'s controller for programmatic push/pop.
    var fmNavigator: FMNavigationController {
        get { self[FMNavigationControllerKey.self] }
        set { self[FMNavigationControllerKey.self] = newValue }
    }

    /// Controls whether trackpad swipe-back is disabled inside the current subtree.
    var fmSwipeBackDisabled: Bool {
        get { self[FMSwipeBackDisabledKey.self] }
        set { self[FMSwipeBackDisabledKey.self] = newValue }
    }
}

public extension View {
    /// Disables trackpad swipe-back within this view hierarchy (propagating both downward via environment
    /// and upward to enclosing `FMNavigationStack` containers via `FMSwipeBackDisabledPreferenceKey`).
    func fmSwipeBackDisabled(_ disabled: Bool = true) -> some View {
        self
            .environment(\.fmSwipeBackDisabled, disabled)
            .preference(key: FMSwipeBackDisabledPreferenceKey.self, value: disabled)
    }
}

/// Native macOS 26 parallax navigation stack with full-bleed opaque page canvases,
/// top-flush (`y = 0`, `46pt`) Liquid Glass toolbar aligned with traffic lights,
/// real translucent blurred scroll-under toolbar, two-finger trackpad swipe-back, and `⌘[`.
public struct FMNavigationStack<Root: View, LeadingBar: View, ScrolledAccessory: View, TrailingBar: View>: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.fmSwipeBackDisabled) private var swipeBackDisabled
    @Environment(\.fmLeadingToolbarInset) private var leadingToolbarInset

    @State private var internalController: FMNavigationController
    private let externalController: FMNavigationController?
    private let rootTitle: String
    private let rootSubtitle: String?
    private let titleIcon: String?
    private let titleIconColor: Color
    private let headerStyle: FMNavigationHeaderStyle
    private let leadingBar: LeadingBar
    private let scrolledAccessory: ScrolledAccessory
    private let trailingBar: TrailingBar
    private let root: Root

    @State private var pageScrollOffsets: [String: CGFloat] = [:]
    @State private var childDisablesSwipeBack = false
    @State private var crossedSwipeThreshold = false

    private let toolbarHeight: CGFloat = 46

    private var controller: FMNavigationController {
        externalController ?? internalController
    }

    private var activePageKey: String {
        controller.entries.last?.id.uuidString ?? "root"
    }

    private var activeScrollOffset: CGFloat {
        pageScrollOffsets[activePageKey] ?? 0
    }

    private var navigationAnimation: Animation {
        FMSpring.animation(.navigation, reduceMotion: reduceMotion, speed: theme.animationSpeed)
    }

    public init(
        controller: FMNavigationController? = nil,
        title: String,
        subtitle: String? = nil,
        titleIcon: String? = nil,
        titleIconColor: Color = FMColor.blue,
        headerStyle: FMNavigationHeaderStyle = .floating,
        @ViewBuilder leadingBar: () -> LeadingBar,
        @ViewBuilder scrolledAccessory: () -> ScrolledAccessory,
        @ViewBuilder trailingBar: () -> TrailingBar,
        @ViewBuilder root: () -> Root
    ) {
        self.externalController = controller
        self._internalController = State(initialValue: controller ?? FMNavigationController())
        self.rootTitle = title
        self.rootSubtitle = subtitle
        self.titleIcon = titleIcon
        self.titleIconColor = titleIconColor
        self.headerStyle = headerStyle
        self.leadingBar = leadingBar()
        self.scrolledAccessory = scrolledAccessory()
        self.trailingBar = trailingBar()
        self.root = root()
    }

    public var body: some View {
        let nav = controller
        let depth = nav.depth

        GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            let progress = nav.isSwipingBack ? min(max(nav.swipeOffset / width, 0), 1) : 0

            ZStack(alignment: .top) {
                // Full-height page stack (opaque canvases — zero bleed-through!).
                ZStack {
                    pageSurface(isRoot: true, pageKey: "root") {
                        root
                    }
                    .offset(x: pageOffset(index: 0, totalCount: depth + 1, width: width, swipeProgress: progress))
                    .overlay {
                        let dim = dimOpacity(index: 0, totalCount: depth + 1, swipeProgress: progress)
                        if dim > 0.001 {
                            Color.black.opacity(dim)
                                .allowsHitTesting(false)
                        }
                    }
                    .allowsHitTesting(depth == 0)

                    ForEach(Array(nav.entries.enumerated()), id: \.element.id) { idx, entry in
                        let stackIndex = idx + 1
                        let isTop = stackIndex == depth

                        pageSurface(isRoot: false, pageKey: entry.id.uuidString) {
                            entry.makeView()
                        }
                        .shadow(
                            color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.16),
                            radius: 22,
                            x: -8
                        )
                        .offset(
                            x: pageOffset(
                                index: stackIndex,
                                totalCount: depth + 1,
                                width: width,
                                swipeProgress: progress
                            )
                        )
                        .overlay {
                            let dim = dimOpacity(index: stackIndex, totalCount: depth + 1, swipeProgress: progress)
                            if dim > 0.001 {
                                Color.black.opacity(dim)
                                    .allowsHitTesting(false)
                            }
                        }
                        .allowsHitTesting(isTop)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .asymmetric(
                                    insertion: .move(edge: .trailing),
                                    removal: .move(edge: .trailing)
                                )
                        )
                    }
                }
                .clipped()
                .onPreferenceChange(FMSwipeBackDisabledPreferenceKey.self) { disabled in
                    childDisablesSwipeBack = disabled
                }
                .background {
                    FMTrackpadSwipeBridge(
                        isEnabled: nav.canPop && !swipeBackDisabled && !childDisablesSwipeBack,
                        onChanged: { translation in
                            nav.isSwipingBack = true
                            nav.swipeOffset = max(0, min(translation, width))
                            let crossed = nav.swipeOffset > width * 0.28
                            if crossed != crossedSwipeThreshold {
                                crossedSwipeThreshold = crossed
                                FMHaptics.perform(.levelChange, enabled: theme.hapticsEnabled)
                            }
                        },
                        onEnded: { translation, velocity in
                            crossedSwipeThreshold = false
                            let shouldPop = FMNavigationController.shouldCommitSwipeBack(
                                translation: translation,
                                velocity: velocity,
                                containerWidth: width
                            )
                            if shouldPop {
                                withAnimation(navigationAnimation) {
                                    nav.swipeOffset = 0
                                    nav.isSwipingBack = false
                                    _ = nav.pop()
                                }
                            } else {
                                withAnimation(navigationAnimation) {
                                    nav.swipeOffset = 0
                                    nav.isSwipingBack = false
                                }
                            }
                        }
                    )
                }

                // Native top-flush unified toolbar bar (blurs scrolled content cleanly behind it like App Store!).
                let scrolled = activeScrollOffset > 14
                floatingNavigationChrome(nav: nav, scrolled: scrolled)
                    .zIndex(20)
            }
            .fmAnimation(.navigation, value: depth)
            .onChange(of: depth) { _, _ in
                let validKeys = Set(["root"] + nav.entries.map(\.id.uuidString))
                pageScrollOffsets = pageScrollOffsets.filter { validKeys.contains($0.key) }
            }
        }
        .background {
            Button("") {
                guard nav.canPop else { return }
                FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                withAnimation(navigationAnimation) {
                    _ = nav.pop()
                }
            }
            .keyboardShortcut("[", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
        .environment(\.fmNavigator, nav)
    }

    @ViewBuilder
    private func floatingNavigationChrome(nav: FMNavigationController, scrolled: Bool) -> some View {
        let currentTitle = nav.entries.last?.title ?? rootTitle
        let showCenterTitle: Bool = {
            switch headerStyle {
            case .floating:
                return scrolled || nav.canPop
            case .inline:
                return true
            case .large:
                return scrolled || nav.canPop
            }
        }()

        ZStack(alignment: .bottom) {
            // Native blurred toolbar backdrop fades in when content scrolls beneath it
            Group {
                if reduceTransparency {
                    FMColor.canvasBackground(colorScheme)
                } else {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            FMColor.canvasBackground(colorScheme).opacity(colorScheme == .dark ? 0.35 : 0.45)
                        }
                }
            }
            .opacity(scrolled ? 1.0 : 0.0)
            .allowsHitTesting(false)

            FMFloatingHeaderBar(height: toolbarHeight) {
                HStack(spacing: 6) {
                    if leadingToolbarInset > 0 {
                        Spacer().frame(width: leadingToolbarInset)
                    }
                    FMToolbarGroup {
                        if nav.canPop {
                            FMToolbarButton(icon: "chevron.left", diameter: 30) {
                                withAnimation(navigationAnimation) {
                                    _ = nav.pop()
                                }
                            }
                            .accessibilityLabel("Back")
                            .transition(reduceMotion ? .opacity : .scale(scale: 0.7).combined(with: .opacity))
                        }
                        leadingBar
                    }
                }
            } center: {
                if showCenterTitle {
                    HStack(spacing: 7) {
                        if !nav.canPop, let titleIcon {
                            FMIconBadge(titleIcon, color: titleIconColor, size: 18)
                        }
                        Text(currentTitle)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    .transition(.opacity.combined(with: .offset(y: 3)))
                }
            } trailing: {
                HStack(spacing: 8) {
                    if scrolled && !nav.canPop {
                        scrolledAccessory
                            .transition(.scale(scale: 0.88).combined(with: .opacity))
                    }
                    trailingBar
                }
            }

            if scrolled {
                Rectangle()
                    .fill(FMColor.separator(colorScheme, highContrast: contrast == .increased))
                    .frame(height: 0.5)
                    .transition(.opacity)
            }
        }
        .frame(height: toolbarHeight)
        .fmAnimation(.micro, value: scrolled)
        .fmAnimation(.micro, value: showCenterTitle)
        .fmAnimation(.navigation, value: nav.canPop)
    }

    @ViewBuilder
    private func pageSurface<V: View>(isRoot: Bool, pageKey: String, @ViewBuilder _ content: () -> V) -> some View {
        let localOffset = pageScrollOffsets[pageKey] ?? 0
        let showsLargeHeader = isRoot && headerStyle == .large
        let largeHeaderHeight: CGFloat = (rootSubtitle?.isEmpty == false) ? 62 : 44
        let collapseProgress = min(max(localOffset / 36, 0), 1)

        ZStack(alignment: .topLeading) {
            FMColor.canvasBackground(colorScheme)
                .ignoresSafeArea()

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaPadding(.top, showsLargeHeader ? toolbarHeight + largeHeaderHeight + 6 : toolbarHeight)
                .scrollEdgeEffectStyle(.soft, for: .top)

            if showsLargeHeader {
                VStack(alignment: .leading, spacing: 3) {
                    Text(rootTitle)
                        .font(.fmLargeTitle)
                        .foregroundStyle(.primary)
                    if let rootSubtitle, !rootSubtitle.isEmpty {
                        Text(rootSubtitle)
                            .font(.fmSubheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 34)
                .padding(.top, toolbarHeight + 4)
                .offset(y: -min(localOffset, largeHeaderHeight))
                .opacity(Double(1 - collapseProgress))
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, newValue in
            pageScrollOffsets[pageKey] = max(0, newValue)
        }
    }

    private func pageOffset(
        index: Int,
        totalCount: Int,
        width: CGFloat,
        swipeProgress: CGFloat
    ) -> CGFloat {
        let topIndex = totalCount - 1
        if index == topIndex {
            return swipeProgress * width
        }
        if index == topIndex - 1 {
            return -width * 0.25 * (1 - swipeProgress)
        }
        return -width * 0.25
    }

    private func dimOpacity(
        index: Int,
        totalCount: Int,
        swipeProgress: CGFloat
    ) -> Double {
        let topIndex = totalCount - 1
        if index == topIndex { return 0 }
        if index == topIndex - 1 {
            return 0.22 * Double(1 - swipeProgress)
        }
        return 0.22
    }
}

public extension FMNavigationStack where LeadingBar == EmptyView, ScrolledAccessory == EmptyView, TrailingBar == EmptyView {
    init(
        controller: FMNavigationController? = nil,
        title: String,
        subtitle: String? = nil,
        titleIcon: String? = nil,
        titleIconColor: Color = FMColor.blue,
        headerStyle: FMNavigationHeaderStyle = .floating,
        @ViewBuilder root: () -> Root
    ) {
        self.init(
            controller: controller,
            title: title,
            subtitle: subtitle,
            titleIcon: titleIcon,
            titleIconColor: titleIconColor,
            headerStyle: headerStyle,
            leadingBar: { EmptyView() },
            scrolledAccessory: { EmptyView() },
            trailingBar: { EmptyView() },
            root: root
        )
    }
}

public extension FMNavigationStack where LeadingBar == EmptyView, ScrolledAccessory == EmptyView {
    init(
        controller: FMNavigationController? = nil,
        title: String,
        subtitle: String? = nil,
        titleIcon: String? = nil,
        titleIconColor: Color = FMColor.blue,
        headerStyle: FMNavigationHeaderStyle = .floating,
        @ViewBuilder trailingBar: () -> TrailingBar,
        @ViewBuilder root: () -> Root
    ) {
        self.init(
            controller: controller,
            title: title,
            subtitle: subtitle,
            titleIcon: titleIcon,
            titleIconColor: titleIconColor,
            headerStyle: headerStyle,
            leadingBar: { EmptyView() },
            scrolledAccessory: { EmptyView() },
            trailingBar: trailingBar,
            root: root
        )
    }
}

public extension FMNavigationStack where LeadingBar == EmptyView {
    init(
        controller: FMNavigationController? = nil,
        title: String,
        subtitle: String? = nil,
        titleIcon: String? = nil,
        titleIconColor: Color = FMColor.blue,
        headerStyle: FMNavigationHeaderStyle = .floating,
        @ViewBuilder scrolledAccessory: () -> ScrolledAccessory,
        @ViewBuilder trailingBar: () -> TrailingBar,
        @ViewBuilder root: () -> Root
    ) {
        self.init(
            controller: controller,
            title: title,
            subtitle: subtitle,
            titleIcon: titleIcon,
            titleIconColor: titleIconColor,
            headerStyle: headerStyle,
            leadingBar: { EmptyView() },
            scrolledAccessory: scrolledAccessory,
            trailingBar: trailingBar,
            root: root
        )
    }
}
