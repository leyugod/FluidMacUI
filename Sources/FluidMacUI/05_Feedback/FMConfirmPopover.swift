import SwiftUI

/// Lightweight anchored confirmation popover (ideal for destructive button confirmations
/// without interrupting the entire window like a centered alert dialog).
public struct FMConfirmPopoverModifier: ViewModifier {
    @Environment(\.fmTheme) private var theme

    @Binding private var isPresented: Bool
    private let title: String
    private let message: String?
    private let confirmTitle: String
    private let cancelTitle: String
    private let isDestructive: Bool
    private let onConfirm: () -> Void

    public init(
        isPresented: Binding<Bool>,
        title: String,
        message: String? = nil,
        confirmTitle: String = "确认",
        cancelTitle: String = "取消",
        isDestructive: Bool = true,
        onConfirm: @escaping () -> Void
    ) {
        self._isPresented = isPresented
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.isDestructive = isDestructive
        self.onConfirm = onConfirm
    }

    public func body(content: Content) -> some View {
        content
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: FMSpacing.sm) {
                    Text(title)
                        .font(.fmHeadline)
                        .foregroundStyle(.primary)

                    if let message, !message.isEmpty {
                        Text(message)
                            .font(.fmFootnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: FMSpacing.xs) {
                        Button(cancelTitle) {
                            isPresented = false
                        }
                        .buttonStyle(.fm(.secondary, fullWidth: true))

                        Button(confirmTitle) {
                            FMHaptics.perform(.generic, enabled: theme.hapticsEnabled)
                            isPresented = false
                            onConfirm()
                        }
                        .buttonStyle(.fm(isDestructive ? .destructive : .primary, fullWidth: true))
                    }
                    .padding(.top, 2)
                }
                .padding(FMSpacing.md)
                .frame(width: 248)
            }
    }
}

public extension View {
    /// Attaches a lightweight anchored confirmation popover to this view.
    func fmConfirmPopover(
        isPresented: Binding<Bool>,
        title: String,
        message: String? = nil,
        confirmTitle: String = "确认",
        cancelTitle: String = "取消",
        isDestructive: Bool = true,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(
            FMConfirmPopoverModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                confirmTitle: confirmTitle,
                cancelTitle: cancelTitle,
                isDestructive: isDestructive,
                onConfirm: onConfirm
            )
        )
    }
}
