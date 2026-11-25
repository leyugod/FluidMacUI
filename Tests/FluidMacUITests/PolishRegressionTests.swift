import Testing
import SwiftUI
import UniformTypeIdentifiers
@testable import FluidMacUI

@Suite("Batch D Polish Regression Tests")
struct PolishRegressionTests {
    @Test("FMButtonMetrics scales cleanly across ControlSize and FMDensity")
    func buttonMetricsControlSizeScaling() {
        let mini = FMButtonMetrics.resolve(density: .regular, controlSize: .mini)
        let small = FMButtonMetrics.resolve(density: .regular, controlSize: .small)
        let regular = FMButtonMetrics.resolve(density: .regular, controlSize: .regular)
        let large = FMButtonMetrics.resolve(density: .regular, controlSize: .large)

        #expect(mini.minHeight < small.minHeight)
        #expect(small.minHeight < regular.minHeight)
        #expect(regular.minHeight < large.minHeight)
        #expect(small.fontSize < regular.fontSize)
        #expect(regular.fontSize < large.fontSize)
    }

    @Test("FMSliderMath pointer mapping accounts for thumb half-width insets")
    func sliderPointerThumbInsetMapping() {
        // Track width 200, thumb diameter 20 -> usable 180, edges at x=10 and x=190.
        #expect(FMSliderMath.progress(locationX: 10, trackWidth: 200, thumbDiameter: 20) == 0.0)
        #expect(FMSliderMath.progress(locationX: 100, trackWidth: 200, thumbDiameter: 20) == 0.5)
        #expect(FMSliderMath.progress(locationX: 190, trackWidth: 200, thumbDiameter: 20) == 1.0)
        // Clamping beyond bounds
        #expect(FMSliderMath.progress(locationX: 0, trackWidth: 200, thumbDiameter: 20) == 0.0)
        #expect(FMSliderMath.progress(locationX: 220, trackWidth: 200, thumbDiameter: 20) == 1.0)
    }

    @Test("FMAlertShortcutResolver never binds Return key to destructive buttons")
    func alertReturnKeySafety() {
        let destructiveOnly = [
            FMAlertButton("Cancel", role: .cancel),
            FMAlertButton("Delete", role: .destructive)
        ]
        #expect(FMAlertShortcutResolver.cancelButton(in: destructiveOnly)?.title == "Cancel")
        #expect(FMAlertShortcutResolver.returnButton(in: destructiveOnly) == nil)

        let withDefault = [
            FMAlertButton("Cancel", role: .cancel),
            FMAlertButton("Save", role: .default),
            FMAlertButton("Delete", role: .destructive)
        ]
        #expect(FMAlertShortcutResolver.returnButton(in: withDefault)?.title == "Save")
    }

    @Test("FMCommandMatcher.grouped preserves first-seen group ordering")
    func commandPaletteGroupingOrder() {
        let items = [
            FMCommandItem(title: "A", group: "Navigation") {},
            FMCommandItem(title: "B", group: "View") {},
            FMCommandItem(title: "C", group: "Navigation") {},
            FMCommandItem(title: "D", group: "Appearance") {}
        ]
        let groups = FMCommandMatcher.grouped(items)
        #expect(groups.map(\.title) == ["Navigation", "View", "Appearance"])
        #expect(groups[0].items.map(\.title) == ["A", "C"])
        #expect(groups[1].items.map(\.title) == ["B"])
        #expect(groups[2].items.map(\.title) == ["D"])
    }

    @Test("FMTableSelectionMath handles single, Command-toggle, and Shift-range selection")
    func tableSelectionMath() {
        let ids = ["r0", "r1", "r2", "r3", "r4"]

        // Single click
        let s1 = FMTableSelectionMath.updatedSelection(
            current: [],
            orderedIDs: ids,
            clickedID: "r1",
            anchorID: nil,
            allowsMultiple: true,
            isCommandHeld: false,
            isShiftHeld: false
        )
        #expect(s1.selection == ["r1"])
        #expect(s1.newAnchor == "r1")

        // Shift-click range from r1 to r3
        let s2 = FMTableSelectionMath.updatedSelection(
            current: s1.selection,
            orderedIDs: ids,
            clickedID: "r3",
            anchorID: s1.newAnchor,
            allowsMultiple: true,
            isCommandHeld: false,
            isShiftHeld: true
        )
        #expect(s2.selection == ["r1", "r2", "r3"])
        #expect(s2.newAnchor == "r1")

        // Command-click toggle off r2
        let s3 = FMTableSelectionMath.updatedSelection(
            current: s2.selection,
            orderedIDs: ids,
            clickedID: "r2",
            anchorID: s2.newAnchor,
            allowsMultiple: true,
            isCommandHeld: true,
            isShiftHeld: false
        )
        #expect(s3.selection == ["r1", "r3"])
    }

    @Test("FMFileDropValidator filters dropped URLs against allowed UTTypes")
    func fileDropUTTypeValidation() {
        let pngURL = URL(fileURLWithPath: "/tmp/screenshot.png")
        let pdfURL = URL(fileURLWithPath: "/tmp/report.pdf")

        #expect(FMFileDropValidator.matches(url: pngURL, allowedContentTypes: [.image]))
        #expect(!FMFileDropValidator.matches(url: pdfURL, allowedContentTypes: [.image]))
        #expect(FMFileDropValidator.matches(url: pdfURL, allowedContentTypes: [.pdf, .image]))
        #expect(FMFileDropValidator.matches(url: pdfURL, allowedContentTypes: [.item]))
    }

    @Test("FMSwipeBackDisabledPreferenceKey reduces with logical OR")
    func swipeBackPreferenceReduction() {
        var value = FMSwipeBackDisabledPreferenceKey.defaultValue
        #expect(!value)
        FMSwipeBackDisabledPreferenceKey.reduce(value: &value) { false }
        #expect(!value)
        FMSwipeBackDisabledPreferenceKey.reduce(value: &value) { true }
        #expect(value)
        FMSwipeBackDisabledPreferenceKey.reduce(value: &value) { false }
        #expect(value)
    }
}
