import SwiftUI

/// Tactile macOS keyboard keycap badge (e.g. `⌘`, `K`) with subtle top rim and depth border.
public struct FMKeycap: View {
    @Environment(\.colorScheme) private var colorScheme
    private let keys: [String]

    public init(_ keys: String...) {
        self.keys = keys
    }

    public init(keys: [String]) {
        self.keys = keys
    }

    public var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                let shape = RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                Text(key)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5.5)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(
                        colorScheme == .dark ? Color.white.opacity(0.09) : Color.white.opacity(0.92),
                        in: shape
                    )
                    .overlay {
                        shape.strokeBorder(
                            colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.14),
                            lineWidth: 0.75
                        )
                    }
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.1), radius: 0, y: 1)
            }
        }
    }
}

/// Floating glass hover tooltip replacing macOS's legacy `.help()` banner,
/// with configurable hover delay and optional shortcut keycaps.
public struct FMTooltipModifier: ViewModifier {
    private let text: String
    private let shortcutKeys: [String]
    private let edge: Edge
    private let delay: Duration

    @State private var isVisible = false
    @State private var hoverTask: Task<Void, Never>?

    public init(
        _ text: String,
        shortcutKeys: [String] = [],
        edge: Edge = .top,
        delay: Duration = .milliseconds(420)
    ) {
        self.text = text
        self.shortcutKeys = shortcutKeys
        self.edge = edge
        self.delay = delay
    }

    public func body(content: Content) -> some View {
        content
            .onHover { hovering in
                hoverTask?.cancel()
                if hovering {
                    hoverTask = Task {
                        try? await Task.sleep(for: delay)
                        guard !Task.isCancelled else { return }
                        isVisible = true
                    }
                } else {
                    isVisible = false
                }
            }
            .onDisappear {
                hoverTask?.cancel()
                isVisible = false
            }
            .overlay(alignment: alignmentForEdge) {
                if isVisible {
                    HStack(spacing: FMSpacing.xs) {
                        Text(text)
                            .font(.fmFootnote)
                            .foregroundStyle(.primary)
                            .fixedSize()

                        if !shortcutKeys.isEmpty {
                            FMKeycap(keys: shortcutKeys)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .fmGlassSurface(.regular, cornerRadius: 10, showShadow: true)
                    .offset(offsetForEdge)
                    .allowsHitTesting(false)
                    .transition(.scale(scale: 0.9, anchor: scaleAnchor).combined(with: .opacity))
                    .zIndex(950)
                }
            }
            .fmAnimation(.micro, value: isVisible)
    }

    private var alignmentForEdge: Alignment {
        switch edge {
        case .top: .top
        case .bottom: .bottom
        case .leading: .leading
        case .trailing: .trailing
        }
    }

    private var scaleAnchor: UnitPoint {
        switch edge {
        case .top: .bottom
        case .bottom: .top
        case .leading: .trailing
        case .trailing: .leading
        }
    }

    private var offsetForEdge: CGSize {
        switch edge {
        case .top: CGSize(width: 0, height: -36)
        case .bottom: CGSize(width: 0, height: 36)
        case .leading: CGSize(width: -12, height: 0)
        case .trailing: CGSize(width: 12, height: 0)
        }
    }
}

public extension View {
    /// Attaches a floating FluidMacUI glass tooltip with optional shortcut keycaps.
    func fmTooltip(
        _ text: String,
        shortcut: [String] = [],
        edge: Edge = .top,
        delay: Duration = .milliseconds(420)
    ) -> some View {
        modifier(FMTooltipModifier(text, shortcutKeys: shortcut, edge: edge, delay: delay))
    }
}
