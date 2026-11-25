import SwiftUI

/// Horizontal capsule filter chip group supporting single-select or multi-select filtering.
public struct FMFilterChips<Option: Hashable>: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState

    @Binding private var selection: Set<Option>
    private let options: [Option]
    private let allowsMultipleSelection: Bool
    private let titleProvider: (Option) -> String
    private let iconProvider: ((Option) -> String?)?

    @State private var hoveredOption: Option?
    @FocusState private var focusedOption: Option?

    public init(
        selection: Binding<Set<Option>>,
        options: [Option],
        allowsMultipleSelection: Bool = true,
        title: @escaping (Option) -> String,
        icon: ((Option) -> String?)? = nil
    ) {
        self._selection = selection
        self.options = options
        self.allowsMultipleSelection = allowsMultipleSelection
        self.titleProvider = title
        self.iconProvider = icon
    }

    public var body: some View {
        let accent = FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FMSpacing.xs) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection.contains(option)
                    let isHovered = hoveredOption == option && !isSelected

                    Button {
                        toggle(option)
                    } label: {
                        HStack(spacing: 5) {
                            if let icon = iconProvider?(option) {
                                Image(systemName: icon)
                                    .font(.system(size: 11.5, weight: .semibold))
                            }
                            Text(titleProvider(option))
                                .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                        }
                        .foregroundStyle(isSelected ? .white : .primary)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(
                            isSelected
                                ? accent
                                : (isHovered ? FMColor.controlHoverFill(colorScheme) : FMColor.controlFill(colorScheme)),
                            in: Capsule(style: .continuous)
                        )
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(
                                    isSelected ? accent.opacity(0.4) : FMColor.hairlineHighlight(colorScheme),
                                    lineWidth: 0.5
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .focused($focusedOption, equals: option)
                    .focusEffectDisabled()
                    .fmFocusRing(isFocused: focusedOption == option, isCapsule: true)
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                    .onHover { hovering in
                        hoveredOption = hovering ? option : (hoveredOption == option ? nil : hoveredOption)
                    }
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 3)
        }
        .fmAnimation(.micro, value: selection)
        .fmAnimation(.micro, value: hoveredOption)
    }

    private func toggle(_ option: Option) {
        if allowsMultipleSelection {
            if selection.contains(option) {
                selection.remove(option)
            } else {
                selection.insert(option)
            }
        } else {
            selection = [option]
        }
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
    }
}

/// Pure token normalization & deduplication helpers for `FMTokenField` (unit-tested).
public enum FMTokenMath {
    public static func appendToken(_ raw: String, to existing: [String]) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return existing }
        let exists = existing.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        return exists ? existing : existing + [trimmed]
    }
}

/// Interactive capsule tag/token input field (matching Mail / Finder tag editors).
public struct FMTokenField: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.isEnabled) private var isEnabled

    @Binding private var tokens: [String]
    private let placeholder: String

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    public init(_ placeholder: String = "输入标签后按回车...", tokens: Binding<[String]>) {
        self.placeholder = placeholder
        self._tokens = tokens
    }

    public var body: some View {
        let radius = FMCornerRadius.control * density.cornerScale
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let accent = FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)

        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tokens, id: \.self) { token in
                        HStack(spacing: 4) {
                            Text(token)
                                .font(.system(size: 12, weight: .medium))
                            Button {
                                tokens.removeAll { $0 == token }
                                FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .focusEffectDisabled()
                            .accessibilityLabel("Remove \(token)")
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(accent.opacity(0.16), in: Capsule(style: .continuous))
                        .foregroundStyle(accent)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                    }

                    TextField(tokens.isEmpty ? placeholder : "继续添加...", text: $draft)
                        .textFieldStyle(.plain)
                        .font(.fmBody)
                        .frame(minWidth: 110)
                        .focused($isFocused)
                        .focusEffectDisabled()
                        .onSubmit { commitDraft() }
                        .onChange(of: isFocused) { _, focused in
                            if !focused && !draft.isEmpty {
                                commitDraft()
                            }
                        }
                        .onChange(of: draft) { _, value in
                            if value.contains(",") {
                                let parts = value.split(separator: ",")
                                for part in parts {
                                    tokens = FMTokenMath.appendToken(String(part), to: tokens)
                                }
                                draft = ""
                            }
                        }
                        .onKeyPress(.delete) {
                            if draft.isEmpty && !tokens.isEmpty {
                                tokens.removeLast()
                                return .handled
                            }
                            return .ignored
                        }
                }
            }
        }
        .padding(.horizontal, FMSpacing.sm)
        .frame(minHeight: density.controlHeight)
        .background(
            isFocused ? FMColor.elevatedSurface(colorScheme) : FMColor.controlFill(colorScheme),
            in: shape
        )
        .overlay {
            shape.strokeBorder(
                isFocused ? accent.opacity(0.85) : FMColor.hairlineHighlight(colorScheme),
                lineWidth: isFocused ? 1.5 : 0.75
            )
        }
        .opacity(isEnabled ? 1.0 : 0.45)
        .fmAnimation(.micro, value: tokens)
        .fmAnimation(.micro, value: isFocused)
    }

    private func commitDraft() {
        let updated = FMTokenMath.appendToken(draft, to: tokens)
        if updated.count != tokens.count {
            tokens = updated
            FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
        }
        draft = ""
    }
}
