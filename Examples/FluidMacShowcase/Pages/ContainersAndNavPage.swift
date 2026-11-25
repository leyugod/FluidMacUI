import SwiftUI
import FluidMacUI

struct ContainersAndNavPage: View {
    @Environment(\.fmHUD) private var hud
    @Environment(\.colorScheme) private var colorScheme

    @Binding var isSidebarVisible: Bool
    @Binding var showInspector: Bool
    @Binding var showCommandPalette: Bool

    @State private var navController = FMNavigationController()
    @State private var accordionOpen = true
    @State private var selectedCapsuleTab = "overview"

    // v1.0 Batch B State
    @State private var splitFraction: CGFloat = 0.44
    @State private var standalonePage = 1

    private let onboardingPages: [FMOnboardingPage] = [
        FMOnboardingPage(
            id: "glass",
            icon: "sparkles",
            iconColor: FMColor.indigo,
            title: "macOS 26 Liquid Glass",
            description: "原生光学折射与同心曲率圆角，自动降级适配降低透明度与高对比度模式。"
        ),
        FMOnboardingPage(
            id: "pure-swiftui",
            icon: "slider.horizontal.3",
            iconColor: FMColor.blue,
            title: "100% Pure SwiftUI",
            description: "彻底消除老旧 AppKit 蓝框、日期表盘与进度菊花，全组件支持弹簧交互与触控板震动。"
        ),
        FMOnboardingPage(
            id: "swift6",
            icon: "checkmark.shield.fill",
            iconColor: FMColor.green,
            title: "Swift 6.2 & Accessibility",
            description: "严格并发安全、键盘焦点环、VoiceOver 语义与失活窗口 0% GPU 休眠保障。"
        )
    ]

    var body: some View {
        FMNavigationStack(
            controller: navController,
            title: ShowcaseSection.containersNav.title,
            subtitle: ShowcaseSection.containersNav.subtitle,
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
                    FMInsetGroup(title: "FMNavigationStack 视差推入与触控板双指滑返", footer: "支持页面独立滚动偏移、不透明画布防透底与悬浮圆形 Liquid Glass 返回键 <。") {
                        FMRow(
                            icon: "arrow.right.circle.fill",
                            iconColor: FMColor.blue,
                            title: "推入二级详情页",
                            subtitle: "体验右侧 100% 滑入 + 底层 -25% 视差压暗",
                            showDivider: false,
                            showChevron: true
                        ) {
                            pushDetailPage(level: 1)
                        }
                    }

                    // v1.0 Resizable Split Pane
                    VStack(alignment: .leading, spacing: FMSpacing.sm) {
                        FMSectionHeader(
                            "FMSplitPane 通用可调分栏视图",
                            subtitle: "拖动中间分割线实时调整比例，双击分割线平滑回弹至 50%（支持方向键微调）",
                            showTopDivider: true
                        ) {
                            FMTag("\(Int((splitFraction * 100).rounded()))% / \(100 - Int((splitFraction * 100).rounded()))%", color: FMColor.blue, style: .tinted)
                        }

                        FMSplitPane(
                            axis: .horizontal,
                            fraction: $splitFraction,
                            minPrimary: 160,
                            minSecondary: 200,
                            resetFractionOnDoubleClick: 0.5
                        ) {
                            VStack(alignment: .leading, spacing: FMSpacing.xs) {
                                Label("主面板 (Primary)", systemImage: "sidebar.squares.leading")
                                    .font(.fmHeadline)
                                Text("适用于邮件列表、代码文件树或大纲目录。拖动分割线自动切换系统缩放光标并确保安全回收。")
                                    .font(.fmSubheadline)
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 0)
                            }
                            .padding(FMSpacing.md)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .background(FMColor.sidebarBackground(colorScheme))
                        } secondary: {
                            VStack(alignment: .leading, spacing: FMSpacing.xs) {
                                Label("次面板 (Secondary)", systemImage: "doc.richtext")
                                    .font(.fmHeadline)
                                Text("右侧预览或详情区域保持最小安全宽度，双击分割线即可伴随触控板对齐震动恢复对称布局。")
                                    .font(.fmSubheadline)
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 0)
                                HStack {
                                    FMTag("Live Ratio", color: FMColor.teal, style: .tinted)
                                    Spacer()
                                    Button("重置 50%") {
                                        withAnimation(FMSpring.navigation) {
                                            splitFraction = 0.5
                                        }
                                    }
                                    .buttonStyle(.fmGhost)
                                }
                            }
                            .padding(FMSpacing.md)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .background(FMColor.canvasBackground(colorScheme))
                        }
                        .frame(height: 184)
                        .fmClipCorner(FMCornerRadius.card)
                        .overlay {
                            RoundedRectangle(cornerRadius: FMCornerRadius.card, style: .continuous)
                                .strokeBorder(FMColor.separator(colorScheme), lineWidth: 0.75)
                                .allowsHitTesting(false)
                        }
                    }

