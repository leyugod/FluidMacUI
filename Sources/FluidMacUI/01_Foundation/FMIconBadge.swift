import SwiftUI

/// iOS Settings-inspired squircle icon badge with top specular gradient sheen
/// and visually centered SF Symbol rendering.
public struct FMIconBadge: View {
    @Environment(\.fmDensity) private var density
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.colorScheme) private var colorScheme

    public let systemName: String
    public let color: Color
    public let customSize: CGFloat?

    public init(
        _ systemName: String,
        color: Color = FMColor.blue,
        size: CGFloat? = nil
    ) {
        self.systemName = systemName
        self.color = color
        self.customSize = size
    }

    public var body: some View {
        let dimension = customSize ?? density.iconBadgeSize
        let radius = dimension * 0.26
        let tint = FMColor.adaptiveAccent(color, activeState: activeState, scheme: colorScheme)

        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.92),
                            tint
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.38), Color.white.opacity(0.06)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.75
                        )
                }

            Image(systemName: systemName)
                .font(.system(size: dimension * 0.50, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.14), radius: 1, y: 0.5)
        }
        .frame(width: dimension, height: dimension)
        .accessibilityHidden(true)
    }
}
