import SwiftUI

/// `UIContentUnavailableView`-inspired empty state placeholder with glowing gradient symbol,
/// rounded title, descriptive copy, and optional primary action button.
public struct FMEmptyStateView: View {
    @Environment(\.fmTheme) private var theme

    private let icon: String
    private let iconColor: Color?
    private let title: String
    private let description: String?
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(
        icon: String,
        iconColor: Color? = nil,
        title: String,
        description: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        let tint = iconColor ?? theme.accentColor

        VStack(spacing: FMSpacing.md) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [tint.opacity(0.24), tint.opacity(0.02)],
                            center: .center,
                            startRadius: 6,
                            endRadius: 48
                        )
                    )
                    .frame(width: 88, height: 88)

                FMIconBadge(icon, color: tint, size: 52)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.fmTitle)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                if let description, !description.isEmpty {
                    Text(description)
                        .font(.fmSubheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 340)
                }
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.fmPrimary)
                    .padding(.top, 4)
            }
        }
        .padding(FMSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}
