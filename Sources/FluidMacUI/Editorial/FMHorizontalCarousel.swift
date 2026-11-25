import SwiftUI

/// Horizontal preview & media gallery carousel (matching App Store `Preview` strip),
/// featuring swipe-back conflict protection and hover-revealed floating Liquid Glass
/// prev/next buttons for effortless desktop mouse browsing.
public struct FMHorizontalCarousel<Data: RandomAccessCollection, ItemView: View>: View where Data.Element: Identifiable {
    @Environment(\.fmTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let items: Data
    private let spacing: CGFloat
    private let horizontalPadding: CGFloat
    private let itemView: (Data.Element) -> ItemView

    @State private var isHovered = false
    @State private var scrollPositionID: Data.Element.ID?

    public init(
        _ items: Data,
        spacing: CGFloat = 16,
        horizontalPadding: CGFloat = 0,
        @ViewBuilder itemView: @escaping (Data.Element) -> ItemView
    ) {
        self.items = items
        self.spacing = spacing
        self.horizontalPadding = horizontalPadding
        self.itemView = itemView
    }

    private var ids: [Data.Element.ID] {
        items.map(\.id)
    }

    public var body: some View {
        ZStack {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: spacing) {
                    ForEach(items) { item in
                        itemView(item)
                            .id(item.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, horizontalPadding)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollPositionID)
            .fmSwipeBackDisabled(true)

            // Desktop hover glass navigation arrows
            if isHovered && items.count > 1 {
                HStack {
                    FMToolbarButton(icon: "chevron.left", diameter: 34) {
                        step(by: -1)
                    }
                    .accessibilityLabel("Previous")
                    .padding(.leading, 8)
                    .opacity(canStepBackward ? 1 : 0.25)
                    .disabled(!canStepBackward)

                    Spacer()

                    FMToolbarButton(icon: "chevron.right", diameter: 34) {
                        step(by: 1)
                    }
                    .accessibilityLabel("Next")
                    .padding(.trailing, 8)
                    .opacity(canStepForward ? 1 : 0.25)
                    .disabled(!canStepForward)
                }
                .transition(.opacity)
            }
        }
        .onHover { isHovered = $0 }
        .fmAnimation(.micro, value: isHovered)
    }

    private var currentIndex: Int {
        guard let id = scrollPositionID, let idx = ids.firstIndex(of: id) else { return 0 }
        return idx
    }

    private var canStepBackward: Bool {
        currentIndex > 0
    }

    private var canStepForward: Bool {
        currentIndex < max(0, ids.count - 1)
    }

    private func step(by delta: Int) {
        guard !ids.isEmpty else { return }
        let target = max(0, min(ids.count - 1, currentIndex + delta))
        withAnimation(FMSpring.animation(.navigation, reduceMotion: reduceMotion, speed: theme.animationSpeed)) {
            scrollPositionID = ids[target]
        }
    }
}
