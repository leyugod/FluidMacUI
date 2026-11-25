import SwiftUI

// MARK: - Steps Model & Pure Math

/// Visual and semantic status of a single step in `FMStepsIndicator`.
public enum FMStepState: Sendable, Hashable {
    /// Step precedes `currentStep` and has no error.
    case completed
    /// Step is currently active.
    case active
    /// Step has not been reached yet.
    case pending
    /// Step has been flagged in `errorSteps`.
    case error

    /// Human-readable status string announced to VoiceOver.
    public var accessibilityDescription: String {
        switch self {
        case .completed: "Completed"
        case .active: "Current step"
        case .pending: "Pending"
        case .error: "Error"
        }
    }
}

/// Descriptor for an individual step in `FMStepsIndicator`.
public struct FMStepItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let icon: String?

    public init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String? = nil,
        icon: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
    }
}

/// Pure, deterministic state and progress math for `FMStepsIndicator`.
public enum FMStepsMath {
    /// Clamps a candidate step index into valid bounds `0..<totalSteps` (or `0` when empty).
    public static func clampedStep(_ step: Int, totalSteps: Int) -> Int {
        guard totalSteps > 0 else { return 0 }
        return min(max(step, 0), totalSteps - 1)
    }

    /// Resolves the semantic `FMStepState` for `index` given `currentStep` and `errorSteps`.
    ///
    /// Error status takes precedence so failed steps remain visibly highlighted regardless of
    /// current navigation position.
    public static func state(
        for index: Int,
        currentStep: Int,
        errorSteps: Set<Int>
    ) -> FMStepState {
        if errorSteps.contains(index) {
            return .error
        }
        if index < currentStep {
            return .completed
        }
        if index == currentStep {
            return .active
        }
        return .pending
    }

    /// Computes overall connector completion progress in `0...1`.
    ///
    /// - For `totalSteps <= 0`, returns `0`.
    /// - For `totalSteps == 1`, returns `1` once `currentStep >= 1`, otherwise `0`.
    /// - For `totalSteps > 1`, maps `currentStep` linearly across the `totalSteps - 1` connectors.
    public static func completionRatio(currentStep: Int, totalSteps: Int) -> Double {
        guard totalSteps > 0 else { return 0 }
        if totalSteps == 1 {
            return currentStep >= 1 ? 1 : 0
        }
        let ratio = Double(currentStep) / Double(totalSteps - 1)
        return min(max(ratio, 0), 1)
    }

    /// Returns the fill amount (`0` or `1`) for the connector segment between `segmentIndex`
    /// and `segmentIndex + 1`.
    public static func segmentFill(at segmentIndex: Int, currentStep: Int) -> CGFloat {
        segmentIndex >= 0 && segmentIndex < currentStep ? 1 : 0
    }

    /// Determines whether the step at `index` may be selected by user interaction.
    ///
    /// Completed and error steps are selectable when `allowsStepSelection` is enabled; unreached
    /// pending steps remain locked until reached.
    public static func canSelectStep(
        at index: Int,
        currentStep: Int,
        errorSteps: Set<Int>,
        allowsStepSelection: Bool
    ) -> Bool {
        guard allowsStepSelection, index >= 0 else { return false }
        let resolved = state(for: index, currentStep: currentStep, errorSteps: errorSteps)
        return resolved == .completed || resolved == .error
    }
}

// MARK: - FMStepsIndicator

