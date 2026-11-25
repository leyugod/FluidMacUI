import SwiftUI

/// Pure index-clamping and paging progression helpers for `FMPageControl` and `FMOnboardingPager`.
public enum FMPageControlMath {
    /// Clamps a page index into `0..<pageCount` (returning `0` when `pageCount <= 0`).
    public static func clamp(_ index: Int, pageCount: Int) -> Int {
        guard pageCount > 0 else { return 0 }
        return min(max(index, 0), pageCount - 1)
    }

    /// Steps `current` by `delta`, clamping to valid bounds or wrapping around when `wraps` is `true`.
    public static func step(
        from current: Int,
        delta: Int,
        pageCount: Int,
        wraps: Bool = false
    ) -> Int {
        guard pageCount > 0 else { return 0 }
        let clampedCurrent = clamp(current, pageCount: pageCount)
        if wraps {
            let offset = (clampedCurrent + delta) % pageCount
            return offset >= 0 ? offset : offset + pageCount
        }
        return clamp(clampedCurrent + delta, pageCount: pageCount)
    }

    /// Returns a `0...1` completion ratio for the active page (1-based over `pageCount`).
    public static func progress(currentPage: Int, pageCount: Int) -> Double {
        guard pageCount > 0 else { return 0 }
        let clamped = clamp(currentPage, pageCount: pageCount)
        return Double(clamped + 1) / Double(pageCount)
    }

    /// Returns `true` when `currentPage` is on (or past) the last page, or when there are no pages.
    public static func isLastPage(_ currentPage: Int, pageCount: Int) -> Bool {
        guard pageCount > 0 else { return true }
        return clamp(currentPage, pageCount: pageCount) == pageCount - 1
    }
}

