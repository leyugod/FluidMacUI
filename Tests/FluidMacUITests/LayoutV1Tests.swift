import Testing
import SwiftUI
@testable import FluidMacUI

@Suite("Layout & Navigation v1.0 Tests")
struct LayoutV1Tests {

    // MARK: - FMSplitPaneMath

    @Test("FMSplitPaneMath clamps primary size within pane minimums and handles tight containers")
    func splitPaneClamping() {
        // Normal in-bounds
        #expect(FMSplitPaneMath.clampPrimarySize(300, total: 800, minPrimary: 180, minSecondary: 180) == 300)
        // Below minPrimary
        #expect(FMSplitPaneMath.clampPrimarySize(80, total: 800, minPrimary: 180, minSecondary: 180) == 180)
        // Above total - minSecondary
        #expect(FMSplitPaneMath.clampPrimarySize(720, total: 800, minPrimary: 180, minSecondary: 180) == 620)
        // Non-positive total
        #expect(FMSplitPaneMath.clampPrimarySize(200, total: 0, minPrimary: 180, minSecondary: 180) == 0)
        #expect(FMSplitPaneMath.clampPrimarySize(200, total: -50, minPrimary: 180, minSecondary: 180) == 0)
        // Negative mins are treated as zero
        #expect(FMSplitPaneMath.clampPrimarySize(-20, total: 500, minPrimary: -10, minSecondary: -10) == 0)
        #expect(FMSplitPaneMath.clampPrimarySize(600, total: 500, minPrimary: -10, minSecondary: -10) == 500)
        // Tight container where minPrimary + minSecondary > total divides proportionally
        let proportional = FMSplitPaneMath.clampPrimarySize(100, total: 150, minPrimary: 200, minSecondary: 100)
        #expect(abs(proportional - 100) < 0.001)
    }

    @Test("FMSplitPaneMath computes bounded ratios and respects minimums during stepping")
    func splitPaneRatiosAndStepping() {
        #expect(FMSplitPaneMath.ratio(for: 250, total: 1000) == 0.25)
        #expect(FMSplitPaneMath.ratio(for: -50, total: 1000) == 0)
        #expect(FMSplitPaneMath.ratio(for: 1400, total: 1000) == 1)
        #expect(FMSplitPaneMath.ratio(for: 100, total: 0) == 0)

        let clampedLow = FMSplitPaneMath.clampFraction(0.05, total: 1000, minPrimary: 200, minSecondary: 200)
        #expect(abs(clampedLow - 0.2) < 0.001)

        let clampedHigh = FMSplitPaneMath.clampFraction(0.95, total: 1000, minPrimary: 200, minSecondary: 200)
        #expect(abs(clampedHigh - 0.8) < 0.001)

        let steppedUp = FMSplitPaneMath.stepFraction(
            current: 0.78,
            delta: 0.05,
            total: 1000,
            minPrimary: 200,
            minSecondary: 200
        )
        #expect(abs(steppedUp - 0.8) < 0.001)

        let steppedDown = FMSplitPaneMath.stepFraction(
            current: 0.5,
            delta: -0.05,
            total: 1000,
            minPrimary: 200,
            minSecondary: 200
        )
        #expect(abs(steppedDown - 0.45) < 0.001)
    }

    // MARK: - FMOutlineTreeMath

    private var sampleTree: [FMOutlineNode<String>] {
        [
            FMOutlineNode(
                id: "src",
                title: "Sources",
                icon: "folder.fill",
                children: [
                    FMOutlineNode(
                        id: "nav",
                        title: "04_Navigation",
                        icon: "folder.fill",
                        children: [
                            FMOutlineNode(id: "split", title: "FMSplitPane.swift", icon: "swift")
                        ]
                    ),
                    FMOutlineNode(id: "empty", title: "EmptyFolder", icon: "folder", children: []),
                    FMOutlineNode(id: "rootSwift", title: "FluidMacUI.swift", icon: "swift")
                ]
            ),
            FMOutlineNode(id: "readme", title: "README.md", icon: "doc.text")
        ]
    }

    @Test("FMOutlineNode distinguishes leaves, empty folders, and populated branches")
    func outlineNodeMetadata() {
        let leaf = FMOutlineNode(id: "a", title: "Leaf")
        let emptyFolder = FMOutlineNode(id: "b", title: "Empty", children: [])
        let branch = FMOutlineNode(id: "c", title: "Branch", children: [leaf])

        #expect(!leaf.isContainer && !leaf.hasChildren)
        #expect(emptyFolder.isContainer && !emptyFolder.hasChildren)
        #expect(branch.isContainer && branch.hasChildren)
    }

