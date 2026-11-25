import SwiftUI
import FluidMacUI

private struct ProcessRow: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let cpu: Double
    let memoryMB: Int
    let status: String
}

struct ProductivityPage: View {
    @Environment(\.fmHUD) private var hud
    @Environment(\.colorScheme) private var colorScheme

    @Binding var isSidebarVisible: Bool
    @Binding var showInspector: Bool
    @Binding var showCommandPalette: Bool

    @State private var pathItems: [FMBreadcrumbItem] = [
        FMBreadcrumbItem(id: "root", title: "Macintosh HD", icon: "internaldrive"),
        FMBreadcrumbItem(id: "dev", title: "Projects", icon: "folder"),
        FMBreadcrumbItem(id: "lib", title: "FluidMacUI", icon: "shippingbox"),
        FMBreadcrumbItem(id: "src", title: "Sources")
    ]
    @State private var activeFilters: Set<String> = ["全部"]
    @State private var tags: [String] = ["SwiftUI", "macOS 26", "Liquid Glass"]
    @State private var selectedRowIDs: Set<UUID> = []
    @State private var droppedFiles: [URL] = []
    @State private var interactiveRating: Double = 4.5
    @State private var pickedDate = Date()
    @State private var pickedDateRange: ClosedRange<Date> = {
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
        return start...end
    }()
    @State private var pickedColor = FMColor.indigo
    @State private var showBanner = true
    @State private var showConfirmDelete = false

    // v1.0 Outline Tree State
    @State private var selectedTreeNodeID: String? = "FMCharts.swift"
    @State private var expandedTreeIDs: Set<String> = ["root", "sources", "dataDisplay", "productivity"]

    // v1.0 Code Block State
    @State private var codeLanguage: FMCodeLanguage = .swift

    @State private var processes: [ProcessRow] = [
        ProcessRow(name: "FluidRenderDaemon", category: "Graphics", cpu: 12.4, memoryMB: 428, status: "运行中"),
        ProcessRow(name: "MetalShaderCompiler", category: "Build", cpu: 28.1, memoryMB: 912, status: "活跃"),
        ProcessRow(name: "SpotlightIndexer", category: "System", cpu: 3.2, memoryMB: 184, status: "空闲"),
        ProcessRow(name: "CloudSyncAgent", category: "Network", cpu: 5.8, memoryMB: 256, status: "同步中")
    ]

    private let workspaceTree: [FMOutlineNode<String>] = [
        FMOutlineNode(
            id: "root",
            title: "FluidMacUI",
            subtitle: "v1.0.0",
            icon: "shippingbox.fill",
            iconColor: FMColor.indigo,
            children: [
                FMOutlineNode(
                    id: "sources",
                    title: "Sources",
                    icon: "folder.fill",
                    iconColor: FMColor.blue,
                    children: [
                        FMOutlineNode(
                            id: "controls",
                            title: "Controls",
                            icon: "folder.fill",
                            iconColor: FMColor.blue,
                            badge: "15",
                            children: [
                                FMOutlineNode(id: "FMDateAndColorPickers.swift", title: "FMDateAndColorPickers.swift", icon: "swift", iconColor: FMColor.orange),
                                FMOutlineNode(id: "FMComboBox.swift", title: "FMComboBox.swift", icon: "swift", iconColor: FMColor.orange),
                                FMOutlineNode(id: "FMShortcutRecorder.swift", title: "FMShortcutRecorder.swift", icon: "swift", iconColor: FMColor.orange)
                            ]
                        ),
                        FMOutlineNode(
                            id: "dataDisplay",
                            title: "DataDisplay",
                            icon: "folder.fill",
                            iconColor: FMColor.blue,
                            badge: "7",
                            children: [
                                FMOutlineNode(id: "FMCharts.swift", title: "FMCharts.swift", subtitle: "FMGauge & FMSparkline", icon: "swift", iconColor: FMColor.orange),
                                FMOutlineNode(id: "FMStepsIndicator.swift", title: "FMStepsIndicator.swift", icon: "swift", iconColor: FMColor.orange),
                                FMOutlineNode(id: "FMSpinner.swift", title: "FMSpinner.swift", icon: "swift", iconColor: FMColor.orange)
                            ]
                        ),
                        FMOutlineNode(
                            id: "productivity",
                            title: "Productivity",
                            icon: "folder.fill",
                            iconColor: FMColor.blue,
                            badge: "8",
                            children: [
                                FMOutlineNode(id: "FMOutlineTree.swift", title: "FMOutlineTree.swift", icon: "swift", iconColor: FMColor.orange),
                                FMOutlineNode(id: "FMCodeBlock.swift", title: "FMCodeBlock.swift", icon: "swift", iconColor: FMColor.orange)
                            ]
                        )
                    ]
                ),
                FMOutlineNode(
                    id: "Package.swift",
                    title: "Package.swift",
                    subtitle: "swift-tools-version: 6.2",
                    icon: "doc.text.fill",
                    iconColor: FMColor.teal
                )
            ]
        )
    ]

