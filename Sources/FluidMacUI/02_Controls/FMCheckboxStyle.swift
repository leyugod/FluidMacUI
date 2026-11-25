import SwiftUI

/// iOS Reminders-inspired circular checkbox with elastic pop animation
/// and stroke-trimmed checkmark drawing.
public struct FMCheckboxStyle: ToggleStyle {
    public let tint: Color?

    public init(tint: Color? = nil) {
        self.tint = tint
    }

    public func makeBody(configuration: Configuration) -> some View {
        FMCheckboxBody(configuration: configuration, customTint: tint)
    }
}

private struct FMCheckmarkShape: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY + rect.height * 0.52))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.43, y: rect.minY + rect.height * 0.73))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.78, y: rect.minY + rect.height * 0.30))
        return path
    }
}

private struct FMCheckboxBody: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.isEnabled) private var isEnabled

    @State private var isPressed = false
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    let configuration: ToggleStyle.Configuration
    let customTint: Color?

    private var circleSize: CGFloat {
        switch density {
        case .compact: 18
        case .regular: 22
        case .comfortable: 25
        }
    }

    var body: some View {
        let accent = FMColor.adaptiveAccent(
            customTint ?? theme.accentColor,
            activeState: activeState,
            scheme: colorScheme
        )

        HStack(spacing: FMSpacing.xs) {
            ZStack {
                Circle()
                    .fill(configuration.isOn ? accent : .clear)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                configuration.isOn
                                    ? accent
                                    : (isHovered ? accent.opacity(0.75) : Color.secondary.opacity(0.45)),
                                lineWidth: configuration.isOn ? 0 : 1.75
                            )
                    }

                FMCheckmarkShape()
                    .trim(from: 0, to: configuration.isOn ? 1 : 0)
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round)
                    )
                    .padding(2)
            }
            .frame(width: circleSize, height: circleSize)
            .scaleEffect(isPressed ? 0.86 : 1.0)
            .focusable(isEnabled)
            .focused($isFocused)
            .focusEffectDisabled()
            .fmFocusRing(isFocused: isFocused, isCapsule: true, color: customTint)
            .onKeyPress(.space) {
                toggleValue()
                return .handled
            }
            .onKeyPress(.return) {
                toggleValue()
                return .handled
            }

            configuration.label
                .font(.fmBody)
        }
        .opacity(isEnabled ? 1.0 : 0.45)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard isEnabled else { return }
                    isPressed = true
                }
                .onEnded { value in
                    guard isEnabled else { return }
                    isPressed = false
                    if abs(value.translation.width) < 24 && abs(value.translation.height) < 24 {
                        toggleValue()
                    }
                }
        )
        .onHover { isHovered = $0 }
        .fmAnimation(.micro, value: configuration.isOn)
        .fmAnimation(.micro, value: isPressed)
        .fmAnimation(.micro, value: isHovered)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(configuration.isOn ? "Checked" : "Unchecked")
    }

    private func toggleValue() {
        guard isEnabled else { return }
        configuration.isOn.toggle()
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
    }
}

public extension ToggleStyle where Self == FMCheckboxStyle {
    static var fmCheckbox: FMCheckboxStyle { FMCheckboxStyle() }

    static func fmCheckbox(tint: Color) -> FMCheckboxStyle {
        FMCheckboxStyle(tint: tint)
    }
}