    @Test("FMOutlineTreeMath flattens visible rows with accurate depth, parentID, and expansion state")
    func outlineTreeFlattening() {
        let roots = sampleTree

        // All collapsed
        let collapsed = FMOutlineTreeMath.flatten(roots, expanded: [])
        #expect(collapsed.map(\.id) == ["src", "readme"])
        #expect(collapsed[0].depth == 0)
        #expect(collapsed[0].isExpandable)
        #expect(!collapsed[0].isExpanded)
        #expect(collapsed[0].parentID == nil)
        #expect(!collapsed[1].isExpandable)

        // Expanded nested ID inside collapsed parent remains hidden
        let hiddenChild = FMOutlineTreeMath.flatten(roots, expanded: ["nav"])
        #expect(hiddenChild.map(\.id) == ["src", "readme"])

        // Expand top folder + empty folder
        let levelOne = FMOutlineTreeMath.flatten(roots, expanded: ["src", "empty"])
        #expect(levelOne.map(\.id) == ["src", "nav", "empty", "rootSwift", "readme"])
        #expect(levelOne[1].depth == 1)
        #expect(levelOne[1].parentID == "src")
        #expect(levelOne[1].isExpandable && !levelOne[1].isExpanded)
        // Empty folder is not expandable even if its ID is in expanded set
        #expect(!levelOne[2].isExpandable && !levelOne[2].isExpanded)

        // Full expansion
        let full = FMOutlineTreeMath.flatten(roots, expanded: ["src", "nav"])
        #expect(full.map(\.id) == ["src", "nav", "split", "empty", "rootSwift", "readme"])
        #expect(full[2].depth == 2)
        #expect(full[2].parentID == "nav")
    }

    @Test("FMOutlineTreeMath handles up/down selection stepping and clamping")
    func outlineSelectionStepping() {
        let rows = FMOutlineTreeMath.flatten(sampleTree, expanded: ["src", "nav"])

        let emptyRows: [FMFlattenedOutlineRow<String>] = []
        #expect(FMOutlineTreeMath.nextSelection(from: nil, in: emptyRows, delta: 1) == nil)
        #expect(FMOutlineTreeMath.nextSelection(from: nil, in: rows, delta: 1) == "src")
        #expect(FMOutlineTreeMath.nextSelection(from: nil, in: rows, delta: -1) == "readme")
        #expect(FMOutlineTreeMath.nextSelection(from: "src", in: rows, delta: -1) == "src")
        #expect(FMOutlineTreeMath.nextSelection(from: "src", in: rows, delta: 1) == "nav")
        #expect(FMOutlineTreeMath.nextSelection(from: "nav", in: rows, delta: 1) == "split")
        #expect(FMOutlineTreeMath.nextSelection(from: "readme", in: rows, delta: 5) == "readme")
        #expect(FMOutlineTreeMath.nextSelection(from: "missing", in: rows, delta: 1) == "src")
    }

    @Test("FMOutlineTreeMath handles right-arrow expand/descend and left-arrow collapse/ascend")
    func outlineArrowNavigation() {
        let roots = sampleTree
        var expanded: Set<String> = []
        var rows = FMOutlineTreeMath.flatten(roots, expanded: expanded)

        // Right on collapsed branch expands it without changing selection
        let step1 = FMOutlineTreeMath.expandOrDescend(from: "src", in: rows, expanded: expanded)
        #expect(step1.selection == "src")
        #expect(step1.expanded == ["src"])

        expanded = step1.expanded
        rows = FMOutlineTreeMath.flatten(roots, expanded: expanded)

        // Right on already-expanded branch descends to its first child
        let step2 = FMOutlineTreeMath.expandOrDescend(from: "src", in: rows, expanded: expanded)
        #expect(step2.selection == "nav")
        #expect(step2.expanded == ["src"])

        // Right on leaf is a no-op
        let leafRight = FMOutlineTreeMath.expandOrDescend(from: "rootSwift", in: rows, expanded: expanded)
        #expect(leafRight.selection == "rootSwift")
        #expect(leafRight.expanded == expanded)

        // Left on collapsed child ascends to parent
        let step3 = FMOutlineTreeMath.collapseOrAscend(from: "nav", in: rows, expanded: expanded)
        #expect(step3.selection == "src")
        #expect(step3.expanded == ["src"])

        // Left on expanded branch collapses it
        let step4 = FMOutlineTreeMath.collapseOrAscend(from: "src", in: rows, expanded: expanded)
        #expect(step4.selection == "src")
        #expect(step4.expanded.isEmpty)

        // Left on top-level collapsed branch is a no-op
        let collapsedRows = FMOutlineTreeMath.flatten(roots, expanded: [])
        let step5 = FMOutlineTreeMath.collapseOrAscend(from: "src", in: collapsedRows, expanded: [])
        #expect(step5.selection == "src")
        #expect(step5.expanded.isEmpty)
    }