                    // v1.0 Page Control & Onboarding Pager
                    VStack(alignment: .leading, spacing: FMSpacing.md) {
                        FMSectionHeader(
                            "FMPageControl & FMOnboardingPager · 流体胶囊页码与引导页",
                            subtitle: "当前页圆点平滑形变为 20×6pt 胶囊，支持点击跳转、←/→ 键翻页与减弱动态淡入降级",
                            showTopDivider: true
                        ) {
                            HStack(spacing: FMSpacing.xs) {
                                FMPageControl(
                                    currentPage: $standalonePage,
                                    pageCount: 5,
                                    showsGlassBackdrop: true
                                )
                                Text("\(standalonePage + 1) / 5")
                                    .font(.fmNumeric(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        FMOnboardingPager(
                            pages: onboardingPages,
                            continueTitle: "下一步",
                            doneTitle: "开始探索 v1.0",
                            backTitle: "上一步",
                            skipTitle: "跳过"
                        ) {
                            hud.show(icon: "checkmark.seal.fill", title: "引导流程完成", style: .success)
                        }
                        .frame(maxWidth: 560)
                    }

                    VStack(alignment: .leading, spacing: FMSpacing.sm) {
                        FMSectionHeader("FMTabBar 悬浮流体胶囊栏", showTopDivider: true)

                        FMTabBar(
                            selection: $selectedCapsuleTab,
                            items: [
                                FMTabItem(id: "overview", title: "总览", icon: "sparkles"),
                                FMTabItem(id: "metrics", title: "指标", icon: "chart.xyaxis.line"),
                                FMTabItem(id: "storage", title: "存储", icon: "internaldrive.fill"),
                                FMTabItem(id: "network", title: "网络", icon: "network")
                            ]
                        )
                    }

                    FMExpandableGroup(
                        title: "FMExpandableGroup 手风琴折叠面板",
                        subtitle: "点击头部体验 90° 箭头弹簧旋转与内容平滑展开",
                        icon: "chevron.down.circle.fill",
                        iconColor: FMColor.purple,
                        isExpanded: $accordionOpen
                    ) {
                        Text("折叠面板内部可自由承载表单、日志预览或说明文本，完全适配三档布局密度与高对比度模式。")
                            .font(.fmBody)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: FMSpacing.sm) {
                        FMSectionHeader("FMGridCard Bento 仪表盘网格", showTopDivider: true)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FMSpacing.md) {
                            FMGridCard(
                                title: "内存压缩引擎",
                                subtitle: "实时运行中",
                                icon: "memorychip.fill",
                                iconColor: FMColor.green,
                                action: { pushDetailPage(level: 1) }
                            ) {
                                FMBadge("极佳", color: FMColor.green, style: .tinted, showsDot: true)
                            } content: {
                                Text("已回收 3.8 GB 闲置分页")
                                    .font(.fmNumeric(size: 20, weight: .bold))
                                    .padding(.top, 4)
                            }

                            FMGridCard(
                                title: "神经渲染管线",
                                subtitle: "Metal 120Hz",
                                icon: "gpu",
                                iconColor: FMColor.indigo,
                                action: { pushDetailPage(level: 1) }
                            ) {
                                FMKeycap("⌘", "R")
                            } content: {
                                Text("窗口失活自动 0% GPU 休眠")
                                    .font(.fmBody)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                    }
                }
                .padding(.horizontal, 34)
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
        }
    }

    private func pushDetailPage(level: Int) {
        withAnimation(FMSpring.navigation) {
            _ = navController.push(
                title: "第 \(level) 层详情页",
                subtitle: "触控板双指右滑或按 ⌘[ 返回上一层"
            ) {
                ScrollView {
                    VStack(alignment: .leading, spacing: FMSpacing.lg) {
                        FMSectionHeader("当前路由深度：\(level)", subtitle: "纯正不透明原生画布，彻底杜绝底页穿透")

                        Text("底层页面向左偏移 -25% 并柔和压暗，左上角自动呈现与交通灯齐平的圆形 Liquid Glass 返回按钮 <。")
                            .font(.fmBody)
                            .foregroundStyle(.secondary)

                        HStack(spacing: FMSpacing.sm) {
                            Button("继续推入第 \(level + 1) 层") {
                                pushDetailPage(level: level + 1)
                            }
                            .buttonStyle(.fm(.primary, isCapsule: true))

                            Button("返回根页面") {
                                withAnimation(FMSpring.navigation) {
                                    navController.popToRoot()
                                }
                            }
                            .buttonStyle(.fm(.secondary, isCapsule: true))
                        }
                    }
                    .padding(.horizontal, 34)
                    .padding(.top, 16)
                }
            }
        }
    }
}
