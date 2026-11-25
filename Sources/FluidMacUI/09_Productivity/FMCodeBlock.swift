import SwiftUI
import AppKit

// MARK: - Language & Tokenizer Models

/// Supported lightweight syntax highlighting languages for `FMCodeBlock`.
public enum FMCodeLanguage: String, Sendable, Hashable, CaseIterable {
    case plain
    case swift
    case json
    case shell

    /// Human-readable display label shown in the header bar.
    public var displayName: String {
        switch self {
        case .plain: "Plain Text"
        case .swift: "Swift"
        case .json: "JSON"
        case .shell: "Shell"
        }
    }
}

/// Semantic syntax token classification emitted by `FMCodeTokenizer`.
public enum FMCodeTokenKind: Sendable, Hashable {
    case plain
    case keyword
    case string
    case number
    case comment
    case property
}

/// Single contiguous lexical token produced by `FMCodeTokenizer`.
public struct FMCodeToken: Sendable, Hashable {
    public let text: String
    public let kind: FMCodeTokenKind

    public init(text: String, kind: FMCodeTokenKind) {
        self.text = text
        self.kind = kind
    }
}

/// Pure-Swift, single-pass line splitter and lightweight syntax tokenizer for `FMCodeBlock`.
public enum FMCodeTokenizer {
    private static let swiftKeywords: Set<String> = [
        "import", "struct", "class", "enum", "actor", "protocol", "extension",
        "func", "init", "deinit", "var", "let", "public", "private", "fileprivate",
        "internal", "open", "static", "final", "override", "mutating", "nonmutating",
        "nonisolated", "isolated", "async", "await", "throws", "rethrows", "try",
        "catch", "throw", "return", "if", "else", "guard", "switch", "case",
        "default", "for", "in", "while", "repeat", "break", "continue", "where",
        "as", "is", "self", "Self", "super", "true", "false", "nil", "some",
        "any", "typealias", "associatedtype", "inout", "defer", "do", "weak",
        "unowned", "Sendable", "MainActor"
    ]

    private static let jsonKeywords: Set<String> = [
        "true", "false", "null"
    ]

    private static let shellKeywords: Set<String> = [
        "if", "then", "else", "elif", "fi", "for", "do", "done", "while",
        "case", "esac", "in", "function", "export", "local", "return", "exit",
        "echo", "cd", "ls", "mkdir", "rm", "cp", "mv", "cat", "grep", "find",
        "git", "swift", "xcodebuild", "curl", "sudo", "set", "true", "false"
    ]

