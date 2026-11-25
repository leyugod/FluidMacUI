import SwiftUI
import AppKit

/// Pure geometric math helpers for `FMSplitPane` sizing, clamping, and keyboard stepping.
public enum FMSplitPaneMath {
    /// Clamps a proposed primary pane length within `[minPrimary, total - minSecondary]`.
    ///
    /// When `total` is smaller than `minPrimary + minSecondary`, the available space is divided
    /// proportionally according to `minPrimary` and `minSecondary` so neither pane overflows `total`.
    public static func clampPrimarySize(
        _ proposed: CGFloat,
        total: CGFloat,
        minPrimary: CGFloat,
        minSecondary: CGFloat
    ) -> CGFloat {
        guard total > 0 else { return 0 }
        let safeMinPrimary = max(0, minPrimary)
        let safeMinSecondary = max(0, minSecondary)
        let minSum = safeMinPrimary + safeMinSecondary

        if minSum > total {
            guard minSum > 0 else { return 0 }
            return total * (safeMinPrimary / minSum)
        }

        let upperBound = total - safeMinSecondary
        return min(max(proposed, safeMinPrimary), upperBound)
    }

    /// Computes a normalized `0...1` ratio for a primary pane size within `total`.
    public static func ratio(for primarySize: CGFloat, total: CGFloat) -> CGFloat {
        guard total > 0 else { return 0 }
        return min(max(primarySize / total, 0), 1)
    }

    /// Clamps a normalized fraction into the valid range allowed by `total`, `minPrimary`, and `minSecondary`.
    public static func clampFraction(
        _ fraction: CGFloat,
        total: CGFloat,
        minPrimary: CGFloat,
        minSecondary: CGFloat
    ) -> CGFloat {
        let bounded = min(max(fraction, 0), 1)
        guard total > 0 else { return bounded }
        let clampedSize = clampPrimarySize(
            bounded * total,
            total: total,
            minPrimary: minPrimary,
            minSecondary: minSecondary
        )
        return ratio(for: clampedSize, total: total)
    }

    /// Adjusts a split fraction by `delta` and clamps the result to the pane constraints.
    public static func stepFraction(
        current: CGFloat,
        delta: CGFloat,
        total: CGFloat,
        minPrimary: CGFloat,
        minSecondary: CGFloat
    ) -> CGFloat {
        clampFraction(
            current + delta,
            total: total,
            minPrimary: minPrimary,
            minSecondary: minSecondary
        )
    }
}

