import SwiftUI
import FluidMacUI

private struct PreviewSlide: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let gradient: [Color]
    let symbol: String
}

/// 1:1 Apple First-Party macOS App Store Detail Page built purely with FluidMacUI,
/// demonstrating clean editorial canvas typography, floating Liquid Glass circular toolbar,
/// horizontal metric strip, expandable release notes, horizontal carousel, and lightbox preview.
struct AppStoreDemoPage: View {
    @Environment(\.fmHUD) private var hud

    @Binding var isSidebarVisible: Bool
    @Binding var showInspector: Bool
    @Binding var showCommandPalette: Bool

    @State private var navController = FMNavigationController()
    @State private var isUpdating = false
    @State private var selectedSlide: PreviewSlide?

    private let slides: [PreviewSlide] = [
        PreviewSlide(
            id: "slide-1",
            title: "Design Presentations",
            subtitle: "Cinematic transitions & native Liquid Glass chrome",
            gradient: [Color(red: 0.14, green: 0.16, blue: 0.24), Color(red: 0.09, green: 0.10, blue: 0.14)],
            symbol: "play.rectangle.on.rectangle.fill"
        ),
        PreviewSlide(
            id: "slide-2",
            title: "Premium Templates",
            subtitle: "Over 40 handcrafted editorial decks & grids",
            gradient: [Color(red: 0.12, green: 0.22, blue: 0.34), Color(red: 0.08, green: 0.12, blue: 0.20)],
            symbol: "rectangle.grid.3x2.fill"
        ),
        PreviewSlide(
            id: "slide-3",
            title: "Real-Time Collaboration",
            subtitle: "Co-edit live across Mac, iPad, and iPhone",
            gradient: [Color(red: 0.22, green: 0.14, blue: 0.30), Color(red: 0.10, green: 0.09, blue: 0.16)],
            symbol: "person.2.wave.2.fill"
        )
    ]

    private let metrics: [FMMetricItem] = [
        FMMetricItem(topLabel: "9.3K Ratings", value: .rating(4.7)),
        FMMetricItem(topLabel: "Age Rating", value: .text("4+"), bottomLabel: "Years"),
        FMMetricItem(topLabel: "Category", value: .icon("paperplane.fill"), bottomLabel: "Productivity"),
        FMMetricItem(topLabel: "Developer", value: .icon("person.crop.square"), bottomLabel: "Apple"),
        FMMetricItem(topLabel: "Language", value: .text("EN"), bottomLabel: "+ 32 More"),
        FMMetricItem(topLabel: "Size", value: .text("1.03"), bottomLabel: "GB")
    ]

