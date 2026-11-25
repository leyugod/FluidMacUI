import SwiftUI

/// iOS-proportioned capsule switch with tactile press-and-hold thumb elongation (squish effect),
/// Force Touch alignment haptics, hover feedback, and density-aware scaling.
public struct FMToggleStyle: ToggleStyle {
    public let tint: Color?

    public init(tint: Color? = nil) {
        self.tint = tint
    }

    public func makeBody(configuration: Configuration) -> some View {
        FMToggleBody(configuration: configuration, customTint: tint)
    }
}

private struct FMToggleBody: View {
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

    var body: some View {
        let size = density.toggleSize
        let inset: CGFloat = 2
        let baseThumb = size.height - inset * 2
        let thumbWidth = isPressed ? baseThumb * 1.24 : baseThumb
        let activeTint = FMColor.adaptiveAccent(
            customTint ?? FMColor.green,
            activeState: activeState,
            scheme: colorScheme
        )
        let offTrack = colorScheme == .dark
            ? Color.white.opacity(isHovered ? 0.22 : 0.16)
            : Color.black.opacity(isHovered ? 0.18 : 0.12)

        HStack(spacing: FMSpacing.sm) {
            configuration.label

            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule(style: .continuous)
                    .fill(configuration.isOn ? activeTint : offTrack)
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(
                                Color.white.opacity(colorScheme == .dark ? 0.10 : 0.18),
                                lineWidth: 0.5
                            )
                    }

                Capsule(style: .continuous)
                    .fill(.white)
                    .frame(width: thumbWidth, height: baseThumb)
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1.5)
                    .padding(inset)
            }
            .frame(width: size.width, height: size.height)
            .brightness(isHovered && isEnabled ? 0.03 : 0)
            .opacity(isEnabled ? 1.0 : 0.45)
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
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled else { return }
                        if !isPressed {
                            isPressed = true
                        }
                        // Allow scrubbing right/left directly on the switch capsule.
                        if value.translation.width > 12 && !configuration.isOn {
                            setValue(true)
                        } else if value.translation.width < -12 && configuration.isOn {
                            setValue(false)
                        }
                    }
                    .onEnded { value in
                        guard isEnabled else { return }
                        let wasTap = abs(value.translation.width) < 10 && abs(value.translation.height) < 10
                        isPressed = false
                        if wasTap {
                            toggleValue()
                        }
                    }
            )
            .onHover { hovering in
                isHovered = hovering
            }
            .fmAnimation(.micro, value: configuration.isOn)
            .fmAnimation(.micro, value: isPressed)
            .fmAnimation(.micro, value: isHovered)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(configuration.isOn ? "On" : "Off")
        }
    }

    private func toggleValue() {
        setValue(!configuration.isOn)
    }

    private func setValue(_ newValue: Bool) {
        guard isEnabled, configuration.isOn != newValue else { return }
        configuration.isOn = newValue
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
    }
}

public extension ToggleStyle where Self == FMToggleStyle {
    static var fmSwitch: FMToggleStyle { FMToggleStyle() }

    static func fmSwitch(tint: Color) -> FMToggleStyle {
        FMToggleStyle(tint: tint)
    }
}