    @Test("FMOutlineTreeMath computes toggle, expandable sets, and ancestor paths")
    func outlineTreeHelpers() {
        let roots = sampleTree
        #expect(FMOutlineTreeMath.allExpandableIDs(in: roots) == ["src", "nav"])
        #expect(FMOutlineTreeMath.ancestorIDs(of: "split", in: roots) == ["src", "nav"])
        #expect(FMOutlineTreeMath.ancestorIDs(of: "src", in: roots).isEmpty)
        #expect(FMOutlineTreeMath.ancestorIDs(of: "unknown", in: roots).isEmpty)

        let added = FMOutlineTreeMath.toggleExpanded("src", in: [])
        #expect(added == ["src"])
        let removed = FMOutlineTreeMath.toggleExpanded("src", in: added)
        #expect(removed.isEmpty)
    }

    // MARK: - FMPageControlMath

    @Test("FMPageControlMath clamps indices, handles stepping/wrapping, and computes progress")
    func pageControlMath() {
        #expect(FMPageControlMath.clamp(-3, pageCount: 4) == 0)
        #expect(FMPageControlMath.clamp(2, pageCount: 4) == 2)
        #expect(FMPageControlMath.clamp(10, pageCount: 4) == 3)
        #expect(FMPageControlMath.clamp(2, pageCount: 0) == 0)
        #expect(FMPageControlMath.clamp(2, pageCount: -5) == 0)

        // Clamped stepping
        #expect(FMPageControlMath.step(from: 0, delta: -1, pageCount: 4) == 0)
        #expect(FMPageControlMath.step(from: 1, delta: 1, pageCount: 4) == 2)
        #expect(FMPageControlMath.step(from: 3, delta: 1, pageCount: 4) == 3)

        // Wrapped stepping
        #expect(FMPageControlMath.step(from: 0, delta: -1, pageCount: 4, wraps: true) == 3)
        #expect(FMPageControlMath.step(from: 3, delta: 1, pageCount: 4, wraps: true) == 0)
        #expect(FMPageControlMath.step(from: 1, delta: -6, pageCount: 4, wraps: true) == 3)
        #expect(FMPageControlMath.step(from: 0, delta: 1, pageCount: 0, wraps: true) == 0)

        // Progress & last-page detection
        #expect(FMPageControlMath.progress(currentPage: 0, pageCount: 0) == 0)
        #expect(FMPageControlMath.progress(currentPage: 0, pageCount: 4) == 0.25)
        #expect(FMPageControlMath.progress(currentPage: 3, pageCount: 4) == 1.0)
        #expect(FMPageControlMath.isLastPage(0, pageCount: 0))
        #expect(FMPageControlMath.isLastPage(0, pageCount: 1))
        #expect(!FMPageControlMath.isLastPage(1, pageCount: 3))
        #expect(FMPageControlMath.isLastPage(2, pageCount: 3))
    }

    // MARK: - View Construction Smoke Checks

    @Test("All Batch B public views instantiate cleanly with default and custom parameters")
    func batchBViewsInstantiate() {
        var fraction: CGFloat = 0.4
        let split = FMSplitPane(
            axis: .horizontal,
            fraction: Binding(get: { fraction }, set: { fraction = $0 }),
            minPrimary: 160,
            minSecondary: 200
        ) {
            Text("Primary")
        } secondary: {
            Text("Secondary")
        }
        _ = split

        var selectedID: String? = "src"
        var expanded: Set<String> = ["src"]
        let tree = FMOutlineTree(
            roots: sampleTree,
            selection: Binding(get: { selectedID }, set: { selectedID = $0 }),
            expandedIDs: Binding(get: { expanded }, set: { expanded = $0 })
        )
        _ = tree

        let statusBar = FMStatusBar(
            leading: {
                FMStatusBarItem(icon: "arrow.triangle.branch", text: "main", statusColor: FMColor.green) {}
                FMStatusBarDivider()
                FMStatusBarItem(text: "42 items")
            },
            center: {
                FMStatusBarItem(text: "Ready")
            },
            trailing: {
                FMStatusBarItem(text: "Ln 12, Col 4")
            }
        )
        _ = statusBar

        var page = 0
        let pageControl = FMPageControl(
            currentPage: Binding(get: { page }, set: { page = $0 }),
            pageCount: 3,
            showsGlassBackdrop: true
        )
        _ = pageControl

        let pager = FMOnboardingPager(
            pages: [
                FMOnboardingPage(id: "welcome", icon: "sparkles", iconColor: FMColor.blue, title: "Welcome", description: "Start fast."),
                FMOnboardingPage(id: "ready", icon: "checkmark.seal.fill", iconColor: FMColor.green, title: "Ready", description: "All set.")
            ],
            onComplete: {}
        )
        _ = pager
    }
}
