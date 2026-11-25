import SwiftUI

/// Full-window media & preview lightbox overlay with keyboard `←` / `→` navigation,
/// floating circular Liquid Glass controls, item counter badge, and `Esc` dismissal.
public struct FMLightboxModifier<Item: Identifiable & Equatable, PreviewContent: View>: ViewModifier {
    @Environment(\.fmTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @Binding private var selectedItem: Item?
    private let items: [Item]
    private let preview: (Item) -> PreviewContent

    public init(
        selectedItem: Binding<Item?>,
        items: [Item],
        @ViewBuilder preview: @escaping (Item) -> PreviewContent
    ) {
        self._selectedItem = selectedItem
        self.items = items
        self.preview = preview
    }

    private var currentIndex: Int? {
        guard let selectedItem else { return nil }
        return items.firstIndex(of: selectedItem)
    }

    public func body(content: Content) -> some View {
        ZStack {
            content

            if let current = selectedItem {
                Color.black.opacity(reduceTransparency ? 0.92 : 0.78)
                    .ignoresSafeArea()
                    .onTapGesture { selectedItem = nil }
                    .transition(.opacity)
                    .zIndex(920)

                ZStack {
                    preview(current)
                        .padding(48)
                        .id(current.id)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .scale(scale: 0.94).combined(with: .opacity)
                        )

                    // Top bar with counter & close button
                    VStack {
                        HStack {
                            if let idx = currentIndex {
                                Text("\(idx + 1) / \(items.count)")
                                    .font(.fmNumeric(size: 12.5, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Color.black.opacity(reduceTransparency ? 0.88 : 0.58),
                                        in: Capsule(style: .continuous)
                                    )
                                    .overlay {
                                        Capsule(style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.75)
                                    }
                                    .accessibilityLabel("Item \(idx + 1) of \(items.count)")
                            }
                            Spacer()
                            FMToolbarButton(icon: "xmark", diameter: 34) {
                                selectedItem = nil
                            }
                            .accessibilityLabel("Close")
                        }
                        .padding(20)
                        Spacer()
                    }

                    // Left / right arrows
                    if items.count > 1, let idx = currentIndex {
                        HStack {
                            FMToolbarButton(icon: "chevron.left", diameter: 38) {
                                step(by: -1)
                            }
                            .accessibilityLabel("Previous")
                            .disabled(idx == 0)
                            .opacity(idx == 0 ? 0.3 : 1)

                            Spacer()

                            FMToolbarButton(icon: "chevron.right", diameter: 38) {
                                step(by: 1)
                            }
                            .accessibilityLabel("Next")
                            .disabled(idx >= items.count - 1)
                            .opacity(idx >= items.count - 1 ? 0.3 : 1)
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .zIndex(930)
                .background {
                    Group {
                        Button("") { selectedItem = nil }
                            .keyboardShortcut(.escape, modifiers: [])
                        Button("") { step(by: -1) }
                            .keyboardShortcut(.leftArrow, modifiers: [])
                        Button("") { step(by: 1) }
                            .keyboardShortcut(.rightArrow, modifiers: [])
                    }
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
                }
            }
        }
        .fmAnimation(.modal, value: selectedItem)
    }

    private func step(by delta: Int) {
        guard let idx = currentIndex else { return }
        let target = idx + delta
        guard items.indices.contains(target) else { return }
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
        selectedItem = items[target]
    }
}

public extension View {
    /// Presents a full-window FluidMacUI lightbox gallery whenever `selectedItem` is non-nil.
    func fmLightbox<Item: Identifiable & Equatable, PreviewContent: View>(
        selectedItem: Binding<Item?>,
        items: [Item],
        @ViewBuilder preview: @escaping (Item) -> PreviewContent
    ) -> some View {
        modifier(
            FMLightboxModifier(
                selectedItem: selectedItem,
                items: items,
                preview: preview
            )
        )
    }
}
