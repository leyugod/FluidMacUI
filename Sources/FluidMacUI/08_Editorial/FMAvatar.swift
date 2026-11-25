import SwiftUI

/// Presence indicator state for `FMAvatar`.
public enum FMAvatarStatus: Sendable, Hashable {
    case online
    case busy
    case away
    case offline

    public var color: Color {
        switch self {
        case .online: FMColor.green
        case .busy: FMColor.red
        case .away: FMColor.orange
        case .offline: Color.secondary
        }
    }
}

/// Circular macOS user avatar supporting image, initials gradient fallback, SF Symbol icon,
/// and optional status indicator dot with customizable cutout ring.
public struct FMAvatar: View {
    @Environment(\.colorScheme) private var colorScheme

    private let image: Image?
    private let initials: String?
    private let systemImage: String?
    private let color: Color
    private let size: CGFloat
    private let status: FMAvatarStatus?
    private let cutoutColor: Color?

    public init(
        image: Image,
        size: CGFloat = 34,
        status: FMAvatarStatus? = nil,
        cutoutColor: Color? = nil
    ) {
        self.image = image
        self.initials = nil
        self.systemImage = nil
        self.color = FMColor.blue
        self.size = size
        self.status = status
        self.cutoutColor = cutoutColor
    }

    public init(
        initials: String,
        color: Color = FMColor.indigo,
        size: CGFloat = 34,
        status: FMAvatarStatus? = nil,
        cutoutColor: Color? = nil
    ) {
        self.image = nil
        self.initials = initials
        self.systemImage = nil
        self.color = color
        self.size = size
        self.status = status
        self.cutoutColor = cutoutColor
    }

    public init(
        systemImage: String = "person.fill",
        color: Color = FMColor.blue,
        size: CGFloat = 34,
        status: FMAvatarStatus? = nil,
        cutoutColor: Color? = nil
    ) {
        self.image = nil
        self.initials = nil
        self.systemImage = systemImage
        self.color = color
        self.size = size
        self.status = status
        self.cutoutColor = cutoutColor
    }

    public var body: some View {
        let ringStroke = cutoutColor ?? FMColor.canvasBackground(colorScheme)

        ZStack(alignment: .bottomTrailing) {
            Group {
                if let image {
                    image
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.84), color],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            if let initials {
                                Text(initials.prefix(2).uppercased())
                                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            } else if let systemImage {
                                Image(systemName: systemImage)
                                    .font(.system(size: size * 0.44, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                }
            }
            .overlay {
                Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
            }
            .frame(width: size, height: size)

            if let status {
                let dotSize = max(8, size * 0.28)
                Circle()
                    .fill(status.color)
                    .frame(width: dotSize, height: dotSize)
                    .overlay {
                        Circle()
                            .stroke(ringStroke, lineWidth: 2)
                    }
            }
        }
    }
}

/// Overlapping circular avatar stack with automatic `+N` overflow counter pill.
public struct FMAvatarGroup: View {
    @Environment(\.colorScheme) private var colorScheme

    /// Member descriptor rendered inside `FMAvatarGroup`.
    public struct Member: Identifiable, Sendable {
        public let id: String
        public let initials: String
        public let color: Color

        public init(id: String = UUID().uuidString, initials: String, color: Color) {
            self.id = id
            self.initials = initials
            self.color = color
        }
    }

    private let members: [Member]
    private let maxVisible: Int
    private let size: CGFloat

    public init(members: [Member], maxVisible: Int = 4, size: CGFloat = 30) {
        self.members = members
        self.maxVisible = max(1, maxVisible)
        self.size = size
    }

    public var body: some View {
        let visible = Array(members.prefix(maxVisible))
        let overflow = max(0, members.count - visible.count)

        HStack(spacing: -(size * 0.26)) {
            ForEach(visible) { member in
                FMAvatar(initials: member.initials, color: member.color, size: size)
                    .overlay {
                        Circle().stroke(FMColor.canvasBackground(colorScheme), lineWidth: 2)
                    }
            }

            if overflow > 0 {
                Circle()
                    .fill(FMColor.controlFill(colorScheme))
                    .frame(width: size, height: size)
                    .overlay {
                        Text("+\(overflow)")
                            .font(.fmNumeric(size: size * 0.34, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .overlay {
                        Circle().stroke(FMColor.canvasBackground(colorScheme), lineWidth: 2)
                    }
            }
        }
    }
}
