import SwiftUI
import FluidMacUI

enum ShowcaseSection: String, CaseIterable, Hashable {
    case appStoreDemo
    case foundation
    case controls
    case containersNav
    case feedbackData
    case productivity

    var title: String {
        switch self {
        case .appStoreDemo: "原生标杆示例"
        case .foundation: "基础与材质"
        case .controls: "交互控件"
        case .containersNav: "容器与导航"
        case .feedbackData: "反馈与数据"
        case .productivity: "生产力套件"
        }
    }

    var subtitle: String {
        switch self {
        case .appStoreDemo: "1:1 对齐 macOS 原生 App Store 布局与排版范式"
        case .foundation: "Liquid Glass、同心圆角、四级弹簧与语义色板"
        case .controls: "弹性按钮、单选、搜索下拉、数值/OTP、快捷键录制与加载器"
        case .containersNav: "InsetGroup、可调分栏、页码引导、悬浮胶囊栏与视差路由"
        case .feedbackData: "灵动岛 HUD、仪表盘、趋势火花线、多步向导与骨架屏"
        case .productivity: "⌘K 命令面板、大纲树、代码块、纯 SwiftUI 日期/取色与表格"
        }
    }
}

@main
struct FluidMacShowcaseApp: App {
    @State private var menuTurbo = true
    @State private var menuBrightness = 0.72

    var body: some Scene {
        WindowGroup("FluidMacUI Showcase") {
            ShowcaseRootView()
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 800)

        MenuBarExtra("FluidMacUI", systemImage: "sparkles") {
            FMMenuBarPanel(
                title: "FluidMacUI 控制中心",
                subtitle: "v\(FluidMacUI.version) · 紧凑流体模式",
                icon: "sparkles",
                iconColor: FMColor.indigo
            ) {
                FMInsetGroup {
                    FMRow(icon: "bolt.fill", iconColor: FMColor.orange, title: "实时物理引擎") {
                        Toggle("", isOn: $menuTurbo)
                            .toggleStyle(.fmSwitch)
                    }
                    FMRow(icon: "sun.max.fill", iconColor: FMColor.yellow, title: "玻璃通透度", showDivider: false) {
                        FMSlider(value: $menuBrightness, style: .controlCenterCapsule)
                            .frame(width: 120)
                    }
                }
            }
            .padding(8)
        }
        .menuBarExtraStyle(.window)
    }
}

struct ShowcaseRootView: View {
    @State private var selectedSection: ShowcaseSection = .appStoreDemo
    @State private var sidebarSearch = ""
    @State private var isSidebarVisible = true
    @State private var showInspector = false
    @State private var showCommandPalette = false
    @State private var theme = FMTheme.default
    @State private var density: FMDensity = .regular
    @State private var backdrop: FMWindowBackdrop = .nativeCanvas
    @State private var sidebarIconStyle: FMSidebarIconStyle = .symbol

    private var filteredSections: [FMSidebarSection<ShowcaseSection>] {
        let allItems: [FMSidebarItem<ShowcaseSection>] = [
            FMSidebarItem(id: .appStoreDemo, title: "Discover", icon: "star", iconColor: FMColor.blue),
            FMSidebarItem(id: .foundation, title: "Foundation", icon: "paintbrush", iconColor: FMColor.blue),
            FMSidebarItem(id: .controls, title: "Controls", icon: "slider.horizontal.3", iconColor: FMColor.blue, badge: "17"),
            FMSidebarItem(id: .containersNav, title: "Navigation", icon: "rectangle.3.group", iconColor: FMColor.blue),
            FMSidebarItem(id: .feedbackData, title: "Feedback & Data", icon: "chart.xyaxis.line", iconColor: FMColor.blue),
            FMSidebarItem(id: .productivity, title: "Productivity", icon: "tablecells", iconColor: FMColor.blue, badge: "12")
        ]

        let trimmed = sidebarSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let items = trimmed.isEmpty
            ? allItems
            : allItems.filter { $0.title.lowercased().contains(trimmed) }

        return [FMSidebarSection(id: "main", items: items)]
    }

