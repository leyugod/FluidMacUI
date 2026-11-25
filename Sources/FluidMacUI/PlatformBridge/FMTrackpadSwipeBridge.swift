import SwiftUI
import AppKit

/// Monitors two-finger horizontal trackpad scroll gestures within the enclosing `NSWindow`
/// to drive interactive swipe-back navigation without breaking vertical scrolling.
public struct FMTrackpadSwipeBridge: NSViewRepresentable {
    public var isEnabled: Bool
    public var onChanged: (CGFloat) -> Void
    public var onEnded: (CGFloat, CGFloat) -> Void

    public init(
        isEnabled: Bool,
        onChanged: @escaping (CGFloat) -> Void,
        onEnded: @escaping (CGFloat, CGFloat) -> Void
    ) {
        self.isEnabled = isEnabled
        self.onChanged = onChanged
        self.onEnded = onEnded
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(isEnabled: isEnabled, onChanged: onChanged, onEnded: onEnded)
    }

    public func makeNSView(context: Context) -> NSView {
        let view = HostNSView()
        view.onWindowChange = { [weak coordinator = context.coordinator] window in
            coordinator?.install(in: window, hostView: view)
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        if let window = nsView.window {
            context.coordinator.install(in: window, hostView: nsView)
        }
    }

    public final class Coordinator {
        var isEnabled: Bool
        var onChanged: (CGFloat) -> Void
        var onEnded: (CGFloat, CGFloat) -> Void

        private weak var window: NSWindow?
        private weak var hostView: NSView?
        private var monitor: Any?

        private var isTrackingHorizontal = false
        private var decidedDirection = false
        private var accumulatedX: CGFloat = 0
        private var lastDeltaX: CGFloat = 0

        init(
            isEnabled: Bool,
            onChanged: @escaping (CGFloat) -> Void,
            onEnded: @escaping (CGFloat, CGFloat) -> Void
        ) {
            self.isEnabled = isEnabled
            self.onChanged = onChanged
            self.onEnded = onEnded
        }

        isolated deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func install(in window: NSWindow?, hostView: NSView) {
            self.hostView = hostView
            guard self.window !== window else { return }
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            self.window = window
            guard window != nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.handle(event: event) ?? event
            }
        }

        private func handle(event: NSEvent) -> NSEvent? {
            guard isEnabled,
                  let window,
                  event.window === window,
                  event.hasPreciseScrollingDeltas else {
                return event
            }

            if let hostView {
                let pointInView = hostView.convert(event.locationInWindow, from: nil)
                guard hostView.bounds.contains(pointInView) else {
                    return event
                }
                // Defer to an enclosing horizontal NSScrollView that still has room to scroll left.
                if !isTrackingHorizontal, let contentView = window.contentView {
                    let pointInContent = contentView.convert(event.locationInWindow, from: nil)
                    if let hit = contentView.hitTest(pointInContent),
                       Self.hasActiveHorizontalScrollAncestor(from: hit) {
                        return event
                    }
                }
            }

            // Ignore pure momentum events once fingers lift.
            if event.momentumPhase != [] && !isTrackingHorizontal {
                return event
            }

            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY

            switch event.phase {
            case .began:
                isTrackingHorizontal = false
                decidedDirection = false
                accumulatedX = 0
                lastDeltaX = 0

            case .changed:
                if !decidedDirection {
                    if abs(dx) > 2.5 || abs(dy) > 2.5 {
                        decidedDirection = true
                        // Only capture clear rightward swipes (dx > 0 on macOS natural scrolling).
                        isTrackingHorizontal = dx > 0 && abs(dx) > abs(dy) * 1.45
                    }
                }
                if isTrackingHorizontal {
                    accumulatedX = max(0, accumulatedX + dx)
                    lastDeltaX = dx
                    onChanged(accumulatedX)
                    return nil
                }

            case .ended, .cancelled:
                if isTrackingHorizontal {
                    let finalTranslation = accumulatedX
                    let velocity = lastDeltaX * 60
                    isTrackingHorizontal = false
                    decidedDirection = false
                    accumulatedX = 0
                    lastDeltaX = 0
                    onEnded(finalTranslation, velocity)
                    return nil
                }
                decidedDirection = false
                accumulatedX = 0

            default:
                break
            }

            return event
        }

        private static func hasActiveHorizontalScrollAncestor(from view: NSView) -> Bool {
            var current: NSView? = view
            while let candidate = current {
                if let scrollView = candidate as? NSScrollView,
                   let documentView = scrollView.documentView {
                    let clipBounds = scrollView.contentView.bounds
                    let canScrollHorizontally = documentView.frame.width > clipBounds.width + 1
                    if canScrollHorizontally && clipBounds.origin.x > 1 {
                        return true
                    }
                }
                current = candidate.superview
            }
            return false
        }
    }

    private final class HostNSView: NSView {
        var onWindowChange: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindowChange?(window)
        }
    }
}
