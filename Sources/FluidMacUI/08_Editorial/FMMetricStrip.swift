import SwiftUI

/// Visual body content for a single cell inside `FMMetricStrip`.
public enum FMMetricValue: Sendable, Hashable {
    case text(String)
    case icon(String)
    case rating(Double)
}

/// Descriptor for one column inside `FMMetricStrip`.
public struct FMMetricItem: Identifiable, Sendable, Hashable {
    public let id: String
    public let topLabel: String
    public let value: FMMetricValue
    public let bottomLabel: String?

    public init(
        id: String? = nil,
        topLabel: String,
        value: FMMetricValue,
        bottomLabel: String? = nil
    ) {
        self.id = id ?? topLabel
        self.topLabel = topLabel
        self.value = value
        self.bottomLabel = bottomLabel
    }
}

/// Apple App Store-style horizontal specification & KPI summary bar with crisp vertical
/// 0.5pt hairline separators and optional star ratings, SF Symbols, and tabular numbers.
public struct FMMetricStrip: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    private let items: [FMMetricItem]
    private let showHorizontalDividers: Bool

    public init(items: [FMMetricItem], showHorizontalDividers: Bool = true) {
        self.items = items
        self.showHorizontalDividers = showHorizontalDividers
    }

    public var body: some View {
        VStack(spacing: 0) {
            if showHorizontalDividers {
                FMHairlineDivider()
            }

            HStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    VStack(spacing: 5) {
                        Text(item.topLabel.uppercased())
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .tracking(0.5)
                            .lineLimit(1)

                        metricValueView(item.value)
                            .frame(minHeight: 24)

                        if case .rating(let score) = item.value {
                            FMRatingView(rating: score, starSize: 10.5, tint: .secondary)
                        } else if let bottom = item.bottomLabel, !bottom.isEmpty {
                            Text(bottom)
                                .font(.system(size: 11.5, weight: .regular))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 6)

                    if index < items.count - 1 {
                        Rectangle()
                            .fill(FMColor.separator(colorScheme, highContrast: contrast == .increased))
                            .frame(width: 0.5, height: 34)
                    }
                }
            }

            if showHorizontalDividers {
                FMHairlineDivider()
            }
        }
    }

    @ViewBuilder
    private func metricValueView(_ value: FMMetricValue) -> some View {
        switch value {
        case .text(let str):
            Text(str)
                .font(.fmNumeric(size: 18, weight: .bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

        case .icon(let symbol):
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)

        case .rating(let score):
            Text(String(format: "%.1f", score))
                .font(.fmNumeric(size: 18, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }
}
