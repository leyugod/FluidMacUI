import SwiftUI

/// Visual tone for `FMInlineBanner`.
public enum FMBannerTone: Sendable, Hashable {
    case info
    case success
    case warning
    case error

    public var color: Color {
        switch self {
        case .info: FMColor.blue
        case .success: FMColor.green
        case .warning: FMColor.orange
        case .error: FMColor.red
        }
    }

    public var defaultIcon: String {
        switch self {
        case .info: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }
}

/// In-page semantic callout banner (matching macOS System Settings & App Store inline notices).
public struct FMInlineBanner: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let tone: FMBannerTone
    private let icon: String
    private let title: String
    private let message: String?
    private let actionTitle: String?
    private let action: (() -> Void)?
    private let onDismiss: (() -> Void)?

    public init(
        tone: FMBannerTone = .info,
        icon: String? = nil,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.tone = tone
        self.icon = icon ?? tone.defaultIcon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.onDismiss = onDismiss
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        HStack(alignment: .top, spacing: FMSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tone.color)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.fmHeadline)
                    .foregroundStyle(.primary)

                if let message, !message.isEmpty {
                    Text(message)
                        .font(.fmSubheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: FMSpacing.sm)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.fm(.tinted, isCapsule: true, color: tone.color))
                    .controlSize(.small)
            }

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(5)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(.horizontal, FMSpacing.md)
        .padding(.vertical, 12)
        .background(
            reduceTransparency
                ? FMColor.elevatedOpaqueSurface(colorScheme)
                : tone.color.opacity(colorScheme == .dark ? 0.14 : 0.10),
            in: shape
        )
        .overlay {
            shape.strokeBorder(
                tone.color.opacity(contrast == .increased ? 0.68 : 0.28),
                lineWidth: contrast == .increased ? 1.25 : 0.75
            )
        }
    }
}