/// Fluid pill-morphing page indicator with click-to-jump dots, optional glass capsule backdrop,
/// keyboard arrow navigation, and VoiceOver adjustable support.
public struct FMPageControl: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    @Binding private var currentPage: Int
    private let pageCount: Int
    private let showsGlassBackdrop: Bool
    private let tint: Color?

    @State private var hoveredIndex: Int?
    @FocusState private var isFocused: Bool

    /// Creates a fluid pill page control.
    /// - Parameters:
    ///   - currentPage: Binding to the active zero-based page index.
    ///   - pageCount: Total number of pages.
    ///   - showsGlassBackdrop: Wraps the indicator dots in an adaptive Liquid Glass / frosted capsule.
    ///   - tint: Optional active indicator tint color (defaults to `FMTheme.accentColor`).
    public init(
        currentPage: Binding<Int>,
        pageCount: Int,
        showsGlassBackdrop: Bool = false,
        tint: Color? = nil
    ) {
        self._currentPage = currentPage
        self.pageCount = max(0, pageCount)
        self.showsGlassBackdrop = showsGlassBackdrop
        self.tint = tint
    }

    private var clampedPage: Int {
        FMPageControlMath.clamp(currentPage, pageCount: pageCount)
    }

    private var activeTint: Color {
        FMColor.adaptiveAccent(
            tint ?? theme.accentColor,
            activeState: activeState,
            scheme: colorScheme
        )
    }

    public var body: some View {
        if pageCount > 0 {
            dotsRow
                .padding(.horizontal, showsGlassBackdrop ? 10 : 4)
                .padding(.vertical, showsGlassBackdrop ? 4 : 2)
                .background {
                    if showsGlassBackdrop {
                        Color.clear
                            .fmGlassSurface(
                                .regular,
                                cornerRadius: FMCornerRadius.control,
                                isCapsule: true,
                                showShadow: false
                            )
                    }
                }
                .opacity(isEnabled ? 1.0 : 0.45)
                .focusable(isEnabled)
                .focused($isFocused)
                .focusEffectDisabled()
                .fmFocusRing(
                    isFocused: isFocused,
                    cornerRadius: FMCornerRadius.control,
                    isCapsule: true,
                    color: tint
                )
                .onKeyPress(.leftArrow) {
                    guard isEnabled else { return .ignored }
                    step(by: -1)
                    return .handled
                }
                .onKeyPress(.rightArrow) {
                    guard isEnabled else { return .ignored }
                    step(by: 1)
                    return .handled
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Page control")
                .accessibilityValue("Page \(clampedPage + 1) of \(pageCount)")
                .accessibilityAdjustableAction { direction in
                    guard isEnabled else { return }
                    switch direction {
                    case .increment:
                        step(by: 1)
                    case .decrement:
                        step(by: -1)
                    @unknown default:
                        break
                    }
                }
        }
    }

    private var dotsRow: some View {
        HStack(spacing: 4) {
            ForEach(0..<pageCount, id: \.self) { index in
                let isActive = index == clampedPage
                let isHovered = hoveredIndex == index && isEnabled

                ZStack {
                    Capsule(style: .continuous)
                        .fill(dotColor(isActive: isActive, isHovered: isHovered))
                        .frame(width: isActive ? 20 : 6, height: 6)
                }
                .frame(minWidth: isActive ? 24 : 14, minHeight: 20)
                .contentShape(Rectangle())
                .onHover { hovering in
                    hoveredIndex = hovering ? index : (hoveredIndex == index ? nil : hoveredIndex)
                }
                .onTapGesture {
                    guard isEnabled else { return }
                    selectPage(index)
                }
            }
        }
        .fmAnimation(.micro, value: clampedPage)
        .fmAnimation(.micro, value: hoveredIndex)
    }

    private func dotColor(isActive: Bool, isHovered: Bool) -> Color {
        if isActive {
            return activeTint
        }
        let highContrast = contrast == .increased
        if colorScheme == .dark {
            if isHovered { return Color.white.opacity(0.54) }
            return Color.white.opacity(highContrast ? 0.42 : 0.28)
        } else {
            if isHovered { return Color.black.opacity(0.42) }
            return Color.black.opacity(highContrast ? 0.36 : 0.20)
        }
    }

    private func step(by delta: Int) {
        let target = FMPageControlMath.step(from: clampedPage, delta: delta, pageCount: pageCount)
        selectPage(target)
    }

    private func selectPage(_ target: Int) {
        let clamped = FMPageControlMath.clamp(target, pageCount: pageCount)
        guard clamped != clampedPage else { return }
        let animation = FMSpring.animation(
            .micro,
            reduceMotion: reduceMotion,
            speed: theme.animationSpeed
        )
        withAnimation(animation) {
            currentPage = clamped
        }
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
    }
}

/// Content model for a single page inside `FMOnboardingPager`.
public struct FMOnboardingPage: Identifiable, Hashable, Sendable {
    public let id: String
    public let icon: String
    public let iconColor: Color
    public let title: String
    public let description: String

    /// Creates an onboarding page descriptor.
    public init(
        id: String = UUID().uuidString,
        icon: String,
        iconColor: Color = FMColor.blue,
        title: String,
        description: String
    ) {
        self.id = id
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
    }
}

