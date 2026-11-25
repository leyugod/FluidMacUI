import SwiftUI
import FluidMacUI

struct FeedbackAndDataPage: View {
    @Environment(\.fmHUD) private var hud

    @Binding var isSidebarVisible: Bool
    @Binding var showInspector: Bool
    @Binding var showCommandPalette: Bool

    @State private var showBottomSheet = false
    @State private var showAlert = false
    @State private var showActionPopover = false
    @State private var progressValue = 0.68
    @State private var isSkeletonLoading = false

    // v1.0 Batch C Telemetry & Steps State
    @State private var cpuLoad: Double = 64
    @State private var memoryRatio: Double = 0.72
    @State private var diskRatio: Double = 0.74
    @State private var latencySamples: [Double] = [18, 24, 21, 32, 28, 45, 39, 31, 26, 35, 29, 22]
    @State private var currentWizardStep = 1
    @State private var wizardErrorSteps: Set<Int> = []
    @State private var wizardAxis: Axis = .horizontal

    private let wizardSteps: [FMStepItem] = [
        FMStepItem(id: "config", title: "环境配置", subtitle: "Swift 6.2 & SDK"),
        FMStepItem(id: "build", title: "编译构建", subtitle: "0 警告 / 0 错误"),
        FMStepItem(id: "verify", title: "自动测试", subtitle: "Swift Testing 套件"),
        FMStepItem(id: "ship", title: "发布 v1.0", subtitle: "签发最终制品", icon: "paperplane.fill")
    ]