    /// Splits `code` into logical lines while normalizing `\r\n` and `\r` line endings.
    ///
    /// Returns `[]` for an empty string and preserves empty lines inside multi-line input.
    public static func splitLines(_ code: String) -> [String] {
        guard !code.isEmpty else { return [] }
        let normalized = code
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    /// Computes the minimum digit width needed to right-align line numbers without jitter.
    public static func lineNumberColumnWidth(lineCount: Int) -> Int {
        max(2, String(max(1, lineCount)).count)
    }

    /// Tokenizes a single source line into lossless contiguous `FMCodeToken` spans.
    ///
    /// Concatenating `text` across the returned tokens always reproduces `line` verbatim.
    public static func tokenizeLine(_ line: String, language: FMCodeLanguage) -> [FMCodeToken] {
        guard !line.isEmpty else { return [] }
        switch language {
        case .plain:
            return [FMCodeToken(text: line, kind: .plain)]
        case .swift:
            return tokenizeSwiftLine(line)
        case .json:
            return tokenizeJSONLine(line)
        case .shell:
            return tokenizeShellLine(line)
        }
    }

    // MARK: - Language Scanners

    private static func tokenizeSwiftLine(_ line: String) -> [FMCodeToken] {
        let chars = Array(line)
        var tokens: [FMCodeToken] = []
        var plainBuffer = ""
        var i = 0

        func flushPlain() {
            if !plainBuffer.isEmpty {
                tokens.append(FMCodeToken(text: plainBuffer, kind: .plain))
                plainBuffer.removeAll(keepingCapacity: true)
            }
        }

        while i < chars.count {
            let c = chars[i]

            // Line comment //
            if c == "/", i + 1 < chars.count, chars[i + 1] == "/" {
                flushPlain()
                tokens.append(FMCodeToken(text: String(chars[i...]), kind: .comment))
                break
            }

            // Inline block comment /* ... */
            if c == "/", i + 1 < chars.count, chars[i + 1] == "*" {
                flushPlain()
                let start = i
                i += 2
                while i < chars.count {
                    if chars[i] == "*", i + 1 < chars.count, chars[i + 1] == "/" {
                        i += 2
                        break
                    }
                    i += 1
                }
                tokens.append(FMCodeToken(text: String(chars[start..<i]), kind: .comment))
                continue
            }

            // String literal "..."
            if c == "\"" {
                flushPlain()
                let end = scanQuotedString(chars, from: i, quote: "\"")
                tokens.append(FMCodeToken(text: String(chars[i..<end]), kind: .string))
                i = end
                continue
            }

            // Attribute @State, @MainActor, etc.
            if c == "@", i + 1 < chars.count, isIdentStart(chars[i + 1]) {
                flushPlain()
                let start = i
                i += 1
                while i < chars.count, isIdentContinue(chars[i]) {
                    i += 1
                }
                tokens.append(FMCodeToken(text: String(chars[start..<i]), kind: .keyword))
                continue
            }

            // Member property access .identifier
            if c == ".", i + 1 < chars.count, isIdentStart(chars[i + 1]) {
                plainBuffer.append(c)
                flushPlain()
                i += 1
                let start = i
                while i < chars.count, isIdentContinue(chars[i]) {
                    i += 1
                }
                tokens.append(FMCodeToken(text: String(chars[start..<i]), kind: .property))
                continue
            }

            // Numeric literal
            if c.isNumber, i == 0 || !isIdentContinue(chars[i - 1]) {
                flushPlain()
                let end = scanNumber(chars, from: i, allowHex: true)
                tokens.append(FMCodeToken(text: String(chars[i..<end]), kind: .number))
                i = end
                continue
            }

            // Identifier / keyword
            if isIdentStart(c) {
                let start = i
                while i < chars.count, isIdentContinue(chars[i]) {
                    i += 1
                }
                let word = String(chars[start..<i])
                if swiftKeywords.contains(word) {
                    flushPlain()
                    tokens.append(FMCodeToken(text: word, kind: .keyword))
                } else {
                    plainBuffer.append(contentsOf: word)
                }
                continue
            }

            plainBuffer.append(c)
            i += 1
        }

        flushPlain()
        return tokens
    }

    private static func tokenizeJSONLine(_ line: String) -> [FMCodeToken] {
        let chars = Array(line)
        var tokens: [FMCodeToken] = []
        var plainBuffer = ""
        var i = 0

        func flushPlain() {
            if !plainBuffer.isEmpty {
                tokens.append(FMCodeToken(text: plainBuffer, kind: .plain))
                plainBuffer.removeAll(keepingCapacity: true)
            }
        }

        while i < chars.count {
            let c = chars[i]

            if c == "\"" {
                flushPlain()
                let end = scanQuotedString(chars, from: i, quote: "\"")
                var lookahead = end
                while lookahead < chars.count, chars[lookahead].isWhitespace {
                    lookahead += 1
                }
                let isKey = lookahead < chars.count && chars[lookahead] == ":"
                tokens.append(
                    FMCodeToken(
                        text: String(chars[i..<end]),
                        kind: isKey ? .property : .string
                    )
                )
                i = end
                continue
            }

            if (c.isNumber) || (c == "-" && i + 1 < chars.count && chars[i + 1].isNumber) {
                flushPlain()
                let end = scanJSONNumber(chars, from: i)
                tokens.append(FMCodeToken(text: String(chars[i..<end]), kind: .number))
                i = end
                continue
            }

            if c.isLetter {
                let start = i
                while i < chars.count, chars[i].isLetter {
                    i += 1
                }
                let word = String(chars[start..<i])
                if jsonKeywords.contains(word) {
                    flushPlain()
                    tokens.append(FMCodeToken(text: word, kind: .keyword))
                } else {
                    plainBuffer.append(contentsOf: word)
                }
                continue
            }

            plainBuffer.append(c)
            i += 1
        }

        flushPlain()
        return tokens
    }

    private static func tokenizeShellLine(_ line: String) -> [FMCodeToken] {
        let chars = Array(line)
        var tokens: [FMCodeToken] = []
        var plainBuffer = ""
        var i = 0

        func flushPlain() {
            if !plainBuffer.isEmpty {
                tokens.append(FMCodeToken(text: plainBuffer, kind: .plain))
                plainBuffer.removeAll(keepingCapacity: true)
            }
        }

        while i < chars.count {
            let c = chars[i]

            // Shell comment # at start or preceded by whitespace
            if c == "#", i == 0 || chars[i - 1].isWhitespace {
                flushPlain()
                tokens.append(FMCodeToken(text: String(chars[i...]), kind: .comment))
                break
            }

            // Double or single quoted strings
            if c == "\"" || c == "'" {
                flushPlain()
                let end = scanQuotedString(chars, from: i, quote: c)
                tokens.append(FMCodeToken(text: String(chars[i..<end]), kind: .string))
                i = end
                continue
            }

            // Environment variable $VAR or ${VAR}
            if c == "$", i + 1 < chars.count, (chars[i + 1] == "{" || isIdentStart(chars[i + 1])) {
                flushPlain()
                let start = i
                i += 1
                if chars[i] == "{" {
                    while i < chars.count, chars[i] != "}" {
                        i += 1
                    }
                    if i < chars.count { i += 1 }
                } else {
                    while i < chars.count, isIdentContinue(chars[i]) {
                        i += 1
                    }
                }
                tokens.append(FMCodeToken(text: String(chars[start..<i]), kind: .property))
                continue
            }

            // CLI flag -f or --flag preceded by whitespace
            if c == "-", (i == 0 || chars[i - 1].isWhitespace), i + 1 < chars.count,
               (chars[i + 1] == "-" || chars[i + 1].isLetter)
            {
                flushPlain()
                let start = i
                while i < chars.count, !chars[i].isWhitespace, chars[i] != "=" {
                    i += 1
                }
                tokens.append(FMCodeToken(text: String(chars[start..<i]), kind: .property))
                continue
            }

            // Standalone number
            if c.isNumber, i == 0 || chars[i - 1].isWhitespace || chars[i - 1] == "=" {
                let end = scanNumber(chars, from: i, allowHex: false)
                if end == chars.count || chars[end].isWhitespace || chars[end] == ";" || chars[end] == ")" {
                    flushPlain()
                    tokens.append(FMCodeToken(text: String(chars[i..<end]), kind: .number))
                    i = end
                    continue
                }
            }

            // Command / shell keyword
            if isIdentStart(c), i == 0 || !isIdentContinue(chars[i - 1]) {
                let start = i
                while i < chars.count, isIdentContinue(chars[i]) {
                    i += 1
                }
                let word = String(chars[start..<i])
                let boundaryBefore = start == 0 || chars[start - 1].isWhitespace || chars[start - 1] == ";" || chars[start - 1] == "|" || chars[start - 1] == "&"
                let boundaryAfter = i == chars.count || chars[i].isWhitespace || chars[i] == ";" || chars[i] == "|" || chars[i] == "&"
                if boundaryBefore && boundaryAfter && shellKeywords.contains(word) {
                    flushPlain()
                    tokens.append(FMCodeToken(text: word, kind: .keyword))
                } else {
                    plainBuffer.append(contentsOf: word)
                }
                continue
            }

            plainBuffer.append(c)
            i += 1
        }

        flushPlain()
        return tokens
    }

    // MARK: - Low-Level Character Scanners

    private static func isIdentStart(_ c: Character) -> Bool {
        c == "_" || c.isLetter
    }

    private static func isIdentContinue(_ c: Character) -> Bool {
        c == "_" || c.isLetter || c.isNumber
    }

    private static func scanQuotedString(_ chars: [Character], from start: Int, quote: Character) -> Int {
        var i = start + 1
        while i < chars.count {
            if chars[i] == "\\", quote == "\"", i + 1 < chars.count {
                i += 2
                continue
            }
            if chars[i] == quote {
                return i + 1
            }
            i += 1
        }
        return i
    }

    private static func scanNumber(_ chars: [Character], from start: Int, allowHex: Bool) -> Int {
        var i = start
        if allowHex, chars[i] == "0", i + 1 < chars.count,
           (chars[i + 1] == "x" || chars[i + 1] == "X" || chars[i + 1] == "b" || chars[i + 1] == "B")
        {
            i += 2
            while i < chars.count, chars[i].isHexDigit || chars[i] == "_" {
                i += 1
            }
            return i
        }

        while i < chars.count, chars[i].isNumber || chars[i] == "_" {
            i += 1
        }
        if i + 1 < chars.count, chars[i] == ".", chars[i + 1].isNumber {
            i += 1
            while i < chars.count, chars[i].isNumber || chars[i] == "_" {
                i += 1
            }
        }
        return i
    }

    private static func scanJSONNumber(_ chars: [Character], from start: Int) -> Int {
        var i = start
        if chars[i] == "-" { i += 1 }
        while i < chars.count, chars[i].isNumber { i += 1 }
        if i + 1 < chars.count, chars[i] == ".", chars[i + 1].isNumber {
            i += 1
            while i < chars.count, chars[i].isNumber { i += 1 }
        }
        if i < chars.count, (chars[i] == "e" || chars[i] == "E") {
            let expStart = i
            i += 1
            if i < chars.count, (chars[i] == "+" || chars[i] == "-") { i += 1 }
            let digitsStart = i
            while i < chars.count, chars[i].isNumber { i += 1 }
            if i == digitsStart { i = expStart }
        }
        return i
    }
}

// MARK: - FMCodeBlock

/// Monospaced code and log viewer featuring an optional title & language header bar,
/// tabular line numbers, one-click Copy button with animated checkmark & haptic confirmation,
/// horizontal scrolling with soft-wrap toggle, and adaptive Dark/Light pure-Swift syntax tinting.
public struct FMCodeBlock: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let code: String
    private let language: FMCodeLanguage
    private let title: String?
    private let showsLineNumbers: Bool
    private let showsCopyButton: Bool
    private let maxHeight: CGFloat?

