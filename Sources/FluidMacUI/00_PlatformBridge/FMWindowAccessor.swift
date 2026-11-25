import SwiftUI
import AppKit

/// Tracks live state of the hosting `NSWindow` for traffic-light safe areas,
/// full-screen transitions, and key-window focus changes.
@Observable
public final class FMWindowState {
    public var isKeyWindow: Bool = true
    public var isFullScreen: Bool = false
    /// Horizontal width occupied by the macOS traffic-light buttons when not in full screen.
    public var trafficLightsWidth: CGFloat = 78
    /// Distance from top edge of window to bottom edge of traffic-light buttons.
    public var trafficLightsBottomY: CGFloat = 24
    /// Recommended unified top toolbar height aligned with traffic lights.
    public var titleBarHeight: CGFloat = 46

    public init() {}
}

private struct FMWindowStateKey: EnvironmentKey {
    static let defaultValue = FMWindowState()
}

public extension EnvironmentValues {
    /// Observable state of the nearest enclosing `FMWindowContainer`'s hosting `NSWindow`.
    var fmWindowState: FMWindowState {
        get { self[FMWindowStateKey.self] }
        set { self[FMWindowStateKey.self] = newValue }
    }
}

/// Bridges SwiftUI to the hosting `NSWindow` to configure seamless titleless chrome
/// and observe window lifecycle events.
public struct FMWindowAccessor: NSViewRepresentable {
    public var isMovableByBackground: Bool
    public var onWindowResolved: ((NSWindow) -> Void)?
    public var windowState: FMWindowState?

    public init(
        isMovableByBackground: Bool = false,
        windowState: FMWindowState? = nil,
        onWindowResolved: ((NSWindow) -> Void)? = nil
    ) {
        self.isMovableByBackground = isMovableByBackground
        self.windowState = windowState
        self.onWindowResolved = onWindowResolved
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(windowState: windowState)
    }

    public func makeNSView(context: Context) -> NSView {
        let view = WindowObservingView()
        view.onAttach = { [weak coordinator = context.coordinator] window in
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = isMovableByBackground
            window.styleMask.insert(.fullSizeContentView)
            coordinator?.attach(to: window)
            onWindowResolved?(window)
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            window.isMovableByWindowBackground = isMovableByBackground
        }
    }

    public final class Coordinator: NSObject {
        private weak var window: NSWindow?
        private var observers: [NSObjectProtocol] = []
        private let windowState: FMWindowState?

        init(windowState: FMWindowState?) {
            self.windowState = windowState
        }

        isolated deinit {
            let center = NotificationCenter.default
            for observer in observers {
                center.removeObserver(observer)
            }
        }

        func attach(to window: NSWindow) {
            guard self.window !== window else {
                sync(window: window)
                return
            }
            let center = NotificationCenter.default
            for observer in observers {
                center.removeObserver(observer)
            }
            observers.removeAll()
            self.window = window
            sync(window: window)

            let names: [Notification.Name] = [
                NSWindow.didBecomeKeyNotification,
                NSWindow.didResignKeyNotification,
                NSWindow.didEnterFullScreenNotification,
                NSWindow.didExitFullScreenNotification,
                NSWindow.didResizeNotification
            ]

            for name in names {
                let token = center.addObserver(forName: name, object: window, queue: .main) { [weak self, weak window] _ in
                    MainActor.assumeIsolated {
                        guard let self, let window else { return }
                        self.sync(window: window)
                    }
                }
                observers.append(token)
            }
        }

        private func sync(window: NSWindow) {
            guard let state = windowState else { return }
            state.isKeyWindow = window.isKeyWindow
            let fullScreen = window.styleMask.contains(.fullScreen)
            state.isFullScreen = fullScreen

            if fullScreen {
                state.trafficLightsWidth = 0
                state.trafficLightsBottomY = 0
            } else if let zoomBtn = window.standardWindowButton(.zoomButton) {
                let maxX = zoomBtn.frame.maxX
                state.trafficLightsWidth = max(68, maxX + 14)
                if let superview = zoomBtn.superview {
                    // Convert button rect to window coordinates (bottom-left origin -> top-down distance).
                    let rectInWindow = superview.convert(zoomBtn.frame, to: nil)
                    let bottomFromTop = max(18, window.frame.height - rectInWindow.minY)
                    state.trafficLightsBottomY = min(bottomFromTop, 36)
                }
            } else {
                state.trafficLightsWidth = 78
                state.trafficLightsBottomY = 24
            }
        }
    }

    private final class WindowObservingView: NSView {
        var onAttach: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window {
                onAttach?(window)
            }
        }
    }
}

/// An invisible interactive area that enables native window dragging and double-click zoom/miniaturize
/// inside custom titleless `FMWindowContainer` layouts.
public struct FMTitleBarDragArea: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        DragRegionNSView()
    }

    public func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragRegionNSView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func mouseDown(with event: NSEvent) {
            guard let window else {
                super.mouseDown(with: event)
                return
            }
            if event.clickCount == 2 {
                let action = UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") ?? "Maximize"
                switch action {
                case "Minimize":
                    window.miniaturize(nil)
                case "None":
                    break
                default:
                    window.zoom(nil)
                }
            } else {
                window.performDrag(with: event)
            }
        }
    }
}