/// General-purpose resizable horizontal or vertical split view with a tactile hairline divider,
/// leak-proof resize cursor tracking, double-click snap reset, and full keyboard/VoiceOver support.
public struct FMSplitPane<Primary: View, Secondary: View>: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    private let axis: Axis
    private let externalFraction: Binding<CGFloat>?
    private let minPrimary: CGFloat
    private let minSecondary: CGFloat
    private let resetFractionOnDoubleClick: CGFloat?
    private let primary: Primary
    private let secondary: Secondary

    @State private var internalFraction: CGFloat
    @State private var dragStartPrimarySize: CGFloat?
    @State private var isDragging = false
    @State private var isHoveringSplitter = false
    @State private var isAtBoundary = false
    @State private var isCursorPushed = false
    @State private var pushedAxis: Axis?
    @FocusState private var isSplitterFocused: Bool

    /// Creates a resizable split pane along the given axis.
    /// - Parameters:
    ///   - axis: `.horizontal` for left/right panes, or `.vertical` for top/bottom panes.
    ///   - fraction: Optional external binding for the primary pane ratio (`0...1`).
    ///   - initialFraction: Initial primary pane ratio used when `fraction` is `nil`.
    ///   - minPrimary: Minimum point length of the primary pane.
    ///   - minSecondary: Minimum point length of the secondary pane.
    ///   - resetFractionOnDoubleClick: Optional fraction to snap back to when double-clicking the divider.
    ///   - primary: Builder for the leading (or top) pane.
    ///   - secondary: Builder for the trailing (or bottom) pane.
    public init(
        axis: Axis = .horizontal,
        fraction: Binding<CGFloat>? = nil,
        initialFraction: CGFloat = 0.5,
        minPrimary: CGFloat = 180,
        minSecondary: CGFloat = 180,
        resetFractionOnDoubleClick: CGFloat? = 0.5,
        @ViewBuilder primary: () -> Primary,
        @ViewBuilder secondary: () -> Secondary
    ) {
        self.axis = axis
        self.externalFraction = fraction
        self.minPrimary = max(0, minPrimary)
        self.minSecondary = max(0, minSecondary)
        self.resetFractionOnDoubleClick = resetFractionOnDoubleClick.map { min(max($0, 0), 1) }
        self.primary = primary()
        self.secondary = secondary()
        self._internalFraction = State(initialValue: min(max(initialFraction, 0), 1))
    }

    private var currentFraction: CGFloat {
        min(max(externalFraction?.wrappedValue ?? internalFraction, 0), 1)
    }

    private func setFraction(_ value: CGFloat) {
        let clamped = min(max(value, 0), 1)
        internalFraction = clamped
        if let externalFraction {
            externalFraction.wrappedValue = clamped
        }
    }

    private var baseDividerThickness: CGFloat {
        contrast == .increased ? 1.0 : 0.5
    }

    public var body: some View {
        GeometryReader { proxy in
            let totalLength = axis == .horizontal ? proxy.size.width : proxy.size.height
            let availableTotal = max(0, totalLength - baseDividerThickness)
            let primaryLength = FMSplitPaneMath.clampPrimarySize(
                currentFraction * availableTotal,
                total: availableTotal,
                minPrimary: minPrimary,
                minSecondary: minSecondary
            )
            let secondaryLength = max(0, availableTotal - primaryLength)
            let effectiveFraction = FMSplitPaneMath.ratio(for: primaryLength, total: availableTotal)

            ZStack(alignment: axis == .horizontal ? .leading : .top) {
                layoutContainer(primaryLength: primaryLength, secondaryLength: secondaryLength)

                splitterHandle(
                    primaryLength: primaryLength,
                    availableTotal: availableTotal,
                    effectiveFraction: effectiveFraction
                )
                .offset(
                    x: axis == .horizontal ? primaryLength - 4 + (baseDividerThickness * 0.5) : 0,
                    y: axis == .vertical ? primaryLength - 4 + (baseDividerThickness * 0.5) : 0
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onChange(of: axis) { _, _ in
            if isCursorPushed {
                updateCursor(active: isHoveringSplitter || isDragging)
            }
        }
        .onChange(of: isEnabled) { _, enabled in
            if !enabled {
                isHoveringSplitter = false
                isDragging = false
                dragStartPrimarySize = nil
                updateCursor(active: false)
            }
        }
        .onDisappear {
            isHoveringSplitter = false
            isDragging = false
            dragStartPrimarySize = nil
            updateCursor(active: false)
        }
    }

    @ViewBuilder
    private func layoutContainer(primaryLength: CGFloat, secondaryLength: CGFloat) -> some View {
        if axis == .horizontal {
            HStack(spacing: 0) {
                primary
                    .frame(width: primaryLength)
                    .frame(maxHeight: .infinity)
                    .clipped()

                Color.clear
                    .frame(width: baseDividerThickness)
                    .frame(maxHeight: .infinity)

                secondary
                    .frame(width: secondaryLength)
                    .frame(maxHeight: .infinity)
                    .clipped()
            }
        } else {
            VStack(spacing: 0) {
                primary
                    .frame(height: primaryLength)
                    .frame(maxWidth: .infinity)
                    .clipped()

                Color.clear
                    .frame(height: baseDividerThickness)
                    .frame(maxWidth: .infinity)

                secondary
                    .frame(height: secondaryLength)
                    .frame(maxWidth: .infinity)
                    .clipped()
            }
        }
    }

    private func splitterHandle(
        primaryLength: CGFloat,
        availableTotal: CGFloat,
        effectiveFraction: CGFloat
    ) -> some View {
        let isHighlighted = isEnabled && (isHoveringSplitter || isDragging || isSplitterFocused)
        let accent = FMColor.adaptiveAccent(
            theme.accentColor,
            activeState: activeState,
            scheme: colorScheme
        )
        let lineColor: Color = isHighlighted
            ? accent.opacity(isDragging ? 0.95 : 0.78)
            : FMColor.separator(colorScheme, highContrast: contrast == .increased)
        let lineThickness: CGFloat = isHighlighted ? (isDragging ? 2.5 : 2.0) : baseDividerThickness
        let percentage = Int((effectiveFraction * 100).rounded())

        return ZStack {
            Rectangle()
                .fill(lineColor)
                .frame(
                    width: axis == .horizontal ? lineThickness : nil,
                    height: axis == .vertical ? lineThickness : nil
                )

            if isHighlighted {
                Capsule(style: .continuous)
                    .fill(accent.opacity(isDragging ? 0.95 : 0.72))
                    .frame(
                        width: axis == .horizontal ? 4 : 28,
                        height: axis == .horizontal ? 28 : 4
                    )
                    .transition(.opacity)
            }
        }
        .frame(
            width: axis == .horizontal ? 8 : nil,
            height: axis == .vertical ? 8 : nil
        )
        .frame(
            maxWidth: axis == .vertical ? .infinity : nil,
            maxHeight: axis == .horizontal ? .infinity : nil
        )
        .contentShape(Rectangle())
        .focusable(isEnabled)
        .focused($isSplitterFocused)
        .focusEffectDisabled()
        .fmFocusRing(isFocused: isSplitterFocused, cornerRadius: 4, isCapsule: true)
        .fmAnimation(.micro, value: isHighlighted)
        .fmAnimation(.micro, value: isDragging)
        .onHover { hovering in
            guard isEnabled else {
                isHoveringSplitter = false
                updateCursor(active: false)
                return
            }
            isHoveringSplitter = hovering
            updateCursor(active: hovering || isDragging)
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    guard isEnabled, availableTotal > 0 else { return }
                    if dragStartPrimarySize == nil {
                        dragStartPrimarySize = primaryLength
                        isDragging = true
                        updateCursor(active: true)
                    }
                    let delta = axis == .horizontal ? value.translation.width : value.translation.height
                    let proposed = (dragStartPrimarySize ?? primaryLength) + delta
                    let clamped = FMSplitPaneMath.clampPrimarySize(
                        proposed,
                        total: availableTotal,
                        minPrimary: minPrimary,
                        minSecondary: minSecondary
                    )
                    let hitBoundary = abs(clamped - proposed) > 0.5
                    if hitBoundary && !isAtBoundary {
                        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                    }
                    isAtBoundary = hitBoundary
                    setFraction(FMSplitPaneMath.ratio(for: clamped, total: availableTotal))
                }
                .onEnded { _ in
                    dragStartPrimarySize = nil
                    isDragging = false
                    isAtBoundary = false
                    updateCursor(active: isHoveringSplitter)
                }
        )
        .onTapGesture(count: 2) {
            guard isEnabled else { return }
            resetToDefaultFraction(availableTotal: availableTotal)
        }
        .onKeyPress(.leftArrow) {
            guard isEnabled, axis == .horizontal else { return .ignored }
            stepBy(-0.05, availableTotal: availableTotal)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            guard isEnabled, axis == .horizontal else { return .ignored }
            stepBy(0.05, availableTotal: availableTotal)
            return .handled
        }
        .onKeyPress(.upArrow) {
            guard isEnabled, axis == .vertical else { return .ignored }
            stepBy(-0.05, availableTotal: availableTotal)
            return .handled
        }
        .onKeyPress(.downArrow) {
            guard isEnabled, axis == .vertical else { return .ignored }
            stepBy(0.05, availableTotal: availableTotal)
            return .handled
        }
        .onKeyPress(.return) {
            guard isEnabled, resetFractionOnDoubleClick != nil else { return .ignored }
            resetToDefaultFraction(availableTotal: availableTotal)
            return .handled
        }
        .onKeyPress(.space) {
            guard isEnabled, resetFractionOnDoubleClick != nil else { return .ignored }
            resetToDefaultFraction(availableTotal: availableTotal)
            return .handled
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(axis == .horizontal ? "Horizontal split divider" : "Vertical split divider")
        .accessibilityValue("\(percentage) percent")
        .accessibilityHint("Drag or use arrow keys to resize panes.")
        .accessibilityAdjustableAction { direction in
            guard isEnabled else { return }
            switch direction {
            case .increment:
                stepBy(0.05, availableTotal: availableTotal)
            case .decrement:
                stepBy(-0.05, availableTotal: availableTotal)
            @unknown default:
                break
            }
        }
    }

    private func stepBy(_ delta: CGFloat, availableTotal: CGFloat) {
        let next = FMSplitPaneMath.stepFraction(
            current: currentFraction,
            delta: delta,
            total: availableTotal,
            minPrimary: minPrimary,
            minSecondary: minSecondary
        )
        let animation = FMSpring.animation(
            .interactive,
            reduceMotion: reduceMotion,
            speed: theme.animationSpeed
        )
        withAnimation(animation) {
            setFraction(next)
        }
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
    }

    private func resetToDefaultFraction(availableTotal: CGFloat) {
        guard let resetFractionOnDoubleClick else { return }
        let target = FMSplitPaneMath.clampFraction(
            resetFractionOnDoubleClick,
            total: availableTotal,
            minPrimary: minPrimary,
            minSecondary: minSecondary
        )
        let animation = FMSpring.animation(
            .navigation,
            reduceMotion: reduceMotion,
            speed: theme.animationSpeed
        )
        withAnimation(animation) {
            setFraction(target)
        }
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
    }

    private func updateCursor(active: Bool) {
        if active {
            if isCursorPushed && pushedAxis != axis {
                NSCursor.pop()
                isCursorPushed = false
                pushedAxis = nil
            }
            if !isCursorPushed {
                let cursor: NSCursor = axis == .horizontal ? .resizeLeftRight : .resizeUpDown
                cursor.push()
                isCursorPushed = true
                pushedAxis = axis
            }
        } else if isCursorPushed {
            NSCursor.pop()
            isCursorPushed = false
            pushedAxis = nil
        }
    }
}