/// Multi-step wizard progress indicator supporting horizontal and vertical layouts,
/// animated connector fills, spring badge transitions, optional jump-to-completed-step
/// interaction with keyboard focus rings, and full VoiceOver accessibility.
public struct FMStepsIndicator: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let steps: [FMStepItem]
    @Binding private var currentStep: Int
    private let errorSteps: Set<Int>
    private let axis: Axis
    private let allowsStepSelection: Bool

    @FocusState private var focusedIndex: Int?
    @State private var hoveredIndex: Int?

    public init(
        steps: [FMStepItem],
        currentStep: Binding<Int>,
        errorSteps: Set<Int> = [],
        axis: Axis = .horizontal,
        allowsStepSelection: Bool = false
    ) {
        self.steps = steps
        self._currentStep = currentStep
        self.errorSteps = errorSteps
        self.axis = axis
        self.allowsStepSelection = allowsStepSelection
    }

    private var badgeSize: CGFloat {
        switch density {
        case .compact: 24
        case .regular: 28
        case .comfortable: 32
        }
    }

    private var isHighContrast: Bool {
        contrast == .increased || reduceTransparency
    }

    private var activeAccent: Color {
        FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
    }

    private var trackColor: Color {
        FMColor.separator(colorScheme, highContrast: isHighContrast)
    }

    public var body: some View {
        Group {
            if steps.isEmpty {
                EmptyView()
            } else {
                switch axis {
                case .horizontal:
                    horizontalLayout
                case .vertical:
                    verticalLayout
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Progress steps")
    }

    // MARK: - Horizontal Layout

    private var horizontalLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                let stepState = FMStepsMath.state(
                    for: index,
                    currentStep: currentStep,
                    errorSteps: errorSteps
                )
                let selectable = FMStepsMath.canSelectStep(
                    at: index,
                    currentStep: currentStep,
                    errorSteps: errorSteps,
                    allowsStepSelection: allowsStepSelection
                )

                VStack(spacing: FMSpacing.xs) {
                    HStack(spacing: 0) {
                        horizontalConnector(
                            visible: index > 0,
                            fill: FMStepsMath.segmentFill(at: index - 1, currentStep: currentStep)
                        )

                        interactiveBadgeWrapper(
                            index: index,
                            step: step,
                            state: stepState,
                            selectable: selectable
                        )

                        horizontalConnector(
                            visible: index < steps.count - 1,
                            fill: FMStepsMath.segmentFill(at: index, currentStep: currentStep)
                        )
                    }

                    VStack(spacing: 2) {
                        Text(step.title)
                            .font(stepState == .active ? .fmCaption.weight(.bold) : .fmCaption)
                            .foregroundStyle(titleColor(for: stepState))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)

                        if let subtitle = step.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.fmFootnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                    .padding(.horizontal, FMSpacing.xxs)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Step \(index + 1) of \(steps.count): \(step.title)")
                .accessibilityValue(stepState.accessibilityDescription)
                .accessibilityHint(selectable ? "Activate to return to this step" : "")
                .accessibilityAddTraits(selectable ? .isButton : [])
            }
        }
    }

    private func horizontalConnector(visible: Bool, fill: CGFloat) -> some View {
        GeometryReader { proxy in
            let width = max(0, proxy.size.width)
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(visible ? trackColor : .clear)

                if visible {
                    Capsule(style: .continuous)
                        .fill(activeAccent)
                        .frame(width: width * fill)
                        .fmAnimation(.navigation, value: fill)
                }
            }
        }
        .frame(height: isHighContrast ? 2.5 : 2)
    }

    // MARK: - Vertical Layout

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                verticalStepRow(index: index, step: step)
            }
        }
    }

    private func verticalStepRow(index: Int, step: FMStepItem) -> some View {
        let stepState = FMStepsMath.state(
            for: index,
            currentStep: currentStep,
            errorSteps: errorSteps
        )
        let selectable = FMStepsMath.canSelectStep(
            at: index,
            currentStep: currentStep,
            errorSteps: errorSteps,
            allowsStepSelection: allowsStepSelection
        )
        let hasTrailingConnector = index < steps.count - 1
        let connectorFill = FMStepsMath.segmentFill(at: index, currentStep: currentStep)

        return HStack(alignment: .top, spacing: FMSpacing.sm) {
            VStack(spacing: 0) {
                interactiveBadgeWrapper(
                    index: index,
                    step: step,
                    state: stepState,
                    selectable: selectable
                )

                if hasTrailingConnector {
                    verticalConnector(fill: connectorFill)
                }
            }
            .frame(width: badgeSize)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(stepState == .active ? .fmHeadline : .fmBody.weight(.medium))
                    .foregroundStyle(titleColor(for: stepState))

                if let subtitle = step.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.fmFootnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, max(0, (badgeSize - 18) * 0.5))
            .padding(.bottom, hasTrailingConnector ? FMSpacing.sm : 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(index + 1) of \(steps.count): \(step.title)")
        .accessibilityValue(stepState.accessibilityDescription)
        .accessibilityHint(selectable ? "Activate to return to this step" : "")
        .accessibilityAddTraits(selectable ? .isButton : [])
    }

    private func verticalConnector(fill: CGFloat) -> some View {
        GeometryReader { proxy in
            let height = max(0, proxy.size.height)
            ZStack(alignment: .top) {
                Capsule(style: .continuous)
                    .fill(trackColor)

                Capsule(style: .continuous)
                    .fill(activeAccent)
                    .frame(height: height * fill)
                    .fmAnimation(.navigation, value: fill)
            }
        }
        .frame(width: isHighContrast ? 2.5 : 2)
        .frame(minHeight: density == .compact ? 22 : 28)
        .padding(.vertical, 3)
    }

    // MARK: - Step Badge & Interaction

    @ViewBuilder
    private func interactiveBadgeWrapper(
        index: Int,
        step: FMStepItem,
        state: FMStepState,
        selectable: Bool
    ) -> some View {
        let isHovered = selectable && hoveredIndex == index
        let isFocused = selectable && focusedIndex == index

        if selectable {
            Button {
                selectStep(index)
            } label: {
                stepBadge(index: index, step: step, state: state, isHovered: isHovered)
            }
            .buttonStyle(.plain)
            .focusable()
            .focused($focusedIndex, equals: index)
            .focusEffectDisabled()
            .fmFocusRing(isFocused: isFocused, isCapsule: true)
            .onHover { hovering in
                hoveredIndex = hovering ? index : (hoveredIndex == index ? nil : hoveredIndex)
            }
            .onKeyPress(.return) {
                selectStep(index)
                return .handled
            }
            .onKeyPress(.space) {
                selectStep(index)
                return .handled
            }
            .onKeyPress(axis == .horizontal ? .leftArrow : .upArrow) {
                moveFocus(from: index, delta: -1)
            }
            .onKeyPress(axis == .horizontal ? .rightArrow : .downArrow) {
                moveFocus(from: index, delta: 1)
            }
        } else {
            stepBadge(index: index, step: step, state: state, isHovered: false)
        }
    }

    private func stepBadge(
        index: Int,
        step: FMStepItem,
        state: FMStepState,
        isHovered: Bool
    ) -> some View {
        let iconFontSize = badgeSize * 0.44
        let numberFontSize = badgeSize * 0.46
        let errorColor = FMColor.adaptiveAccent(FMColor.red, activeState: activeState, scheme: colorScheme)

        return ZStack {
            if state == .active && !reduceTransparency {
                Circle()
                    .fill(activeAccent.opacity(colorScheme == .dark ? 0.24 : 0.16))
                    .frame(width: badgeSize + 8, height: badgeSize + 8)
            }

            Circle()
                .fill(badgeBackground(for: state, errorColor: errorColor))
                .frame(width: badgeSize, height: badgeSize)
                .overlay {
                    Circle()
                        .strokeBorder(
                            badgeBorderColor(for: state, errorColor: errorColor),
                            lineWidth: badgeBorderWidth(for: state)
                        )
                }

            switch state {
            case .completed:
                Image(systemName: "checkmark")
                    .font(.system(size: iconFontSize, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.5).combined(with: .opacity))

            case .error:
                Image(systemName: "exclamationmark")
                    .font(.system(size: iconFontSize, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))

            case .active, .pending:
                if let icon = step.icon, !icon.isEmpty {
                    Image(systemName: icon)
                        .font(.system(size: iconFontSize, weight: .semibold))
                        .foregroundStyle(state == .active ? Color.white : Color.secondary)
                } else {
                    Text("\(index + 1)")
                        .font(.fmNumeric(size: numberFontSize, weight: .bold))
                        .foregroundStyle(state == .active ? Color.white : Color.secondary)
                }
            }
        }
        .frame(width: badgeSize, height: badgeSize)
        .scaleEffect(isHovered ? 1.08 : 1.0)
        .fmAnimation(.micro, value: state)
        .fmAnimation(.micro, value: isHovered)
    }

    private func badgeBackground(for state: FMStepState, errorColor: Color) -> Color {
        switch state {
        case .completed, .active:
            return activeAccent
        case .error:
            return errorColor
        case .pending:
            return reduceTransparency
                ? FMColor.elevatedOpaqueSurface(colorScheme)
                : FMColor.controlFill(colorScheme)
        }
    }

    private func badgeBorderColor(for state: FMStepState, errorColor: Color) -> Color {
        switch state {
        case .completed:
            return .clear
        case .active:
            return isHighContrast ? Color.primary.opacity(0.45) : activeAccent.opacity(0.35)
        case .error:
            return isHighContrast ? Color.primary.opacity(0.35) : errorColor.opacity(0.4)
        case .pending:
            return FMColor.separator(colorScheme, highContrast: isHighContrast)
        }
    }

    private func badgeBorderWidth(for state: FMStepState) -> CGFloat {
        switch state {
        case .active:
            return isHighContrast ? 1.5 : 1.0
        case .pending:
            return isHighContrast ? 1.25 : 0.75
        case .completed, .error:
            return isHighContrast ? 1.0 : 0
        }
    }

    private func titleColor(for state: FMStepState) -> Color {
        switch state {
        case .active, .completed:
            return .primary
        case .error:
            return FMColor.adaptiveAccent(FMColor.red, activeState: activeState, scheme: colorScheme)
        case .pending:
            return .secondary
        }
    }

    private func selectStep(_ index: Int) {
        let clamped = FMStepsMath.clampedStep(index, totalSteps: steps.count)
        guard clamped != currentStep else { return }
        withAnimation(
            FMSpring.animation(.navigation, reduceMotion: reduceMotion, speed: theme.animationSpeed)
        ) {
            currentStep = clamped
        }
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
    }

    private func moveFocus(from index: Int, delta: Int) -> KeyPress.Result {
        var candidate = index + delta
        while candidate >= 0 && candidate < steps.count {
            if FMStepsMath.canSelectStep(
                at: candidate,
                currentStep: currentStep,
                errorSteps: errorSteps,
                allowsStepSelection: allowsStepSelection
            ) {
                focusedIndex = candidate
                return .handled
            }
            candidate += delta
        }
        return .ignored
    }
}
