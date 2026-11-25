import SwiftUI

/// Visual style of a `FMDynamicHUD` capsule notification.
public enum FMHUDStyle: Sendable, Hashable {
    case info
    case success
    case warning
    case error
    case loading

    public var tintColor: Color {
        switch self {
        case .info: FMColor.blue
        case .success: FMColor.green
        case .warning: FMColor.orange
        case .error: FMColor.red
        case .loading: FMColor.indigo
        }
    }

    public var defaultIcon: String {
        switch self {
        case .info: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        case .loading: "arrow.trianglehead.2.clockwise"
        }
    }
}

/// Optional interactive button displayed inside an expanded `FMDynamicHUD` pill.
public struct FMHUDAction: Identifiable {
    public let id = UUID()
    public let title: String
    public let handler: () -> Void

    public init(_ title: String, handler: @escaping () -> Void) {
        self.title = title
        self.handler = handler
    }
}

/// Immutable descriptor of a Dynamic HUD capsule item.
public struct FMHUDItem: Identifiable {
    public let id: UUID
    public var icon: String
    public var title: String
    public var subtitle: String?
    public var style: FMHUDStyle
    public var duration: TimeInterval?
    public var action: FMHUDAction?

    public init(
        id: UUID = UUID(),
        icon: String? = nil,
        title: String,
        subtitle: String? = nil,
        style: FMHUDStyle = .info,
        duration: TimeInterval? = 2.8,
        action: FMHUDAction? = nil
    ) {
        self.id = id
        self.icon = icon ?? style.defaultIcon
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.duration = style == .loading ? nil : duration
        self.action = action
    }
}

/// Window-scoped coordinator managing Dynamic HUD capsules and modal backdrop state.
///
/// Each `FMWindowContainer` creates its own independent `FMOverlayCoordinator`,
/// guaranteeing complete multi-window isolation in macOS apps.
@Observable
public final class FMOverlayCoordinator {
    /// Currently displayed HUD pill (nil when collapsed).
    public private(set) var activeHUD: FMHUDItem?
    /// Pending FIFO queue of HUD items waiting to present.
    public private(set) var hudQueue: [FMHUDItem] = []
    /// Tracks whether pointer is hovering over the HUD pill (pauses auto-dismiss).
    public var isHUDHovered: Bool = false {
        didSet {
            if isHUDHovered {
                cancelDismissTimer()
            } else if let current = activeHUD, let duration = current.duration {
                scheduleDismiss(after: max(1.0, duration * 0.6), for: current.id)
            }
        }
    }
    /// Number of active bottom sheets in this window (used for subtle background depth scale).
    public var activeSheetCount: Int = 0

    private var dismissTask: Task<Void, Never>?

    public init() {}

    /// Presents a HUD pill immediately or morphs/queues it cleanly.
    @discardableResult
    public func show(
        icon: String? = nil,
        title: String,
        subtitle: String? = nil,
        style: FMHUDStyle = .info,
        duration: TimeInterval? = 2.8,
        action: FMHUDAction? = nil,
        hapticsEnabled: Bool = true
    ) -> UUID {
        let item = FMHUDItem(
            icon: icon,
            title: title,
            subtitle: subtitle,
            style: style,
            duration: duration,
            action: action
        )
        enqueue(item, hapticsEnabled: hapticsEnabled)
        return item.id
    }

    /// Enqueues a pre-built `FMHUDItem`.
    public func enqueue(_ item: FMHUDItem, hapticsEnabled: Bool = true) {
        if activeHUD == nil {
            present(item, hapticsEnabled: hapticsEnabled)
        } else if activeHUD?.style == .loading && item.style != .loading {
            // Morph an active loading capsule directly into its completion state.
            morphActive(to: item, hapticsEnabled: hapticsEnabled)
        } else {
            hudQueue.append(item)
        }
    }

    /// Updates an existing active HUD in-place (e.g., morphing `.loading` into `.success` or `.error`).
    public func update(
        id: UUID,
        icon: String? = nil,
        title: String,
        subtitle: String? = nil,
        style: FMHUDStyle,
        duration: TimeInterval? = 2.6,
        action: FMHUDAction? = nil,
        hapticsEnabled: Bool = true
    ) {
        let updated = FMHUDItem(
            id: id,
            icon: icon,
            title: title,
            subtitle: subtitle,
            style: style,
            duration: duration,
            action: action
        )
        if activeHUD?.id == id {
            morphActive(to: updated, hapticsEnabled: hapticsEnabled)
        } else if let idx = hudQueue.firstIndex(where: { $0.id == id }) {
            hudQueue[idx] = updated
        } else {
            enqueue(updated, hapticsEnabled: hapticsEnabled)
        }
    }

    /// Dismisses the current HUD and advances to the next queued item if present.
    public func dismissCurrent() {
        cancelDismissTimer()
        activeHUD = nil
        if !hudQueue.isEmpty {
            let next = hudQueue.removeFirst()
            present(next, hapticsEnabled: false)
        }
    }

    /// Clears the active HUD and empties the pending queue.
    public func dismissAll() {
        cancelDismissTimer()
        hudQueue.removeAll()
        activeHUD = nil
    }

    private func present(_ item: FMHUDItem, hapticsEnabled: Bool) {
        cancelDismissTimer()
        activeHUD = item
        triggerHaptic(for: item.style, enabled: hapticsEnabled)
        if let duration = item.duration, !isHUDHovered {
            scheduleDismiss(after: duration, for: item.id)
        }
    }

    private func morphActive(to item: FMHUDItem, hapticsEnabled: Bool) {
        cancelDismissTimer()
        activeHUD = item
        triggerHaptic(for: item.style, enabled: hapticsEnabled)
        if let duration = item.duration, !isHUDHovered {
            scheduleDismiss(after: duration, for: item.id)
        }
    }

    private func scheduleDismiss(after seconds: TimeInterval, for id: UUID) {
        cancelDismissTimer()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
            guard !Task.isCancelled, let self, self.activeHUD?.id == id else { return }
            self.dismissCurrent()
        }
    }

    private func cancelDismissTimer() {
        dismissTask?.cancel()
        dismissTask = nil
    }

    private func triggerHaptic(for style: FMHUDStyle, enabled: Bool) {
        switch style {
        case .error, .warning:
            FMHaptics.perform(.generic, enabled: enabled)
        case .success:
            FMHaptics.perform(.levelChange, enabled: enabled)
        case .info:
            FMHaptics.perform(.alignment, enabled: enabled)
        case .loading:
            break
        }
    }
}

private struct FMOverlayCoordinatorKey: EnvironmentKey {
    static let defaultValue = FMOverlayCoordinator()
}

public extension EnvironmentValues {
    /// Window-scoped overlay coordinator injected by `FMWindowContainer`.
    var fmOverlay: FMOverlayCoordinator {
        get { self[FMOverlayCoordinatorKey.self] }
        set { self[FMOverlayCoordinatorKey.self] = newValue }
    }

    /// Convenience alias for triggering Dynamic HUD capsules inside the current window.
    var fmHUD: FMOverlayCoordinator {
        get { self[FMOverlayCoordinatorKey.self] }
        set { self[FMOverlayCoordinatorKey.self] = newValue }
    }
}
