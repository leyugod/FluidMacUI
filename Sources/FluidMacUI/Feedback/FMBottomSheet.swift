import SwiftUI

/// iOS `UISheetPresentationController`-inspired elastic bottom card drawer for macOS,
/// featuring a top grabber handle, interactive downward drag dismissal with rubber-band
/// resistance, `Escape` key dismissal, and background canvas depth scaling.
public struct FMBottomSheetModifier<SheetContent: View>: ViewModifier {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmOverlay) private var overlay
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding private var isPresented: Bool
    private let maxWidth: CGFloat
    private let showsGrabber: Bool
    private let dismissOnBackdropTap: Bool
    private let sheetContent: () -> SheetContent

    @State private var dragOffset: CGFloat = 0
    @State private var isTrackedInOverlay = false

    public init(
        isPresented: Binding<Bool>,
        maxWidth: CGFloat = 520,
        showsGrabber: Bool = true,
        dismissOnBackdropTap: Bool = true,
        @ViewBuilder content: @escaping () -> SheetContent
    ) {
        self._isPresented = isPresented
        self.maxWidth = maxWidth
        self.showsGrabber = showsGrabber
        self.dismissOnBackdropTap = dismissOnBackdropTap
        self.sheetContent = content
    }

    public func body(content: Content) -> some View {
        ZStack {
            content

            if isPresented {
                Color.black.opacity(colorScheme == .dark ? 0.45 : 0.28)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        if dismissOnBackdropTap {
                            dismissSheet()
                        }
                    }
                    .zIndex(700)

                VStack(spacing: 0) {
                    Spacer(minLength: FMSpacing.xl)

                    VStack(spacing: 0) {
                        if showsGrabber {
                            Capsule(style: .continuous)
                                .fill(Color.secondary.opacity(0.38))
                                .frame(width: 40, height: 5)
                                .padding(.top, 10)
                                .padding(.bottom, 6)
                        }

                        sheetContent()
                    }
                    .frame(maxWidth: maxWidth)
                    .fmGlassSurface(.regular, cornerRadius: FMCornerRadius.sheet, showShadow: true)
                    .padding(.horizontal, FMSpacing.lg)
                    .padding(.bottom, FMSpacing.lg)
                    .offset(y: dragOffset)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { value in
                                let y = value.translation.height
                                let x = value.translation.width
                                guard abs(y) > abs(x) * 1.4 || dragOffset != 0 else { return }
                                dragOffset = y < 0 ? y * 0.16 : y
                            }
                            .onEnded { value in
                                guard dragOffset != 0 else { return }
                                let predicted = value.predictedEndTranslation.height
                                if value.translation.height > 90 || predicted > 160 {
                                    dismissSheet()
                                } else {
                                    let snapAnim = FMSpring.animation(.modal, reduceMotion: reduceMotion, speed: theme.animationSpeed)
                                    withAnimation(snapAnim) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
                    .onKeyPress(.escape) {
                        dismissSheet()
                        return .handled
                    }
                }
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                .zIndex(710)
                .background {
                    Button("") { dismissSheet() }
                        .keyboardShortcut(.escape, modifiers: [])
                        .opacity(0)
                        .frame(width: 0, height: 0)
                        .accessibilityHidden(true)
                }
            }
        }
        .fmAnimation(.modal, value: isPresented)
        .onChange(of: isPresented, initial: true) { _, presented in
            syncOverlayCount(presented: presented)
            if presented {
                dragOffset = 0
                FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
            }
        }
        .onDisappear {
            syncOverlayCount(presented: false)
        }
    }

    private func dismissSheet() {
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
        dragOffset = 0
        isPresented = false
    }

    private func syncOverlayCount(presented: Bool) {
        if presented && !isTrackedInOverlay {
            isTrackedInOverlay = true
            overlay.activeSheetCount += 1
        } else if !presented && isTrackedInOverlay {
            isTrackedInOverlay = false
            overlay.activeSheetCount = max(0, overlay.activeSheetCount - 1)
        }
    }
}

public extension View {
    /// Presents a FluidMacUI elastic bottom sheet within the current window hierarchy.
    func fmBottomSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        maxWidth: CGFloat = 520,
        showsGrabber: Bool = true,
        dismissOnBackdropTap: Bool = true,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        modifier(
            FMBottomSheetModifier(
                isPresented: isPresented,
                maxWidth: maxWidth,
                showsGrabber: showsGrabber,
                dismissOnBackdropTap: dismissOnBackdropTap,
                content: content
            )
        )
    }
}
