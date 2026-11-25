import SwiftUI

/// Native macOS right-side collapsible Inspector split container (matching Xcode, Keynote,
/// Pages, and Photos), with a draggable hairline resize splitter and spring collapse animation.
public struct FMInspectorSplitView<Main: View, Inspector: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    @Binding private var isPresented: Bool
    @State private var currentWidth: CGFloat
    private let minWidth: CGFloat
    private let maxWidth: CGFloat
    private let main: Main
    private let inspector: Inspector

    @State private var dragStartWidth: CGFloat?
    @State private var isCursorPushed = false

    public init(
        isPresented: Binding<Bool>,
        defaultWidth: CGFloat = 280,
        minWidth: CGFloat = 240,
        maxWidth: CGFloat = 420,
        @ViewBuilder main: () -> Main,
        @ViewBuilder inspector: () -> Inspector
    ) {
        self._isPresented = isPresented
        self._currentWidth = State(initialValue: min(max(defaultWidth, minWidth), maxWidth))
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.main = main()
        self.inspector = inspector()
    }

    public var body: some View {
        HStack(spacing: 0) {
            main
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isPresented {
                HStack(spacing: 0) {
                    resizeSplitter

                    inspector
                        .frame(width: currentWidth)
                        .frame(maxHeight: .infinity)
                        .background {
                            FMColor.sidebarBackground(colorScheme)
                                .ignoresSafeArea()
                        }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .fmAnimation(.navigation, value: isPresented)
    }

    private var resizeSplitter: some View {
        ZStack {
            Rectangle()
                .fill(FMColor.separator(colorScheme, highContrast: contrast == .increased))
                .frame(width: contrast == .increased ? 1.0 : 0.5)
        }
        .frame(width: 6)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering && !isCursorPushed {
                NSCursor.resizeLeftRight.push()
                isCursorPushed = true
            } else if !hovering && isCursorPushed {
                NSCursor.pop()
                isCursorPushed = false
            }
        }
        .onDisappear {
            if isCursorPushed {
                NSCursor.pop()
                isCursorPushed = false
            }
        }
        .gesture(
            DragGesture(coordinateSpace: .global)
                .onChanged { value in
                    if dragStartWidth == nil {
                        dragStartWidth = currentWidth
                    }
                    let proposed = (dragStartWidth ?? currentWidth) - value.translation.width
                    currentWidth = min(max(proposed, minWidth), maxWidth)
                }
                .onEnded { _ in
                    dragStartWidth = nil
                }
        )
    }
}