    private var commands: [FMCommandItem] {
        [
            FMCommandItem(title: "前往：原生 App Store 样板页", icon: "star", group: "导航", shortcut: ["⌘", "1"]) {
                selectedSection = .appStoreDemo
            },
            FMCommandItem(title: "前往：基础与材质", icon: "paintbrush", group: "导航", shortcut: ["⌘", "2"]) {
                selectedSection = .foundation
            },
            FMCommandItem(title: "前往：交互控件套件", icon: "slider.horizontal.3", group: "导航", shortcut: ["⌘", "3"]) {
                selectedSection = .controls
            },
            FMCommandItem(title: "前往：容器与导航", icon: "rectangle.3.group", group: "导航", shortcut: ["⌘", "4"]) {
                selectedSection = .containersNav
            },
            FMCommandItem(title: "前往：反馈与数据可视化", icon: "chart.xyaxis.line", group: "导航", shortcut: ["⌘", "5"]) {
                selectedSection = .feedbackData
            },
            FMCommandItem(title: "前往：桌面生产力套件", icon: "tablecells", group: "导航", shortcut: ["⌘", "6"]) {
                selectedSection = .productivity
            },
            FMCommandItem(title: "切换右侧调参检查器", icon: "sidebar.right", group: "视图", shortcut: ["⌘", "I"]) {
                showInspector.toggle()
            },
            FMCommandItem(title: "切换左侧导航栏", icon: "sidebar.left", group: "视图", shortcut: ["⌥", "⌘", "S"]) {
                isSidebarVisible.toggle()
            },
            FMCommandItem(title: "切换材质引擎（Liquid Glass / 磨砂）", icon: "sparkles", group: "外观") {
                theme.surfaceStyle = theme.surfaceStyle == .liquidGlass ? .frosted : .liquidGlass
            }
        ]
    }

