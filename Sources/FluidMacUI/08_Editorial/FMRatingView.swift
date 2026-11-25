import SwiftUI

/// Star rating display & interactive input supporting exact fractional fills (e.g., 4.7 stars)
/// as well as interactive pointer clicking with Force Touch haptics.
public struct FMRatingView: View {
    @Environment(\.fmTheme) private var theme

    private let maxRating: Int
    private let starSize: CGFloat
    private let tint: Color
    private let readOnlyRating: Double
    private let bindingRating: Binding<Double>?

    public init(
        rating: Double,
        maxRating: Int = 5,
        starSize: CGFloat = 13,
        tint: Color = FMColor.orange
    ) {
        self.readOnlyRating = min(max(rating, 0), Double(maxRating))
        self.bindingRating = nil
        self.maxRating = max(1, maxRating)
        self.starSize = starSize
        self.tint = tint
    }

    public init(
        rating: Binding<Double>,
        maxRating: Int = 5,
        starSize: CGFloat = 18,
        tint: Color = FMColor.orange
    ) {
        self.readOnlyRating = rating.wrappedValue
        self.bindingRating = rating
        self.maxRating = max(1, maxRating)
        self.starSize = starSize
        self.tint = tint
    }

    private var currentRating: Double {
        bindingRating?.wrappedValue ?? readOnlyRating
    }

    public var body: some View {
        HStack(spacing: max(2, starSize * 0.16)) {
            ForEach(1...maxRating, id: \.self) { index in
                let fillAmount = min(max(currentRating - Double(index - 1), 0), 1)
                starGlyph(fill: fillAmount)
                    .onTapGesture {
                        guard let bindingRating else { return }
                        bindingRating.wrappedValue = Double(index)
                        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating")
        .accessibilityValue(String(format: "%.1f out of %d stars", currentRating, maxRating))
    }

    @ViewBuilder
    private func starGlyph(fill: Double) -> some View {
        ZStack {
            Image(systemName: "star.fill")
                .font(.system(size: starSize))
                .foregroundStyle(Color.secondary.opacity(0.28))

            Image(systemName: "star.fill")
                .font(.system(size: starSize))
                .foregroundStyle(tint)
                .mask(alignment: .leading) {
                    GeometryReader { proxy in
                        Rectangle()
                            .frame(width: proxy.size.width * fill)
                    }
                }
        }
        .frame(width: starSize + 1, height: starSize + 1)
    }
}