/// Multi-page onboarding and feature-walkthrough pager paired with `FMPageControl`,
/// spring directional slide transitions, Reduce Motion crossfade fallback, and keyboard navigation.
public struct FMOnboardingPager: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let pages: [FMOnboardingPage]
    private let continueTitle: String
    private let doneTitle: String
    private let backTitle: String
    private let skipTitle: String?
    private let onComplete: () -> Void

    @State private var currentPage: Int = 0
    @State private var isMovingForward: Bool = true

    /// Creates an onboarding pager.
    /// - Parameters:
    ///   - pages: Ordered sequence of onboarding pages.
    ///   - continueTitle: Primary button label for intermediate pages.
    ///   - doneTitle: Primary button label for the final page.
    ///   - backTitle: Secondary button label to navigate back one page.
    ///   - skipTitle: Optional top-trailing skip button title.
    ///   - onComplete: Action executed when completing (or skipping) the walkthrough.
    public init(
        pages: [FMOnboardingPage],
        continueTitle: String = "Continue",
        doneTitle: String = "Get Started",
        backTitle: String = "Back",
        skipTitle: String? = nil,
        onComplete: @escaping () -> Void
    ) {
        self.pages = pages
        self.continueTitle = continueTitle
        self.doneTitle = doneTitle
        self.backTitle = backTitle
        self.skipTitle = skipTitle
        self.onComplete = onComplete
    }

    private var clampedIndex: Int {
        FMPageControlMath.clamp(currentPage, pageCount: pages.count)
    }

    private var isLastPage: Bool {
        FMPageControlMath.isLastPage(clampedIndex, pageCount: pages.count)
    }

    private var pageTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        let insertionEdge: Edge = isMovingForward ? .trailing : .leading
        let removalEdge: Edge = isMovingForward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }

    public var body: some View {
        VStack(spacing: FMSpacing.lg) {
            if let skipTitle, !isLastPage, !pages.isEmpty {
                HStack {
                    Spacer()
                    Button(skipTitle) {
                        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                        onComplete()
                    }
                    .buttonStyle(.fmGhost)
                }
            }

            if !pages.isEmpty {
                let activePage = pages[clampedIndex]
                ZStack {
                    pageContent(activePage)
                        .id(activePage.id)
                        .transition(pageTransition)
                }
                .frame(maxWidth: .infinity)
                .clipped()
            }

            if pages.count > 1 {
                FMPageControl(
                    currentPage: Binding(
                        get: { clampedIndex },
                        set: { target in
                            navigate(to: target)
                        }
                    ),
                    pageCount: pages.count,
                    showsGlassBackdrop: true
                )
            }

            HStack(spacing: FMSpacing.sm) {
                if clampedIndex > 0 {
                    Button(backTitle) {
                        navigate(to: clampedIndex - 1)
                    }
                    .buttonStyle(.fmSecondary)
                }

                Button(isLastPage ? doneTitle : continueTitle) {
                    if isLastPage {
                        FMHaptics.perform(.levelChange, enabled: theme.hapticsEnabled)
                        onComplete()
                    } else {
                        navigate(to: clampedIndex + 1)
                    }
                }
                .buttonStyle(.fmPrimary)
            }
        }
        .padding(.horizontal, density.horizontalPadding + FMSpacing.xs)
        .padding(.vertical, density.verticalPadding + FMSpacing.xs)
        .onKeyPress(.leftArrow) {
            guard clampedIndex > 0 else { return .ignored }
            navigate(to: clampedIndex - 1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            guard !isLastPage else { return .ignored }
            navigate(to: clampedIndex + 1)
            return .handled
        }
    }

    private func pageContent(_ page: FMOnboardingPage) -> some View {
        let glowColor = FMColor.adaptiveAccent(
            page.iconColor,
            activeState: activeState,
            scheme: colorScheme
        )

        return VStack(spacing: FMSpacing.md) {
            ZStack {
                if !reduceTransparency {
                    Circle()
                        .fill(glowColor.opacity(colorScheme == .dark ? 0.22 : 0.14))
                        .frame(width: 88, height: 88)
                        .blur(radius: 16)
                        .accessibilityHidden(true)
                }

                FMIconBadge(page.icon, color: page.iconColor, size: 60)
            }
            .padding(.top, FMSpacing.xs)

            VStack(spacing: FMSpacing.xs) {
                Text(page.title)
                    .font(.fmTitle)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.fmBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 380)
            }
        }
        .padding(.vertical, FMSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    private func navigate(to target: Int) {
        let clamped = FMPageControlMath.clamp(target, pageCount: pages.count)
        guard clamped != clampedIndex else { return }
        isMovingForward = clamped > clampedIndex
        let animation = FMSpring.animation(
            .navigation,
            reduceMotion: reduceMotion,
            speed: theme.animationSpeed
        )
        withAnimation(animation) {
            currentPage = clamped
        }
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
    }
}