    @State private var didCopy = false
    @State private var isWrapped = false
    @State private var isCopyHovered = false
    @State private var isWrapHovered = false
    @State private var copyResetTask: Task<Void, Never>?

    @FocusState private var focusedControl: HeaderControl?

    private enum HeaderControl: Hashable {
        case wrap
        case copy
    }

    public init(
        _ code: String,
        language: FMCodeLanguage = .plain,
        title: String? = nil,
        showsLineNumbers: Bool = true,
        showsCopyButton: Bool = true,
        maxHeight: CGFloat? = 320
    ) {
        self.code = code
        self.language = language
        self.title = title
        self.showsLineNumbers = showsLineNumbers
        self.showsCopyButton = showsCopyButton
        self.maxHeight = maxHeight
    }

    private var lines: [String] {
        FMCodeTokenizer.splitLines(code)
    }

    private var showsHeader: Bool {
        (title != nil && !(title ?? "").isEmpty) || language != .plain || showsCopyButton
    }

    private var isHighContrast: Bool {
        contrast == .increased || reduceTransparency
    }

    private var cornerRadius: CGFloat {
        FMCornerRadius.card * density.cornerScale
    }

    private var surfaceBackground: Color {
        if reduceTransparency {
            return FMColor.elevatedOpaqueSurface(colorScheme)
        }
        return colorScheme == .dark
            ? Color(red: 0.092, green: 0.095, blue: 0.106)
            : Color(red: 0.968, green: 0.971, blue: 0.980)
    }

