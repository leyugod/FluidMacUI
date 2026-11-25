import SwiftUI

/// Visual style for `FMBadge` and `FMTag`.
public enum FMBadgeStyle: Sendable, Hashable {
    /// Saturated solid capsule with white foreground.
    case solid
    /// Soft translucent tinted background (`15%`) with vibrant foreground text.
    case tinted
    /// Subtle outlined capsule pill.
    case outline
}

/// iOS-style capsule status badge supporting solid, tinted, and outline styles,
/// optional icon or status dot, and numeric text transitions.
public struct FMBadge: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState

    private let text: String
    private let color: Color
    private let style: FMBadgeStyle
    private let icon: String?
    private let showsDot: Bool

    public init(
        _ text: String,
        color: Color = FMColor.blue,
        style: FMBadgeStyle = .tinted,
        icon: String? = nil,
        showsDot: Bool = false
    ) {
        self.text = text
        self.color = color
        self.style = style
        self.icon = icon
        self.showsDot = showsDot
    }

    public var body: some View {
        let tint = FMColor.adaptiveAccent(color, activeState: activeState, scheme: colorScheme)

        HStack(spacing: 4) {
            if showsDot {
                Circle()
                    .fill(style == .solid ? Color.white : tint)
                    .frame(width: 6, height: 6)
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .bold))
            }

            Text(text)
                .font(.fmCaption)
                .contentTransition(.numericText())
        }
        .foregroundStyle(style == .solid ? Color.white : tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background {
            switch style {
            case .solid:
                Capsule(style: .continuous).fill(tint)
            case .tinted:
                Capsule(style: .continuous).fill(tint.opacity(colorScheme == .dark ? 0.22 : 0.14))
            case .outline:
                Capsule(style: .continuous).fill(.clear)
            }
        }
        .overlay {
            if style == .outline {
                Capsule(style: .continuous).strokeBorder(tint.opacity(0.6), lineWidth: 1)
            }
        }
    }
}

/// Convenience semantic alias matching tag-oriented usage.
public typealias FMTag = FMBadge
