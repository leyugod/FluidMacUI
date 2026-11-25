import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// Pure file-type validation helper for `FMFileDropZone` (tested independently).
public enum FMFileDropValidator {
    /// Checks whether a URL's content type (resolved from file attributes or filename extension)
    /// conforms to at least one `UTType` in `allowedContentTypes`.
    public nonisolated static func matches(url: URL, allowedContentTypes: [UTType]) -> Bool {
        guard !allowedContentTypes.isEmpty else { return true }
        if allowedContentTypes.contains(.item) { return true }
        let detectedType: UTType? = {
            if let resourceType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
                return resourceType
            }
            let ext = url.pathExtension
            guard !ext.isEmpty else { return nil }
            return UTType(filenameExtension: ext)
        }()
        guard let detectedType else { return false }
        return allowedContentTypes.contains { detectedType.conforms(to: $0) }
    }
}

/// Native macOS drag-and-drop file drop zone with animated target highlight,
/// magnetic hover scale, click-to-browse `NSOpenPanel`, and dropped file chips.
public struct FMFileDropZone: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState

    @Binding private var fileURLs: [URL]
    private let title: String
    private let subtitle: String
    private let icon: String
    private let allowedContentTypes: [UTType]
    private let allowsMultiple: Bool

    @State private var isTargeted = false
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    public init(
        fileURLs: Binding<[URL]>,
        title: String = "拖放文件到此处，或点击浏览",
        subtitle: String = "支持从 Finder 直接拖入一个或多个文件",
        icon: String = "arrow.down.doc.fill",
        allowedContentTypes: [UTType] = [.item],
        allowsMultiple: Bool = true
    ) {
        self._fileURLs = fileURLs
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.allowedContentTypes = allowedContentTypes
        self.allowsMultiple = allowsMultiple
    }

    public var body: some View {
        let accent = FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
        let shape = RoundedRectangle(cornerRadius: FMCornerRadius.card, style: .continuous)

        VStack(spacing: FMSpacing.sm) {
            Button {
                openPanel()
            } label: {
                VStack(spacing: FMSpacing.xs + 2) {
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(isTargeted ? accent : .secondary)
                        .symbolEffect(.bounce, value: isTargeted)

                    Text(title)
                        .font(.fmHeadline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.fmFootnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)
                .padding(.horizontal, FMSpacing.md)
                .background(
                    isTargeted
                        ? accent.opacity(0.12)
                        : (isHovered ? FMColor.controlFill(colorScheme) : FMColor.elevatedSurface(colorScheme)),
                    in: shape
                )
                .overlay {
                    shape.strokeBorder(
                        isTargeted ? accent : FMColor.separator(colorScheme),
                        style: StrokeStyle(lineWidth: isTargeted ? 1.75 : 1.0, dash: [6, 5])
                    )
                }
                .scaleEffect(isTargeted ? 1.015 : 1.0)
                .contentShape(shape)
            }
            .buttonStyle(.plain)
            .focused($isFocused)
            .focusEffectDisabled()
            .fmFocusRing(isFocused: isFocused, cornerRadius: FMCornerRadius.card)
            .onHover { isHovered = $0 }
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }

            if !fileURLs.isEmpty {
                VStack(spacing: 4) {
                    ForEach(fileURLs, id: \.self) { url in
                        HStack(spacing: FMSpacing.xs) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(accent)
                            Text(url.lastPathComponent)
                                .font(.fmBody)
                                .lineLimit(1)
                            Spacer()
                            Button {
                                fileURLs.removeAll { $0 == url }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .focusEffectDisabled()
                            .accessibilityLabel("Remove \(url.lastPathComponent)")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(FMColor.elevatedSurface(colorScheme), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                }
            }
        }
        .fmAnimation(.micro, value: isTargeted)
        .fmAnimation(.micro, value: isHovered)
        .fmAnimation(.micro, value: fileURLs)
    }

    private func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = allowsMultiple
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = allowedContentTypes
        panel.begin { response in
            guard response == .OK else { return }
            mergeURLs(panel.urls)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var accepted = false
        let allowed = allowedContentTypes
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let resolved: URL? = {
                    if let data = item as? Data {
                        return URL(dataRepresentation: data, relativeTo: nil)
                    }
                    return item as? URL
                }()
                guard let resolved, FMFileDropValidator.matches(url: resolved, allowedContentTypes: allowed) else { return }
                Task { @MainActor in
                    mergeURLs([resolved])
                }
            }
        }
        return accepted
    }

    private func mergeURLs(_ incoming: [URL]) {
        guard !incoming.isEmpty else { return }
        if allowsMultiple {
            for url in incoming where !fileURLs.contains(url) {
                fileURLs.append(url)
            }
        } else if let first = incoming.first {
            fileURLs = [first]
        }
        FMHaptics.perform(.levelChange, enabled: theme.hapticsEnabled)
    }
}
