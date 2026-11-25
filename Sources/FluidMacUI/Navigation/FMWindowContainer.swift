import SwiftUI

/// Background rendering modes for `FMWindowContainer`.
public enum FMWindowBackdrop: Sendable, Hashable {
    /// Pure Apple first-party macOS detail canvas (`#1C1C1E` dark / `#FFFFFF` light).
    case nativeCanvas
    /// Soft organic multi-color ambient mesh gradient that pauses automatically when window is inactive.
    case ambientMesh
    /// Classic iOS grouped semantic background color.
    case grouped
    /// Translucent desktop-blended vibrancy backdrop.
    case clear
}

/// Immersive titleless macOS window host that blends traffic lights seamlessly into the canvas,
/// manages a window-scoped `FMOverlayCoordinator` (HUD & modal isolation), and renders either
/// a crisp native macOS canvas or an opt-in power-aware ambient backdrop.
public struct FMWindowContainer<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.fmTheme) private var theme

    @State private var windowState = FMWindowState()
    @State private var overlayCoordinator = FMOverlayCoordinator()
    @State private var meshPhase: Bool = false

    private let backdrop: FMWindowBackdrop
    private let isMovableByBackground: Bool
    private let content: Content

    public init(
        backdrop: FMWindowBackdrop = .nativeCanvas,
        isMovableByBackground: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.backdrop = backdrop
        self.isMovableByBackground = isMovableByBackground
        self.content = content()
    }

    public var body: some View {
        ZStack(alignment: .top) {
            backdropLayer
                .ignoresSafeArea()

            // Main content extends edge-to-edge into the top titlebar area (y = 0) so sidebars
            // and floating toolbars align directly with the macOS traffic lights.
            let hasSheet = overlayCoordinator.activeSheetCount > 0
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: .top)
                .scaleEffect(hasSheet ? 0.985 : 1.0)
                .opacity(hasSheet ? 0.92 : 1.0)
                .fmAnimation(.modal, value: hasSheet)

            // Window-scoped Dynamic Island HUD host layer.
            FMDynamicHUDHostView(coordinator: overlayCoordinator)
                .padding(.top, 8)
                .zIndex(900)
        }
        .ignoresSafeArea(.container, edges: .top)
        .background {
            FMWindowAccessor(
                isMovableByBackground: isMovableByBackground,
                windowState: windowState
            )
            .frame(width: 0, height: 0)
        }
        .environment(\.fmWindowState, windowState)
        .environment(\.fmOverlay, overlayCoordinator)
    }

    @ViewBuilder
    private var backdropLayer: some View {
        switch backdrop {
        case .nativeCanvas:
            FMColor.canvasBackground(colorScheme)

        case .grouped:
            FMColor.groupedBackground(colorScheme)

        case .clear:
            Rectangle().fill(.ultraThinMaterial)

        case .ambientMesh:
            let isPaused = activeState == .inactive || reduceMotion
            ZStack {
                FMColor.canvasBackground(colorScheme)

                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                        [0.0, 0.5], [meshPhase && !isPaused ? 0.58 : 0.42, meshPhase && !isPaused ? 0.44 : 0.56], [1.0, 0.5],
                        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                    ],
                    colors: meshColors(dimmed: activeState == .inactive)
                )
                .opacity(colorScheme == .dark ? 0.28 : 0.20)
                .blur(radius: 40)
                .onAppear {
                    guard !isPaused else { return }
                    withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                        meshPhase = true
                    }
                }
                .onChange(of: isPaused) { _, paused in
                    if paused {
                        withAnimation(.easeOut(duration: 0.4)) {
                            meshPhase = false
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                            meshPhase = true
                        }
                    }
                }
            }
        }
    }

    private func meshColors(dimmed: Bool) -> [Color] {
        let base = FMColor.canvasBackground(colorScheme)
        if dimmed {
            return Array(repeating: base, count: 9)
        }
        let accent = theme.accentColor
        let secondary = FMColor.purple
        let tertiary = FMColor.teal
        return [
            accent.opacity(0.65), base, secondary.opacity(0.45),
            base, accent.opacity(0.45), tertiary.opacity(0.5),
            tertiary.opacity(0.35), base, secondary.opacity(0.55)
        ]
    }
}

/// Top-edge Dynamic Island HUD presentation view bound to a window's `FMOverlayCoordinator`.
public struct FMDynamicHUDHostView: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let coordinator: FMOverlayCoordinator

    public init(coordinator: FMOverlayCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack {
            if let item = coordinator.activeHUD {
                FMDynamicHUDCapsule(item: item) {
                    coordinator.dismissCurrent()
                }
                .onHover { hovering in
                    coordinator.isHUDHovered = hovering
                }
                .transition(
                    reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .move(edge: .top).combined(with: .scale(scale: 0.72, anchor: .top)).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .scale(scale: 0.82, anchor: .top)).combined(with: .opacity)
                        )
                )
            }
        }
        .frame(maxWidth: .infinity)
        .fmAnimation(.modal, value: coordinator.activeHUD?.id)
        .fmAnimation(.modal, value: coordinator.activeHUD?.style)
    }
}

private struct FMDynamicHUDCapsule: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: FMHUDItem
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: FMSpacing.sm) {
            ZStack {
                if item.style == .loading {
                    FMSpinner(style: .ring, size: .small, tint: item.style.tintColor)
                } else {
                    Image(systemName: item.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(item.style.tintColor)
                        .symbolEffect(.bounce, value: item.id)
                }
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.fmHeadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.fmFootnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if let action = item.action {
                Button(action.title) {
                    action.handler()
                    onDismiss()
                }
                .buttonStyle(.fm(.tinted, isCapsule: true, color: item.style.tintColor))
                .controlSize(.small)
                .padding(.leading, 4)
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .background(FMColor.controlFill(colorScheme), in: Circle())
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .accessibilityLabel("Dismiss notification")
        }
        .padding(.horizontal, FMSpacing.md)
        .padding(.vertical, 9)
        .fmGlassSurface(.regular, isCapsule: true, showShadow: true)
        .accessibilityElement(children: .contain)
    }
}
