import SwiftUI

/// Turns any view into a shimmering continuous-curvature skeleton placeholder while loading,
/// automatically downgrading to a calm static placeholder when Reduce Motion is enabled.
public struct FMSkeletonModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.controlActiveState) private var activeState

    let isLoading: Bool
    let cornerRadius: CGFloat

    @State private var shimmerPhase: CGFloat = -0.7

    public init(isLoading: Bool, cornerRadius: CGFloat = FMCornerRadius.micro) {
        self.isLoading = isLoading
        self.cornerRadius = cornerRadius
    }

    private var shouldAnimateShimmer: Bool {
        isLoading && !reduceMotion && activeState != .inactive
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .opacity(isLoading ? 0 : 1)
            .accessibilityHidden(isLoading)
            .overlay {
                if isLoading {
                    GeometryReader { proxy in
                        let width = max(1, proxy.size.width)
                        let base = colorScheme == .dark
                            ? Color.white.opacity(0.09)
                            : Color.black.opacity(0.07)
                        let highlight = colorScheme == .dark
                            ? Color.white.opacity(0.18)
                            : Color.white.opacity(0.65)

                        ZStack {
                            shape.fill(base)

                            if shouldAnimateShimmer {
                                LinearGradient(
                                    colors: [.clear, highlight, .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: width * 0.55)
                                .offset(x: width * shimmerPhase)
                            }
                        }
                        .clipShape(shape)
                    }
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Loading content")
                }
            }
            .allowsHitTesting(!isLoading)
            .fmAnimation(.micro, value: isLoading)
            .onChange(of: shouldAnimateShimmer, initial: true) { _, active in
                if active {
                    shimmerPhase = -0.7
                    withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
                        shimmerPhase = 1.3
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.15)) {
                        shimmerPhase = -0.7
                    }
                }
            }
    }
}

public extension View {
    /// Replaces this view with a fluid skeleton shimmer placeholder while `isLoading` is true.
    func fmSkeleton(isLoading: Bool, cornerRadius: CGFloat = FMCornerRadius.micro) -> some View {
        modifier(FMSkeletonModifier(isLoading: isLoading, cornerRadius: cornerRadius))
    }
}