    var body: some View {
        FMNavigationStack(
            controller: navController,
            title: "Keynote: Design Presentations",
            titleIcon: "chart.bar.doc.horizontal.fill",
            titleIconColor: FMColor.blue,
            headerStyle: .floating
        ) {
            Button(isUpdating ? "Updating..." : "Update") {
                triggerUpdate()
            }
            .buttonStyle(.fm(.primary, isLoading: isUpdating, isCapsule: true))
            .fmDensity(.compact)
        } trailingBar: {
            HStack(spacing: 8) {
                FMToolbarButton(icon: "square.and.arrow.up") {
                    hud.show(icon: "link", title: "已复制应用分享链接", style: .success)
                }
                .fmTooltip("分享", edge: .bottom)

                ShowcaseToolbarControls(
                    isSidebarVisible: $isSidebarVisible,
                    showInspector: $showInspector,
                    showCommandPalette: $showCommandPalette
                )
            }
        } root: {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    // 1. Hero Header
                    FMHeroHeader(
                        title: "Keynote: Design Presentations",
                        subtitle: "Build and present your story",
                        artworkSize: 98
                    ) {
                        ZStack {
                            LinearGradient(
                                colors: [Color(red: 0.12, green: 0.62, blue: 1.0), Color(red: 0.02, green: 0.30, blue: 0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            Image(systemName: "chart.bar.doc.horizontal.fill")
                                .font(.system(size: 46, weight: .semibold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                        }
                    } actions: {
                        Button(isUpdating ? "Updating..." : "Update") {
                            triggerUpdate()
                        }
                        .buttonStyle(.fm(.primary, isLoading: isUpdating, isCapsule: true))
                        .controlSize(.small)

                        FMAvatarGroup(
                            members: [
                                .init(initials: "AL", color: FMColor.indigo),
                                .init(initials: "MK", color: FMColor.orange),
                                .init(initials: "JY", color: FMColor.green),
                                .init(initials: "SR", color: FMColor.pink),
                                .init(initials: "CW", color: FMColor.teal)
                            ],
                            maxVisible: 3,
                            size: 26
                        )
                    }

                    // 2. Horizontal Spec Metric Strip
                    FMMetricStrip(items: metrics)

                    // 3. Also Included In (Editorial inline row — NO heavy box card!)
                    VStack(alignment: .leading, spacing: FMSpacing.md) {
                        FMSectionHeader("Also Included In")

                        HStack(spacing: FMSpacing.md) {
                            ZStack {
                                LinearGradient(
                                    colors: [FMColor.green, FMColor.blue, FMColor.purple, FMColor.pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                Image(systemName: "infinity")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Apple Creator Studio")
                                    .font(.fmHeadline)
                                Text("Photo & Video · 4 Apps Included")
                                    .font(.fmSubheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer().frame(width: 24)

                            Button("View") {
                                pushBundleDetail()
                            }
                            .buttonStyle(.fm(.secondary, isCapsule: true))

                            Spacer()
                        }
                    }

                    // 4. What's New
                    VStack(alignment: .leading, spacing: FMSpacing.sm) {
                        FMSectionHeader(
                            "What's New",
                            showTopDivider: true,
                            actionTitle: "Version History"
                        ) {
                            pushVersionHistory()
                        }

                        HStack(alignment: .top, spacing: FMSpacing.xl) {
                            FMExpandableText(
                                "For Apple Creator Studio Subscribers: Intelligent Assistant (Beta) helps structure narrative slides, refine visual hierarchy, and generate cohesive FluidMacUI-grade transitions automatically. Includes native macOS 26 Liquid Glass toolbar support, concentric corner alignment, and ProMotion 120Hz timeline playback.",
                                lineLimit: 2
                            )

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("6d ago")
                                    .font(.fmSubheadline)
                                    .foregroundStyle(.secondary)
                                Text("Version 16.0")
                                    .font(.fmSubheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 96, alignment: .trailing)
                        }
                    }

                    // 5. Preview Horizontal Carousel + Lightbox
                    VStack(alignment: .leading, spacing: FMSpacing.md) {
                        FMSectionHeader("Preview", showTopDivider: true)

                        FMHorizontalCarousel(slides, spacing: 18) { slide in
                            slideCard(slide)
                                .onTapGesture {
                                    selectedSlide = slide
                                }
                        }
                    }
                }
                .padding(.horizontal, 34)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .fmLightbox(selectedItem: $selectedSlide, items: slides) { slide in
            slideCard(slide, large: true)
        }
    }

    @ViewBuilder
    private func slideCard(_ slide: PreviewSlide, large: Bool = false) -> some View {
        let w: CGFloat = large ? 760 : 410
        let h: CGFloat = large ? 460 : 250

        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: slide.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack {
                Spacer()
                Image(systemName: slide.symbol)
                    .font(.system(size: large ? 92 : 56, weight: .light))
                    .foregroundStyle(.white.opacity(0.24))
                Spacer()
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text(slide.title)
                    .font(.system(size: large ? 28 : 19, weight: .bold))
                    .foregroundStyle(.white)
                Text(slide.subtitle)
                    .font(.system(size: large ? 15 : 13))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(large ? 28 : 20)
        }
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.24), radius: 14, y: 6)
    }

    private func triggerUpdate() {
        isUpdating = true
        let id = hud.show(title: "正在下载 Keynote 16.0 更新...", style: .loading)
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            isUpdating = false
            hud.update(id: id, title: "Keynote 已更新至最新版本", style: .success)
        }
    }

    private func pushVersionHistory() {
        withAnimation(FMSpring.navigation) {
            _ = navController.push(title: "Version History") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        FMSectionHeader("Version History", subtitle: "触控板双指右滑、点击左上角玻璃圆钮 < 或按 ⌘[ 返回")

                        FMHairlineDivider()

                        versionItem("16.0", date: "6d ago", notes: "全面适配 macOS 26 Liquid Glass 悬浮圆形工具栏、同心圆角与 120Hz 视差导航；零透底纯净原生画布。")
                        FMHairlineDivider()
                        versionItem("15.4", date: "2mo ago", notes: "优化 HDR 幻灯片导出性能，新增协作头像组与实时光标同步。")
                        FMHairlineDivider()
                        versionItem("15.0", date: "5mo ago", notes: "全新编辑器引擎，支持更细腻的物理弹簧转场与多窗口独立状态隔离。")
                    }
                    .padding(.horizontal, 34)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func pushBundleDetail() {
        withAnimation(FMSpring.navigation) {
            _ = navController.push(title: "Apple Creator Studio") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        FMHeroHeader(
                            icon: "infinity",
                            iconColor: FMColor.indigo,
                            title: "Apple Creator Studio",
                            subtitle: "All-in-one creative suite for macOS"
                        ) {
                            Button("Subscribe") {
                                hud.show(title: "已开启 Apple Creator Studio 试用", style: .success)
                            }
                            .buttonStyle(.fm(.primary, isCapsule: true))
                        }

                        FMHairlineDivider()

                        FMInlineBanner(
                            tone: .info,
                            title: "原生零透底视差推入验证",
                            message: "二级页面拥有完整独立的不透明原生画布底色，底层页面向左 -25% 视差退后并柔和压暗，彻底消除透底问题。"
                        )
                    }
                    .padding(.horizontal, 34)
                    .padding(.top, 12)
                }
            }
        }
    }

    @ViewBuilder
    private func versionItem(_ version: String, date: String, notes: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Version \(version)")
                    .font(.fmHeadline)
                Spacer()
                Text(date)
                    .font(.fmFootnote)
                    .foregroundStyle(.secondary)
            }
            Text(notes)
                .font(.fmBody)
                .foregroundStyle(.secondary)
        }
    }
}