    private var sampleCodeTitle: String {
        switch codeLanguage {
        case .swift: "TelemetryCard.swift"
        case .json: "theme-preset.json"
        case .shell: "verify-release.sh"
        case .plain: "release-notes.txt"
        }
    }

    private var sampleCodeSnippet: String {
        switch codeLanguage {
        case .swift:
            """
            import SwiftUI
            import FluidMacUI

            @MainActor
            struct TelemetryCard: View {
                @State private var cpuLoad: Double = 64.0 // Live utilization

                var body: some View {
                    FMGlassCard(surface: .glass(.regular)) {
                        HStack(spacing: FMSpacing.md) {
                            FMGauge(value: cpuLoad, in: 0...100, label: "CPU", style: .arc)
                            FMSparkline(values: [24, 38, 52, 47, 64], color: FMColor.teal)
                        }
                    }
                }
            }
            """
        case .json:
            """
            {
              "library": "FluidMacUI",
              "version": "1.0.0",
              "platform": "macOS 26.0+",
              "swift": 6.2,
              "zeroAppKitChrome": true,
              "idleWindowGPU": 0,
              "modules": ["Foundation", "Controls", "Navigation", "DataDisplay", "Productivity"]
            }
            """
        case .shell:
            """
            # Build & verify all Swift Testing suites with 0 warnings
            export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
            swift build --configuration release
            swift test --parallel # 63+ deterministic tests
            """
        case .plain:
            """
            FluidMacUI v1.0.0
            Native macOS 26 Liquid Glass & Fluid Spring Component Library
            """
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            FMNavigationStack(
                title: ShowcaseSection.productivity.title,
                headerStyle: .large
            ) {
                ShowcaseToolbarControls(
                    isSidebarVisible: $isSidebarVisible,
                    showInspector: $showInspector,
                    showCommandPalette: $showCommandPalette
                )
            } root: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        if showBanner {
                            FMInlineBanner(
                                tone: .info,
                                title: "随时按下 ⌘K 呼出 Spotlight 级命令面板",
                                message: "支持关键字模糊过滤、方向键切换与快捷键回显。",
                                actionTitle: "立即体验 ⌘K",
                                action: { showCommandPalette = true },
                                onDismiss: { showBanner = false }
                            )
                        }

                        // Breadcrumb & Filter Chips
                        VStack(alignment: .leading, spacing: FMSpacing.sm) {
                            FMSectionHeader("路径面包屑与筛选胶囊")

                            FMBreadcrumbBar(items: pathItems) { clicked in
                                if let idx = pathItems.firstIndex(of: clicked) {
                                    pathItems = Array(pathItems.prefix(idx + 1))
                                }
                            }

                            FMFilterChips(
                                selection: $activeFilters,
                                options: ["全部", "Graphics", "Build", "System", "Network"],
                                allowsMultipleSelection: true,
                                title: { $0 }
                            )
                        }

                        // Pure-SwiftUI Date, Date Range & Color Studio Pickers
                        VStack(alignment: .leading, spacing: FMSpacing.md) {
                            FMSectionHeader(
                                "100% 纯 SwiftUI 日期区间与取色工作室",
                                subtitle: "零 AppKit NSDatePicker / NSColorWell 视觉割裂：支持自定义月历、区间选择、2D 色盘与彩虹色环",
                                showTopDivider: true
                            )

                            HStack(spacing: FMSpacing.md) {
                                FMDatePicker(selection: $pickedDate, displayedComponents: [.date, .hourAndMinute])
                                FMDateRangePicker(selection: $pickedDateRange)
                                Spacer()
                                FMRatingView(rating: $interactiveRating)
                            }

                            HStack(spacing: FMSpacing.md) {
                                FMColorPicker(selection: $pickedColor, supportsOpacity: true, style: .pill)
                                FMColorPicker(selection: $pickedColor, style: .orb(size: 26))
                                FMHairlineDivider(.vertical)
                                    .frame(height: 20)
                                FMColorSwatches(selection: $pickedColor)
                                Spacer()
                                Button("就地确认删除") {
                                    showConfirmDelete = true
                                }
                                .buttonStyle(.fm(.tinted, color: FMColor.red))
                                .fmConfirmPopover(
                                    isPresented: $showConfirmDelete,
                                    title: "移除所选标签？",
                                    message: "轻量级气泡确认，不打断全局窗口视线。",
                                    confirmTitle: "确认移除"
                                ) {
                                    hud.show(title: "已执行轻量确认操作", style: .warning)
                                }
                            }

                            FMTokenField("输入标签按回车生成胶囊...", tokens: $tags)
                        }

                        // v1.0 Outline Tree & Syntax-Highlighted Code Block
                        VStack(alignment: .leading, spacing: FMSpacing.md) {
                            FMSectionHeader(
                                "FMOutlineTree 层级大纲浏览器",
                                subtitle: "对标 Finder / Xcode 导航树，支持 ↑/↓/→/← 键盘展开折叠与缩进参考线",
                                showTopDivider: true
                            ) {
                                HStack(spacing: FMSpacing.xs) {
                                    if let selectedTreeNodeID {
                                        FMTag(selectedTreeNodeID, color: FMColor.indigo, style: .tinted)
                                    }
                                    Button("全部展开") {
                                        expandedTreeIDs = ["root", "sources", "controls", "dataDisplay", "productivity"]
                                    }
                                    .buttonStyle(.fmGhost)
                                }
                            }

                            FMOutlineTree(
                                roots: workspaceTree,
                                selection: $selectedTreeNodeID,
                                expandedIDs: $expandedTreeIDs
                            ) { node in
                                hud.show(icon: "doc.text", title: "已打开 \(node.title)", style: .info)
                            }
                            .frame(height: 224)
                            .padding(FMSpacing.xs)
                            .background(
                                FMColor.elevatedSurface(colorScheme),
                                in: RoundedRectangle(cornerRadius: FMCornerRadius.card, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: FMCornerRadius.card, style: .continuous)
                                    .strokeBorder(FMColor.separator(colorScheme), lineWidth: 0.75)
                                    .allowsHitTesting(false)
                            }
                        }

                        VStack(alignment: .leading, spacing: FMSpacing.sm) {
                            FMSectionHeader(
                                "FMCodeBlock 语法高亮代码块",
                                subtitle: "纯 Swift 无损分词、等宽行号、自动换行切换与一键复制反馈",
                                showTopDivider: true
                            ) {
                                FMSegmentedPicker(
                                    selection: $codeLanguage,
                                    options: [FMCodeLanguage.swift, .json, .shell]
                                ) { lang in
                                    Text(lang.displayName)
                                }
                                .frame(width: 210)
                            }

                            FMCodeBlock(
                                sampleCodeSnippet,
                                language: codeLanguage,
                                title: sampleCodeTitle,
                                showsLineNumbers: true,
                                showsCopyButton: true,
                                maxHeight: 250
                            )
                        }

                        // Data Table + Floating Selection Bar
                        VStack(alignment: .leading, spacing: FMSpacing.sm) {
                            FMSectionHeader(
                                "FMDataTable 多列排序表格",
                                subtitle: "点击列头排序；单击选择或按住 ⌘/⇧ 多选，底部将浮出批量操作玻璃胶囊",
                                showTopDivider: true
                            )

                            FMDataTable(
                                rows: processes,
                                columns: [
                                    FMTableColumn(
                                        title: "进程名称",
                                        width: .flexible(min: 180),
                                        sortBy: { $0.name.localizedCompare($1.name) }
                                    ) { row in
                                        Text(row.name).font(.fmHeadline)
                                    },
                                    FMTableColumn(
                                        title: "分类",
                                        width: .fixed(110),
                                        sortBy: { $0.category.localizedCompare($1.category) }
                                    ) { row in
                                        FMTag(row.category, color: FMColor.blue, style: .tinted)
                                    },
                                    FMTableColumn(
                                        title: "CPU",
                                        width: .fixed(88),
                                        alignment: .trailing,
                                        sortBy: { $0.cpu < $1.cpu ? .orderedAscending : ($0.cpu > $1.cpu ? .orderedDescending : .orderedSame) }
                                    ) { row in
                                        Text(String(format: "%.1f%%", row.cpu))
                                            .font(.fmNumeric(size: 13))
                                    },
                                    FMTableColumn(
                                        title: "内存",
                                        width: .fixed(96),
                                        alignment: .trailing,
                                        sortBy: { $0.memoryMB < $1.memoryMB ? .orderedAscending : ($0.memoryMB > $1.memoryMB ? .orderedDescending : .orderedSame) }
                                    ) { row in
                                        Text("\(row.memoryMB) MB")
                                            .font(.fmNumeric(size: 13))
                                            .foregroundStyle(.secondary)
                                    },
                                    FMTableColumn(title: "状态", width: .fixed(90), alignment: .trailing) { row in
                                        FMBadge(row.status, color: FMColor.green, style: .tinted, showsDot: true)
                                    }
                                ],
                                selection: $selectedRowIDs
                            )
                        }

                        // Native Drag & Drop File Drop Zone
                        VStack(alignment: .leading, spacing: FMSpacing.sm) {
                            FMSectionHeader("FMFileDropZone 桌面文件拖放区", showTopDivider: true)
                            FMFileDropZone(fileURLs: $droppedFiles)
                        }
                    }
                    .padding(.horizontal, 34)
                    .padding(.top, 10)
                    .padding(.bottom, 84)
                }
            }

            FMSelectionActionBar(selectedCount: selectedRowIDs.count, unitLabel: "个进程") {
                selectedRowIDs.removeAll()
            } actions: {
                Button("导出快照") {
                    hud.show(title: "已导出 \(selectedRowIDs.count) 项进程快照", style: .success)
                }
                .buttonStyle(.fm(.tinted, isCapsule: true))

                Button("终止") {
                    processes.removeAll { selectedRowIDs.contains($0.id) }
                    selectedRowIDs.removeAll()
                    hud.show(title: "已终止选中进程", style: .warning)
                }
                .buttonStyle(.fm(.destructive, isCapsule: true))
            }
            .padding(.bottom, 20)
        }
    }
}