    var body: some View {
        FMNavigationStack(
            title: ShowcaseSection.feedbackData.title,
            subtitle: ShowcaseSection.feedbackData.subtitle,
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
                    // Dynamic HUD
                    VStack(alignment: .leading, spacing: FMSpacing.sm) {
                        FMSectionHeader("FMDynamicHUD 窗口级灵动岛胶囊", subtitle: "按 ⌘N 新开第二个窗口后分别点击，可验证各窗口 HUD 与 Sheet 100% 独立不串台")

                        HStack(spacing: FMSpacing.sm) {
                            Button("成功胶囊") {
                                hud.show(
                                    icon: "sparkles",
                                    title: "已释放 2.4 GB 可用内存",
                                    subtitle: "后台守护引擎运行正常",
                                    style: .success
                                )
                            }
                            .buttonStyle(.fm(.tinted, isCapsule: true, color: FMColor.green))

                            Button("加载 → 成功变形") {
                                let id = hud.show(title: "正在深度扫描派生缓存...", style: .loading)
                                Task {
                                    try? await Task.sleep(for: .seconds(1.6))
                                    hud.update(
                                        id: id,
                                        title: "扫描完成 · 发现 8.6 GB 可清理",
                                        style: .success,
                                        action: FMHUDAction("查看") {
                                            showBottomSheet = true
                                        }
                                    )
                                }
                            }
                            .buttonStyle(.fm(.primary, isCapsule: true))

                            Button("警告胶囊") {
                                hud.show(title: "磁盘剩余空间不足 15%", style: .warning)
                            }
                            .buttonStyle(.fm(.tinted, isCapsule: true, color: FMColor.orange))
                        }
                    }

                    // v1.0 Telemetry Gauges & Interactive Sparkline
                    VStack(alignment: .leading, spacing: FMSpacing.md) {
                        FMSectionHeader(
                            "FMGauge & FMSparkline · 纯 SwiftUI 遥测仪表与火花线",
                            subtitle: "240° 速度弧、360° 环形与线性容量条；鼠标悬停火花线可实时微调读数",
                            showTopDivider: true
                        ) {
                            Button("随机采样刷新") {
                                cpuLoad = Double(Int.random(in: 18...94))
                                memoryRatio = Double.random(in: 0.32...0.92)
                                diskRatio = Double.random(in: 0.45...0.88)
                                latencySamples = (0..<12).map { _ in Double(Int.random(in: 12...68)) }
                            }
                            .buttonStyle(.fm(.tinted, isCapsule: true))
                        }

                        HStack(alignment: .center, spacing: FMSpacing.lg) {
                            FMGauge(
                                value: cpuLoad,
                                in: 0...100,
                                label: "CPU",
                                valueText: "\(Int(cpuLoad))%",
                                style: .arc,
                                size: 92,
                                gradient: [FMColor.green, FMColor.orange, FMColor.red]
                            )

                            FMGauge(
                                value: memoryRatio,
                                in: 0...1,
                                label: "Memory",
                                style: .ring,
                                size: 92,
                                gradient: [FMColor.blue, FMColor.indigo]
                            )

                            VStack(alignment: .leading, spacing: FMSpacing.md) {
                                FMGauge(
                                    value: diskRatio,
                                    in: 0...1,
                                    label: "NVMe SSD 容量",
                                    valueText: "\(Int((diskRatio * 1000).rounded())) / 1000 GB",
                                    style: .linearCapacity,
                                    gradient: [FMColor.teal, FMColor.blue]
                                )

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("渲染帧延迟趋势（悬停查看单点）")
                                            .font(.fmCaption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(Int(latencySamples.last ?? 0)) ms")
                                            .font(.fmNumeric(size: 12, weight: .semibold))
                                    }
                                    FMSparkline(
                                        values: latencySamples,
                                        color: FMColor.teal,
                                        lineWidth: 2,
                                        showsAreaFill: true,
                                        showsHoverScrub: true
                                    ) { value in
                                        "\(Int(value.rounded())) ms"
                                    }
                                    .frame(height: 54)
                                }
                            }
                        }
                    }

                    // v1.0 Multi-Step Wizard Progress Indicator
                    VStack(alignment: .leading, spacing: FMSpacing.md) {
                        FMSectionHeader(
                            "FMStepsIndicator · 多步向导进度条",
                            subtitle: "支持水平/垂直布局、弹簧完成对勾、点击已完结步骤回跳与异常步骤高亮",
                            showTopDivider: true
                        ) {
                            FMSegmentedPicker(selection: $wizardAxis, options: [Axis.horizontal, Axis.vertical]) { axis in
                                Text(axis == .horizontal ? "水平" : "垂直")
                            }
                            .frame(width: 132)
                        }

                        FMStepsIndicator(
                            steps: wizardSteps,
                            currentStep: $currentWizardStep,
                            errorSteps: wizardErrorSteps,
                            axis: wizardAxis,
                            allowsStepSelection: true
                        )
                        .padding(.vertical, FMSpacing.xs)

                        HStack(spacing: FMSpacing.sm) {
                            Button("上一步") {
                                currentWizardStep = FMStepsMath.clampedStep(currentWizardStep - 1, totalSteps: wizardSteps.count)
                            }
                            .buttonStyle(.fm(.secondary, isCapsule: true))
                            .disabled(currentWizardStep <= 0)

                            Button(currentWizardStep >= wizardSteps.count - 1 ? "重置流程" : "下一步") {
                                if currentWizardStep >= wizardSteps.count - 1 {
                                    currentWizardStep = 0
                                    wizardErrorSteps.removeAll()
                                } else {
                                    currentWizardStep += 1
                                }
                            }
                            .buttonStyle(.fm(.primary, isCapsule: true))

                            Button(wizardErrorSteps.contains(2) ? "清除异常标记" : "模拟第 3 步异常") {
                                if wizardErrorSteps.contains(2) {
                                    wizardErrorSteps.remove(2)
                                } else {
                                    wizardErrorSteps.insert(2)
                                }
                            }
                            .buttonStyle(.fm(.tinted, isCapsule: true, color: FMColor.red))
                        }
                    }

                    // Modals & Popovers
                    VStack(alignment: .leading, spacing: FMSpacing.sm) {
                        FMSectionHeader("模态抽屉、警告框与上下文菜单", showTopDivider: true)

                        HStack(spacing: FMSpacing.sm) {
                            Button("弹出 FMBottomSheet") {
                                showBottomSheet = true
                            }
                            .buttonStyle(.fm(.primary, isCapsule: true))
                            .fmTooltip("支持向下拖拽 Grabber 或按 Esc 关闭", shortcut: ["Esc"])

                            Button("弹出 FMAlert") {
                                showAlert = true
                            }
                            .buttonStyle(.fm(.secondary, isCapsule: true))

                            Button("FMActionPopover") {
                                showActionPopover.toggle()
                            }
                            .buttonStyle(.fm(.glass, isCapsule: true))
                            .fmActionPopover(
                                isPresented: $showActionPopover,
                                items: [
                                    .action(title: "快速快照", icon: "camera.aperture", shortcut: "⌘S") {
                                        hud.show(title: "已创建系统快照", style: .info)
                                    },
                                    .action(title: "导出诊断报告", icon: "square.and.arrow.up", shortcut: "⌘E") {
                                        hud.show(title: "诊断报告已导出", style: .success)
                                    },
                                    .divider(),
                                    .action(title: "重置全部缓存", icon: "trash.fill", isDestructive: true) {
                                        showAlert = true
                                    }
                                ]
                            )
                        }
                    }

                    // Progress Rings, Bars, Spinners, Badges & Skeleton
                    VStack(alignment: .leading, spacing: FMSpacing.md) {
                        FMSectionHeader("进度指示、纯 SwiftUI 加载器、徽标与骨架屏", showTopDivider: true) {
                            Toggle("骨架屏占位", isOn: $isSkeletonLoading)
                                .toggleStyle(.fmSwitch)
                        }

                        HStack(spacing: FMSpacing.lg) {
                            FMProgressRing(progress: progressValue, size: 68, lineWidth: 7)
                            FMProgressRing(progress: nil, size: 48, lineWidth: 5, colors: [FMColor.purple, FMColor.pink])

                            VStack(spacing: FMSpacing.xs) {
                                FMSpinner(style: .ring, size: .regular, tint: FMColor.blue)
                                FMSpinner(style: .petals, size: .regular, tint: FMColor.indigo)
                            }

                            VStack(alignment: .leading, spacing: FMSpacing.sm) {
                                FMProgressBar(progress: progressValue, height: 10)
                                FMProgressBar(progress: nil, height: 6)
                                FMSlider(value: $progressValue, style: .standard)
                            }
                        }
                        .fmSkeleton(isLoading: isSkeletonLoading, cornerRadius: 12)

                        HStack(spacing: FMSpacing.xs) {
                            FMBadge("在线", color: FMColor.green, style: .tinted, showsDot: true)
                            FMBadge("v1.0", color: FMColor.indigo, style: .solid, icon: "crown.fill")
                            FMTag("Swift 6.2", color: FMColor.orange, style: .outline)
                            Spacer()
                            FMKeycap("⌘", "⇧", "P")
                        }
                    }

                    FMHairlineDivider()

                    FMEmptyStateView(
                        icon: "tray.fill",
                        iconColor: FMColor.indigo,
                        title: "暂无待处理告警",
                        description: "系统核心守护进程、内存水位与磁盘健康度均处于最佳状态。",
                        actionTitle: "立即刷新巡检"
                    ) {
                        hud.show(title: "巡检完成 · 一切正常", style: .success)
                    }
                }
                .padding(.horizontal, 34)
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
        }
        .fmBottomSheet(isPresented: $showBottomSheet) {
            VStack(spacing: FMSpacing.md) {
                FMIconBadge("trash.fill", color: FMColor.red, size: 44)
                Text("深度清理确认")
                    .font(.fmTitle)
                Text("即将清理 Xcode 派生缓存与旧版系统日志（约 8.6 GB）。可向下拖拽顶部横条或按 Esc 键取消。")
                    .font(.fmSubheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: FMSpacing.sm) {
                    Button("取消") {
                        showBottomSheet = false
                    }
                    .buttonStyle(.fm(.secondary, fullWidth: true, isCapsule: true))

                    Button("确认清理") {
                        showBottomSheet = false
                        hud.show(title: "已清理 8.6 GB 磁盘空间", style: .success)
                    }
                    .buttonStyle(.fm(.destructive, fullWidth: true, isCapsule: true))
                }
            }
            .padding(FMSpacing.lg)
        }
        .fmAlert(
            isPresented: $showAlert,
            title: "重置全部本地缓存？",
            message: "该操作将清空索引缓存并在下次启动时重新构建，确认继续吗？",
            icon: "exclamationmark.triangle.fill",
            iconColor: FMColor.orange,
            buttons: [
                FMAlertButton("取消", role: .cancel),
                FMAlertButton("确认重置", role: .destructive) {
                    hud.show(title: "缓存已重置", style: .warning)
                }
            ]
        )
    }
}
