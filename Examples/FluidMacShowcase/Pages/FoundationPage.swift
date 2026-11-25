import SwiftUI
import FluidMacUI

struct FoundationPage: View {
    @Binding var isSidebarVisible: Bool
    @Binding var showInspector: Bool
    @Binding var showCommandPalette: Bool

    @State private var springToggle = false

    private let badges: [(String, Color)] = [
        ("sparkles", FMColor.indigo),
        ("bolt.fill", FMColor.orange),
        ("cpu.fill", FMColor.blue),
        ("flame.fill", FMColor.red),
        ("leaf.fill", FMColor.green),
        ("wand.and.stars", FMColor.purple),
        ("waveform", FMColor.teal),
        ("heart.fill", FMColor.pink)
    ]

    var body: some View {
        FMNavigationStack(
            title: ShowcaseSection.foundation.title,
            subtitle: ShowcaseSection.foundation.subtitle,
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
                    FMGlassCard(surface: .glass(.regular), hoverLift: true) {
                        VStack(alignment: .leading, spacing: FMSpacing.sm) {
                            HStack {
                                FMIconBadge("sparkles", color: FMColor.indigo, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Adaptive Optical Surface")
                                        .font(.fmTitle2)
                                    Text("支持 macOS 26 原生 Liquid Glass 折射与经典磨砂双模实时切换")
                                        .font(.fmSubheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                FMBadge("Live", color: FMColor.green, style: .tinted, showsDot: true)
                            }
                            Text("打开右侧检查器面板，即可实时切换侧边栏范式、画布背景、Liquid Glass/磨砂材质与动画慢放倍速。")
                                .font(.fmBody)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: FMSpacing.md) {
                        FMSectionHeader("FMIconBadge & FMAvatar", showTopDivider: true)

                        HStack(spacing: FMSpacing.md) {
                            ForEach(Array(badges.enumerated()), id: \.offset) { _, item in
                                FMIconBadge(item.0, color: item.1)
                            }
                            Spacer()
                            FMAvatar(initials: "LY", color: FMColor.indigo, size: 34, status: .online)
                            FMAvatar(initials: "FM", color: FMColor.orange, size: 34, status: .busy)
                        }
                    }

                    VStack(alignment: .leading, spacing: FMSpacing.md) {
                        FMSectionHeader("四级物理弹簧对比 (FMSpring)", showTopDivider: true) {
                            Button("触发弹簧对比") {
                                springToggle.toggle()
                            }
                            .buttonStyle(.fm(.tinted, isCapsule: true))
                        }

                        springRow(label: "Interactive (0.15 / 0.86)", level: .interactive, color: FMColor.teal)
                        springRow(label: "Micro (0.22 / 0.68)", level: .micro, color: FMColor.blue)
                        springRow(label: "Navigation (0.36 / 0.84)", level: .navigation, color: FMColor.indigo)
                        springRow(label: "Modal (0.42 / 0.78)", level: .modal, color: FMColor.purple)
                    }
                }
                .padding(.horizontal, 34)
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
        }
    }

    @ViewBuilder
    private func springRow(label: String, level: FMSpringLevel, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.fmFootnote)
                .foregroundStyle(.secondary)
            GeometryReader { proxy in
                let maxTravel = max(0, proxy.size.width - 24)
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(color.opacity(0.14))
                        .frame(height: 24)
                    Circle()
                        .fill(color)
                        .frame(width: 20, height: 20)
                        .padding(2)
                        .offset(x: springToggle ? maxTravel : 0)
                        .fmAnimation(level, value: springToggle)
                }
            }
            .frame(height: 24)
        }
    }
}
