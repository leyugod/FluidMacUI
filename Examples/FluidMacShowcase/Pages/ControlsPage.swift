import SwiftUI
import FluidMacUI

struct ControlsPage: View {
    @Environment(\.fmHUD) private var hud

    @Binding var isSidebarVisible: Bool
    @Binding var showInspector: Bool
    @Binding var showCommandPalette: Bool

    @State private var isLoadingButton = false
    @State private var switchA = true
    @State private var checkA = true
    @State private var checkB = false
    @State private var perfMode = "均衡"
    @State private var standardSlider = 0.55
    @State private var capsuleSlider = 0.72
    @State private var username = "FluidMac"
    @State private var fieldError: String? = nil
    @State private var password = "super-secret-token"
    @State private var notes = ""
    @State private var searchQuery = ""
    @State private var workerCount = 6
    @State private var selectedRegion = "东京 · Tokyo"

    // v1.0 Batch A Controls State
    @State private var inlineRadioChoice = "automatic"
    @State private var cardRadioChoice = "pro"
    @State private var selectedBranch: String? = "main"
    @State private var selectedFrameworks: Set<String> = ["SwiftUI", "Metal"]
    @State private var monthlyBudget: Double = 249.50
    @State private var requestTimeoutMs: Double = 1200
    @State private var otpCode = "482"
    @State private var otpHasError = false
    @State private var quickLaunchShortcut: FMKeyShortcut? = FMKeyShortcut(key: "K", modifiers: [.command, .shift])

    private let branchOptions = [
        "main",
        "release/v1.0",
        "feat/liquid-glass",
        "feat/outline-tree",
        "fix/focus-rings",
        "chore/docc-catalog"
    ]

    private let frameworkOptions = [
        "SwiftUI",
        "Metal",
        "AppKit",
        "Combine",
        "Swift Testing",
        "CoreGraphics",
        "UniformTypeIdentifiers"
    ]