    var body: some View {
        FMWindowContainer(backdrop: backdrop) {
            FMSidebarSplitView(
                selection: $selectedSection,
                isSidebarVisible: $isSidebarVisible,
                searchText: $sidebarSearch,
                searchPlaceholder: "Search",
                iconStyle: sidebarIconStyle,
                sidebarWidth: 224,
                sections: filteredSections
            ) {
                FMSidebarAccountFooter(
                    name: "FluidMac Studio",
                    subtitle: "v\(FluidMacUI.version) · macOS 26 Native",
                    initials: "FM"
                ) {
                    showInspector.toggle()
                }
            } detail: {
                FMInspectorSplitView(isPresented: $showInspector, defaultWidth: 276) {
                    VStack(spacing: 0) {
                        detailPage
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        showcaseStatusBar
                    }
                } inspector: {
                    LabInspectorPanel(
                        theme: $theme,
                        density: $density,
                        backdrop: $backdrop,
                        sidebarIconStyle: $sidebarIconStyle
                    )
                }
            }
            .fmCommandPalette(isPresented: $showCommandPalette, commands: commands)
        }
        .background {
            Group {
                Button("") { showCommandPalette.toggle() }
                    .keyboardShortcut("k", modifiers: .command)
                Button("") { isSidebarVisible.toggle() }
                    .keyboardShortcut("s", modifiers: [.option, .command])
                Button("") { showInspector.toggle() }
                    .keyboardShortcut("i", modifiers: .command)
            }
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
        .fmTheme(theme)
        .fmDensity(density)
    }

    private var showcaseStatusBar: some View {
        FMStatusBar {
            FMStatusBarItem(
                icon: "square.stack.3d.up.fill",
                text: selectedSection.title
            )
            FMStatusBarDivider()
            FMStatusBarItem(
                icon: "sparkles",
                text: theme.surfaceStyle == .liquidGlass ? "Liquid Glass" : "Frosted",
                accessibilityLabel: "Toggle surface style"
            ) {
                theme.surfaceStyle = theme.surfaceStyle == .liquidGlass ? .frosted : .liquidGlass
            }
            FMStatusBarDivider()
            FMStatusBarItem(
                text: "v\(FluidMacUI.version) · 58 Components"
            )
        } center: {
            FMStatusBarItem(
                icon: "command",
                text: "⌘K Command Palette",
                accessibilityLabel: "Open Command Palette"
            ) {
                showCommandPalette = true
            }
        } trailing: {
            FMStatusBarItem(
                icon: "sidebar.right",
                text: showInspector ? "Inspector On" : "Inspector",
                accessibilityLabel: "Toggle Appearance Inspector"
            ) {
                showInspector.toggle()
            }
            FMStatusBarDivider()
            FMStatusBarItem(
                text: "Swift 6.2 · Ready",
                statusColor: FMColor.green
            )
        }
    }

    @ViewBuilder
    private var detailPage: some View {
        switch selectedSection {
        case .appStoreDemo:
            AppStoreDemoPage(
                isSidebarVisible: $isSidebarVisible,
                showInspector: $showInspector,
                showCommandPalette: $showCommandPalette
            )
        case .foundation:
            FoundationPage(
                isSidebarVisible: $isSidebarVisible,
                showInspector: $showInspector,
                showCommandPalette: $showCommandPalette
            )
        case .controls:
            ControlsPage(
                isSidebarVisible: $isSidebarVisible,
                showInspector: $showInspector,
                showCommandPalette: $showCommandPalette
            )
        case .containersNav:
            ContainersAndNavPage(
                isSidebarVisible: $isSidebarVisible,
                showInspector: $showInspector,
                showCommandPalette: $showCommandPalette
            )
        case .feedbackData:
            FeedbackAndDataPage(
                isSidebarVisible: $isSidebarVisible,
                showInspector: $showInspector,
                showCommandPalette: $showCommandPalette
            )
        case .productivity:
            ProductivityPage(
                isSidebarVisible: $isSidebarVisible,
                showInspector: $showInspector,
                showCommandPalette: $showCommandPalette
            )
        }
    }
}

struct LabInspectorPanel: View {
    @Binding var theme: FMTheme
    @Binding var density: FMDensity
    @Binding var backdrop: FMWindowBackdrop
    @Binding var sidebarIconStyle: FMSidebarIconStyle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FMSpacing.md) {
                HStack {
                    Text("外观检查器")
                        .font(.fmHeadline)
                    Spacer()
                    FMBadge("Live", color: FMColor.green, style: .tinted, showsDot: true)
                }

                FMHairlineDivider()

                VStack(alignment: .leading, spacing: FMSpacing.xs) {
                    Text("主题强调色")
                        .font(.fmCaption)
                        .foregroundStyle(.secondary)
                    FMColorSwatches(selection: $theme.accentColor, size: 22)
                }

                VStack(alignment: .leading, spacing: FMSpacing.xs) {
                    Text("侧边栏图标样式")
                        .font(.fmCaption)
                        .foregroundStyle(.secondary)
                    FMSegmentedPicker(selection: $sidebarIconStyle, options: [.symbol, .badge]) { style in
                        Text(style == .symbol ? "原生符号" : "彩色底座")
                    }
                }

                VStack(alignment: .leading, spacing: FMSpacing.xs) {
                    Text("玻璃材质引擎")
                        .font(.fmCaption)
                        .foregroundStyle(.secondary)
                    FMSegmentedPicker(selection: $theme.surfaceStyle, options: FMSurfaceStyle.allCases) { style in
                        Text(style.displayName)
                    }
                }

                VStack(alignment: .leading, spacing: FMSpacing.xs) {
                    Text("界面密度")
                        .font(.fmCaption)
                        .foregroundStyle(.secondary)
                    FMSegmentedPicker(selection: $density, options: FMDensity.allCases) { d in
                        Text(d.displayName)
                    }
                }

                VStack(alignment: .leading, spacing: FMSpacing.xs) {
                    Text("画布背景")
                        .font(.fmCaption)
                        .foregroundStyle(.secondary)
                    FMSegmentedPicker(
                        selection: $backdrop,
                        options: [.nativeCanvas, .ambientMesh, .grouped]
                    ) { mode in
                        switch mode {
                        case .nativeCanvas: Text("原生纯净")
                        case .ambientMesh: Text("弥散光斑")
                        case .grouped: Text("分组底色")
                        case .clear: Text("透明")
                        }
                    }
                }

                VStack(alignment: .leading, spacing: FMSpacing.xs) {
                    HStack {
                        Text("弹簧倍速")
                            .font(.fmCaption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.1fx", theme.animationSpeed))
                            .font(.fmNumeric(size: 12))
                    }
                    FMSlider(value: $theme.animationSpeed, in: 0.2...1.5, step: 0.1, style: .controlCenterCapsule)
                }

                FMHairlineDivider()

                HStack {
                    Text("触控板震动反馈")
                        .font(.fmSubheadline)
                    Spacer()
                    Toggle("", isOn: $theme.hapticsEnabled)
                        .toggleStyle(.fmSwitch)
                }
            }
            .padding(.horizontal, FMSpacing.md)
            .padding(.top, 14)
            .padding(.bottom, FMSpacing.lg)
        }
        .fmDensity(.compact)
    }
}

struct ShowcaseToolbarControls: View {
    @Binding var isSidebarVisible: Bool
    @Binding var showInspector: Bool
    @Binding var showCommandPalette: Bool

    var body: some View {
        FMToolbarGroup {
            FMToolbarButton(icon: "magnifyingglass") {
                showCommandPalette = true
            }
            .fmTooltip("命令面板", shortcut: ["⌘", "K"], edge: .bottom)

            FMToolbarButton(icon: "sidebar.right", isActive: showInspector) {
                showInspector.toggle()
            }
            .fmTooltip("打开/关闭检查器", shortcut: ["⌘", "I"], edge: .bottom)
        }
    }
}
