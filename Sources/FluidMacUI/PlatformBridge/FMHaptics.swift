import AppKit

/// Semantic tactile feedback patterns backed by macOS Force Touch trackpad haptics.
public enum FMHapticPattern: Sendable, Hashable {
    /// Crisp detent for toggles, checkboxes, steppers, and slider ticks.
    case alignment
    /// Distinct step feedback for navigation thresholds and mode switches.
    case levelChange
    /// General confirmation or alert feedback.
    case generic

    fileprivate var nsPattern: NSHapticFeedbackManager.FeedbackPattern {
        switch self {
        case .alignment: .alignment
        case .levelChange: .levelChange
        case .generic: .generic
        }
    }
}

/// Centralized macOS trackpad haptic engine.
public enum FMHaptics {
    /// Triggers tactile feedback if `enabled` is true.
    public static func perform(_ pattern: FMHapticPattern, enabled: Bool = true) {
        guard enabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(
            pattern.nsPattern,
            performanceTime: .now
        )
    }
}