    var body: some View {
        FMNavigationStack(
            title: ShowcaseSection.controls.title,
            subtitle: ShowcaseSection.controls.subtitle,
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
                    FMSearchBar(text: $searchQuery, placeholder: "搜索控件或按 Esc 清除聚焦...")

                    // Buttons & Pure-SwiftUI Spinner
                    VStack(alignment: .leading, spacing: FMSpacing.sm) {
                        FMSectionHeader("FMButtonStyle & FMSpinner · 6 种语义变体与纯 SwiftUI 加载器")

                        HStack(spacing: FMSpacing.sm) {
                            Button("Primary") {
                                hud.show(title: "Primary 按钮点击", style: .info)
                            }
                            .buttonStyle(.fm(.primary, isCapsule: true))

                            Button("Secondary") {}
                                .buttonStyle(.fm(.secondary, isCapsule: true))

                            Button("Tinted") {}
                                .buttonStyle(.fm(.tinted, isCapsule: true))

                            Button("Glass") {}
                                .buttonStyle(.fm(.glass, isCapsule: true))

                            Button("Ghost") {}
                                .buttonStyle(.fmGhost)

                            Button("Destructive") {}
                                .buttonStyle(.fm(.destructive, isCapsule: true))
                        }

                        HStack(spacing: FMSpacing.md) {
                            Button(isLoadingButton ? "优化中..." : "测试内联加载态") {
                                isLoadingButton = true
                                Task {
                                    try? await Task.sleep(for: .seconds(1.5))
                                    isLoadingButton = false
                                    hud.show(title: "任务执行完成", style: .success)
                                }
                            }
                            .buttonStyle(.fm(.primary, isLoading: isLoadingButton, isCapsule: true))

                            FMHairlineDivider(.vertical)
                                .frame(height: 22)

                            HStack(spacing: FMSpacing.sm) {
                                FMSpinner(style: .ring, size: .small)
                                FMSpinner(style: .ring, size: .regular)
                                FMSpinner(style: .ring, size: .large, tint: FMColor.indigo)
                                FMSpinner(style: .petals, size: .small)
                                FMSpinner(style: .petals, size: .regular)
                                FMSpinner(style: .petals, size: .large, tint: FMColor.teal)
                            }
                            Text("0% 失活窗口 GPU")
                                .font(.fmFootnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Core switches, sliders, steppers, dropdown
                    FMInsetGroup(title: "开关、滑杆、分段与步进器", footer: "所有控件均已修复原生矩形蓝框问题，按 Tab 键盘聚焦仅显示柔和胶囊/连续曲率光环。") {
                        FMRow(icon: "bolt.fill", iconColor: FMColor.orange, title: "iOS 物理拉伸开关", subtitle: "支持按压拉伸与左右滑动切换") {
                            Toggle("", isOn: $switchA)
                                .toggleStyle(.fmSwitch)
                        }
                        FMRow(icon: "checkmark.circle.fill", iconColor: FMColor.green, title: "提醒事项圆形勾选框") {
                            HStack(spacing: FMSpacing.md) {
                                Toggle("自动备份", isOn: $checkA)
                                    .toggleStyle(.fmCheckbox)
                                Toggle("静默更新", isOn: $checkB)
                                    .toggleStyle(.fmCheckbox(tint: FMColor.purple))
                            }
                        }
                        FMRow(icon: "dial.high.fill", iconColor: FMColor.blue, title: "FMSegmentedPicker") {
                            FMSegmentedPicker(selection: $perfMode, options: ["静音", "均衡", "极速"])
                                .frame(width: 210)
                        }
                        FMRow(icon: "speaker.wave.2.fill", iconColor: FMColor.indigo, title: "标准圆球滑杆") {
                            FMSlider(value: $standardSlider, step: 0.05)
                                .frame(width: 190)
                        }
                        FMRow(icon: "sun.max.fill", iconColor: FMColor.yellow, title: "控制中心宽体胶囊滑杆") {
                            FMSlider(value: $capsuleSlider, style: .controlCenterCapsule, tint: FMColor.orange, icon: "sun.max.fill")
                                .frame(width: 190)
                        }
                        FMRow(icon: "cpu", iconColor: FMColor.purple, title: "并发工作线程 (FMStepper)") {
                            FMStepper(value: $workerCount, in: 1...32, suffix: " 核")
                        }
                        FMRow(icon: "globe", iconColor: FMColor.teal, title: "边缘节点 (FMDropdownPicker)", showDivider: false) {
                            FMDropdownPicker(
                                selection: $selectedRegion,
                                options: ["东京 · Tokyo", "新加坡 · Singapore", "旧金山 · San Francisco", "法兰克福 · Frankfurt"],
                                title: { $0 },
                                icon: { _ in "server.rack" }
                            )
                            .frame(width: 210)
                        }
                    }

                    // v1.0 Radio Group (.inline & .card)
                    VStack(alignment: .leading, spacing: FMSpacing.md) {
                        FMSectionHeader(
                            "FMRadioGroup · 行内与卡片式单选",
                            subtitle: "支持方向键切换、同心圆弹簧回弹与 VoiceOver 选中状态",
                            showTopDivider: true
                        )

                        FMRadioGroup(
                            selection: $inlineRadioChoice,
                            options: [
                                FMRadioOption(id: "automatic", title: "自动匹配系统", subtitle: "跟随 macOS 浅色/深色"),
                                FMRadioOption(id: "light", title: "始终浅色", subtitle: "高亮文档阅读画布"),
                                FMRadioOption(id: "dark", title: "始终深色", subtitle: "低眩光专业工作站")
                            ],
                            style: .inline,
                            axis: .horizontal
                        )

                        FMRadioGroup(
                            selection: $cardRadioChoice,
                            options: [
                                FMRadioOption(id: "starter", title: "Starter", subtitle: "独立工具与原型开发", icon: "leaf.fill"),
                                FMRadioOption(id: "pro", title: "Studio Pro", subtitle: "完整 macOS 26 桌面组件套件", icon: "sparkles"),
                                FMRadioOption(id: "enterprise", title: "Enterprise", subtitle: "自定义设计 Token 与多窗口协同", icon: "building.2.fill")
                            ],
                            style: .card,
                            axis: .horizontal
                        )
                    }

                    // v1.0 Searchable ComboBox & Shortcut Recorder
                    FMInsetGroup(
                        title: "FMComboBox 搜索下拉与 FMShortcutRecorder 快捷键录制",
                        footer: "FMComboBox 支持前缀优先模糊搜索与 ↑/↓/↵/Esc 键盘导航；快捷键录制器支持自动校验冲突并忽略单独修饰键。"
                    ) {
                        FMRow(
                            icon: "arrow.triangle.branch",
                            iconColor: FMColor.indigo,
                            title: "单选可搜索分支",
                            subtitle: "FMComboBox (Single-Select)"
                        ) {
                            FMComboBox(
                                selection: $selectedBranch,
                                options: branchOptions,
                                placeholder: "选择分支...",
                                searchPlaceholder: "过滤分支名...",
                                title: { $0 },
                                icon: { _ in "arrow.triangle.branch" }
                            )
                            .frame(width: 240)
                        }

                        FMRow(
                            icon: "square.stack.3d.up.fill",
                            iconColor: FMColor.teal,
                            title: "多选技术栈标签",
                            subtitle: "FMComboBox (Multi-Select)"
                        ) {
                            FMComboBox(
                                selection: $selectedFrameworks,
                                options: frameworkOptions,
                                placeholder: "选择框架...",
                                searchPlaceholder: "搜索框架...",
                                title: { $0 }
                            )
                            .frame(width: 300)
                        }

                        FMRow(
                            icon: "keyboard",
                            iconColor: FMColor.purple,
                            title: "快速唤起快捷键",
                            subtitle: "点击后按下组合键，Esc 取消，⌫ 清除（校验禁止 ⌘Q）",
                            showDivider: false
                        ) {
                            FMShortcutRecorder(
                                shortcut: $quickLaunchShortcut,
                                placeholder: "录制快捷键"
                            ) { candidate in
                                if candidate.key == "Q" && candidate.modifiers == .command {
                                    return "⌘Q 为 macOS 系统退出保留键"
                                }
                                return nil
                            }
                            .frame(width: 210)
                        }
                    }

                    // v1.0 Formatted Numeric & OTP Fields
                    VStack(alignment: .leading, spacing: FMSpacing.md) {
                        FMSectionHeader(
                            "FMNumberField & FMOTPField · 格式化数值与分段验证码",
                            subtitle: "支持 ↑/↓ 键盘微调（Shift 10× 步进）、⌘V 整段验证码粘贴与 Reduce Motion 安全抖动",
                            showTopDivider: true
                        ) {
                            Button(otpHasError ? "清除 OTP 错误态" : "模拟 OTP 错误抖动") {
                                otpHasError.toggle()
                            }
                            .buttonStyle(.fmGhost)
                        }

                        HStack(alignment: .top, spacing: FMSpacing.md) {
                            VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                                Text("月度算力预算（USD）")
                                    .font(.fmCaption)
                                    .foregroundStyle(.secondary)
                                FMNumberField(
                                    "0.00",
                                    value: $monthlyBudget,
                                    range: 0...10_000,
                                    step: 25,
                                    precision: 2,
                                    prefix: "$"
                                )
                            }

                            VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                                Text("RPC 超时阈值")
                                    .font(.fmCaption)
                                    .foregroundStyle(.secondary)
                                FMNumberField(
                                    "1000",
                                    value: $requestTimeoutMs,
                                    range: 50...5000,
                                    step: 50,
                                    precision: 0,
                                    suffix: "ms"
                                )
                            }
                        }

                        VStack(alignment: .leading, spacing: FMSpacing.xs) {
                            Text("6 位双重验证代码（支持直接键入或 ⌘V 粘贴）")
                                .font(.fmCaption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: FMSpacing.md) {
                                FMOTPField(
                                    code: $otpCode,
                                    length: 6,
                                    isError: otpHasError
                                ) { completed in
                                    otpHasError = false
                                    hud.show(title: "验证码已提交：\(completed)", style: .success)
                                }

                                Button("填充演示码") {
                                    otpHasError = false
                                    otpCode = "260100"
                                }
                                .buttonStyle(.fm(.secondary, isCapsule: true))
                            }
                        }
                    }

                    // Standard Text Inputs
                    VStack(alignment: .leading, spacing: FMSpacing.sm) {
                        FMSectionHeader("无蓝框现代输入套件", showTopDivider: true) {
                            Button(fieldError == nil ? "模拟校验错误抖动" : "清除错误") {
                                fieldError = fieldError == nil ? "节点名称不可包含非法空格字符" : nil
                            }
                            .buttonStyle(.fmGhost)
                        }

                        HStack(spacing: FMSpacing.sm) {
                            FMTextField("输入名称...", text: $username, icon: "person.fill", errorMessage: fieldError)
                            FMSecureField("API Secret Token", text: $password)
                        }

                        FMTextEditor("输入多行备注内容（无原生 NSTextView 边框割裂感）...", text: $notes, minHeight: 84, maxCharacters: 200)
                    }
                }
                .padding(.horizontal, 34)
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
        }
    }
}