    private var headerBackground: Color {
        if reduceTransparency {
            return colorScheme == .dark
                ? Color(red: 0.125, green: 0.128, blue: 0.140)
                : Color(red: 0.935, green: 0.940, blue: 0.952)
        }
        return colorScheme == .dark
            ? Color.white.opacity(0.038)
            : Color.black.opacity(0.032)
    }

    public var body: some View {
        let codeLines = lines
        let digitWidth = FMCodeTokenizer.lineNumberColumnWidth(lineCount: codeLines.count)
        let gutterWidth = CGFloat(digitWidth) * 8.2 + 8

        VStack(alignment: .leading, spacing: 0) {
            if showsHeader {
                headerBar
                FMHairlineDivider()
            }

            codeViewport(lines: codeLines, gutterWidth: gutterWidth)
        }
        .background(surfaceBackground)
        .fmClipCorner(FMCornerRadius.card)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    FMColor.separator(colorScheme, highContrast: isHighContrast),
                    lineWidth: isHighContrast ? 1.0 : 0.5
                )
                .allowsHitTesting(false)
        }
        .onDisappear {
            copyResetTask?.cancel()
            copyResetTask = nil
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(containerAccessibilityLabel(lineCount: codeLines.count))
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: FMSpacing.xs) {
            if language != .plain || title == nil {
                Text(language.displayName)
                    .font(.fmCaption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background {
                        Capsule(style: .continuous)
                            .fill(FMColor.controlFill(colorScheme))
                    }
            }

            if let title, !title.isEmpty {
                Text(title)
                    .font(.fmSubheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: FMSpacing.sm)

            Button {
                withAnimation(
                    FMSpring.animation(.micro, reduceMotion: reduceMotion, speed: theme.animationSpeed)
                ) {
                    isWrapped.toggle()
                }
                FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
            } label: {
                Image(systemName: isWrapped ? "text.justify.left" : "arrow.right.to.line.compact")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(
                        isWrapped
                            ? FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
                            : .secondary
                    )
                    .frame(width: 26, height: 24)
                    .background {
                        Capsule(style: .continuous)
                            .fill(isWrapHovered ? FMColor.controlHoverFill(colorScheme) : .clear)
                    }
            }
            .buttonStyle(.plain)
            .focusable()
            .focused($focusedControl, equals: .wrap)
            .focusEffectDisabled()
            .fmFocusRing(isFocused: focusedControl == .wrap, isCapsule: true)
            .onHover { isWrapHovered = $0 }
            .help(isWrapped ? "Disable soft wrap" : "Enable soft wrap")
            .accessibilityLabel("Line wrapping")
            .accessibilityValue(isWrapped ? "On" : "Off")

            if showsCopyButton {
                Button(action: copyToPasteboard) {
                    HStack(spacing: 4) {
                        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .semibold))
                            .contentTransition(.symbolEffect(.replace))

                        Text(didCopy ? "Copied" : "Copy")
                            .font(.fmCaption)
                    }
                    .foregroundStyle(
                        didCopy
                            ? FMColor.adaptiveAccent(FMColor.green, activeState: activeState, scheme: colorScheme)
                            : .primary
                    )
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background {
                        Capsule(style: .continuous)
                            .fill(
                                didCopy
                                    ? FMColor.green.opacity(colorScheme == .dark ? 0.22 : 0.14)
                                    : (isCopyHovered
                                        ? FMColor.controlHoverFill(colorScheme)
                                        : FMColor.controlFill(colorScheme))
                            )
                    }
                }
                .buttonStyle(.plain)
                .focusable()
                .focused($focusedControl, equals: .copy)
                .focusEffectDisabled()
                .fmFocusRing(isFocused: focusedControl == .copy, isCapsule: true)
                .onHover { isCopyHovered = $0 }
                .fmAnimation(.micro, value: didCopy)
                .accessibilityLabel(didCopy ? "Code copied" : "Copy code")
            }
        }
        .padding(.horizontal, density.horizontalPadding * 0.8)
        .padding(.vertical, density == .compact ? 6 : 8)
        .background(headerBackground)
    }

    // MARK: - Code Viewport

    @ViewBuilder
    private func codeViewport(lines: [String], gutterWidth: CGFloat) -> some View {
        let content = codeContent(lines: lines, gutterWidth: gutterWidth)
            .padding(.horizontal, density.horizontalPadding * 0.8)
            .padding(.vertical, density.verticalPadding * 0.85)

        if let maxHeight {
            ScrollView(.vertical, showsIndicators: true) {
                horizontalWrapper(content)
            }
            .frame(maxHeight: maxHeight)
        } else {
            horizontalWrapper(content)
        }
    }

    @ViewBuilder
    private func horizontalWrapper<Content: View>(_ content: Content) -> some View {
        if isWrapped {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView(.horizontal, showsIndicators: true) {
                content
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func codeContent(lines: [String], gutterWidth: CGFloat) -> some View {
        if lines.isEmpty {
            Text(" ")
                .font(.fmMono)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            LazyVStack(alignment: .leading, spacing: density == .compact ? 1.5 : 2.5) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .top, spacing: FMSpacing.sm) {
                        if showsLineNumbers {
                            Text("\(index + 1)")
                                .font(.system(size: 11.5, weight: .regular, design: .monospaced).monospacedDigit())
                                .foregroundStyle(.secondary.opacity(colorScheme == .dark ? 0.55 : 0.65))
                                .frame(width: gutterWidth, alignment: .trailing)
                                .accessibilityHidden(true)
                        }

                        Text(attributedLine(line))
                            .font(.fmMono)
                            .fixedSize(horizontal: !isWrapped, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    // MARK: - Syntax Styling & Clipboard

    private func attributedLine(_ line: String) -> AttributedString {
        guard !line.isEmpty else {
            return AttributedString(" ")
        }

        let tokens = FMCodeTokenizer.tokenizeLine(line, language: language)
        var result = AttributedString()
        for token in tokens {
            var segment = AttributedString(token.text)
            segment.foregroundColor = color(for: token.kind)
            result.append(segment)
        }
        return result
    }

    private func color(for kind: FMCodeTokenKind) -> Color {
        if colorScheme == .dark {
            switch kind {
            case .plain: Color(white: 0.92)
            case .keyword: Color(red: 0.99, green: 0.42, blue: 0.64)
            case .string: Color(red: 0.99, green: 0.48, blue: 0.40)
            case .number: Color(red: 0.84, green: 0.77, blue: 0.42)
            case .comment: Color(red: 0.52, green: 0.58, blue: 0.64)
            case .property: Color(red: 0.42, green: 0.76, blue: 0.68)
            }
        } else {
            switch kind {
            case .plain: Color(white: 0.12)
            case .keyword: Color(red: 0.67, green: 0.11, blue: 0.48)
            case .string: Color(red: 0.76, green: 0.10, blue: 0.09)
            case .number: Color(red: 0.11, green: 0.04, blue: 0.78)
            case .comment: Color(red: 0.36, green: 0.42, blue: 0.48)
            case .property: Color(red: 0.18, green: 0.46, blue: 0.50)
            }
        }
    }

    private func copyToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(code, forType: .string)

        FMHaptics.perform(.generic, enabled: theme.hapticsEnabled)

        withAnimation(
            FMSpring.animation(.micro, reduceMotion: reduceMotion, speed: theme.animationSpeed)
        ) {
            didCopy = true
        }

        copyResetTask?.cancel()
        copyResetTask = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            withAnimation(
                FMSpring.animation(.micro, reduceMotion: reduceMotion, speed: theme.animationSpeed)
            ) {
                didCopy = false
            }
        }
    }

    private func containerAccessibilityLabel(lineCount: Int) -> String {
        let lineWord = lineCount == 1 ? "line" : "lines"
        if let title, !title.isEmpty {
            return "\(title), \(language.displayName) code block, \(lineCount) \(lineWord)"
        }
        return "\(language.displayName) code block, \(lineCount) \(lineWord)"
    }
}
