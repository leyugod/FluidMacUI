import SwiftUI

/// Semantic button role inside `FMAlert`.
public enum FMAlertButtonRole: Sendable, Hashable {
    case `default`
    case cancel
    case destructive
}

/// Action descriptor for `FMAlert`.
public struct FMAlertButton: Identifiable {
    public let id = UUID()
    public let title: String
    public let role: FMAlertButtonRole
    public let action: () -> Void

    public init(
        _ title: String,
        role: FMAlertButtonRole = .default,
        action: @escaping () -> Void = {}
    ) {
        self.title = title
        self.role = role
        self.action = action
    }
}

/// Pure macOS HIG keyboard-shortcut resolution rules for `FMAlert` (tested independently).
public enum FMAlertShortcutResolver {
    /// Returns the button to trigger on `Escape` (first `.cancel` button).
    public static func cancelButton(in buttons: [FMAlertButton]) -> FMAlertButton? {
        buttons.first(where: { $0.role == .cancel })
    }

    /// Returns the button to trigger on `Return` — strictly limited to `.default` buttons
    /// so destructive actions are never accidentally confirmed by hitting Enter.
    public static func returnButton(in buttons: [FMAlertButton]) -> FMAlertButton? {
        buttons.first(where: { $0.role == .default })
    }
}

/// Centered iOS-style glass modal alert with 1.08 -> 1.0 spring entrance,
/// crisp 0.5pt hairline button dividers, and Return/Escape keyboard shortcuts.
public struct FMAlertModifier: ViewModifier {
    @Environment(\.fmTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding private var isPresented: Bool
    private let title: String
    private let message: String?
    private let icon: String?
    private let iconColor: Color
    private let buttons: [FMAlertButton]

    @State private var hoveredButtonID: UUID?

    public init(
        isPresented: Binding<Bool>,
        title: String,
        message: String? = nil,
        icon: String? = nil,
        iconColor: Color = FMColor.blue,
        buttons: [FMAlertButton]
    ) {
        self._isPresented = isPresented
        self.title = title
        self.message = message
        self.icon = icon
        self.iconColor = iconColor
        self.buttons = buttons
    }

    public func body(content: Content) -> some View {
        ZStack {
            content

            if isPresented {
                Color.black.opacity(colorScheme == .dark ? 0.45 : 0.28)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(800)

                VStack(spacing: 0) {
                    VStack(spacing: FMSpacing.sm) {
                        if let icon {
                            FMIconBadge(icon, color: iconColor, size: 42)
                                .padding(.bottom, 2)
                        }

                        Text(title)
                            .font(.fmTitle2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)

                        if let message, !message.isEmpty {
                            Text(message)
                                .font(.fmSubheadline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, FMSpacing.lg)
                    .padding(.vertical, FMSpacing.lg)

                    Rectangle()
                        .fill(FMColor.separator(colorScheme, highContrast: contrast == .increased))
                        .frame(height: 0.5)

                    if buttons.count == 2 {
                        HStack(spacing: 0) {
                            alertButtonView(buttons[0])
                            Rectangle()
                                .fill(FMColor.separator(colorScheme, highContrast: contrast == .increased))
                                .frame(width: 0.5, height: 44)
                            alertButtonView(buttons[1])
                        }
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(buttons.enumerated()), id: \.element.id) { index, button in
                                alertButtonView(button)
                                if index < buttons.count - 1 {
                                    Rectangle()
                                        .fill(FMColor.separator(colorScheme, highContrast: contrast == .increased))
                                        .frame(height: 0.5)
                                }
                            }
                        }
                    }
                }
                .frame(width: 310)
                .fmGlassSurface(.regular, cornerRadius: FMCornerRadius.sheet - 2, showShadow: true)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .scale(scale: 1.08).combined(with: .opacity),
                            removal: .scale(scale: 0.94).combined(with: .opacity)
                        )
                )
                .zIndex(810)
                .background {
                    Group {
                        if let cancel = FMAlertShortcutResolver.cancelButton(in: buttons) {
                            Button("") { invoke(cancel) }
                                .keyboardShortcut(.escape, modifiers: [])
                        }
                        if let primary = FMAlertShortcutResolver.returnButton(in: buttons) {
                            Button("") { invoke(primary) }
                                .keyboardShortcut(.return, modifiers: [])
                        }
                    }
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
                }
            }
        }
        .fmAnimation(.modal, value: isPresented)
        .onChange(of: isPresented) { _, presented in
            if presented {
                FMHaptics.perform(.generic, enabled: theme.hapticsEnabled)
            }
        }
    }

    @ViewBuilder
    private func alertButtonView(_ button: FMAlertButton) -> some View {
        let isHovered = hoveredButtonID == button.id
        Button {
            invoke(button)
        } label: {
            Text(button.title)
                .font(button.role == .cancel ? .fmBody : .fmHeadline)
                .foregroundStyle(buttonColor(for: button.role))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isHovered ? FMColor.controlFill(colorScheme) : .clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { hovering in
            hoveredButtonID = hovering ? button.id : (hoveredButtonID == button.id ? nil : hoveredButtonID)
        }
    }

    private func buttonColor(for role: FMAlertButtonRole) -> Color {
        switch role {
        case .default: theme.accentColor
        case .cancel: .secondary
        case .destructive: FMColor.red
        }
    }

    private func invoke(_ button: FMAlertButton) {
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
        isPresented = false
        button.action()
    }
}

public extension View {
    /// Presents a centered FluidMacUI glass alert dialog.
    func fmAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String? = nil,
        icon: String? = nil,
        iconColor: Color = FMColor.blue,
        buttons: [FMAlertButton]
    ) -> some View {
        modifier(
            FMAlertModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                icon: icon,
                iconColor: iconColor,
                buttons: buttons
            )
        )
    }
}
