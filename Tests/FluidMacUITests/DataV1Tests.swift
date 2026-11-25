import Foundation
import SwiftUI
import Testing
@testable import FluidMacUI

@Suite("Data Display & Code v1.0 Logic Tests")
struct DataV1Tests {
    // MARK: - FMChartMath Tests

    @Test("Gauge normalization maps values cleanly and handles clamping, degenerate ranges, and non-finite inputs")
    func gaugeNormalization() {
        #expect(abs(FMChartMath.normalized(0.5, in: 0...1) - 0.5) < 0.0001)
        #expect(abs(FMChartMath.normalized(75, in: 50...100) - 0.5) < 0.0001)
        #expect(abs(FMChartMath.normalized(-10, in: -20...20) - 0.25) < 0.0001)

        // Clamping beyond bounds
        #expect(FMChartMath.normalized(-5, in: 0...100) == 0.0)
        #expect(FMChartMath.normalized(150, in: 0...100) == 1.0)

        // Degenerate zero-span range
        #expect(FMChartMath.normalized(10, in: 10...10) == 0.0)
        #expect(FMChartMath.normalized(12, in: 10...10) == 1.0)
        #expect(FMChartMath.normalized(5, in: 10...10) == 0.0)

        // Non-finite inputs
        #expect(FMChartMath.normalized(.nan, in: 0...100) == 0.0)
        #expect(FMChartMath.normalized(.infinity, in: 0...100) == 1.0)
        #expect(FMChartMath.normalized(-.infinity, in: 0...100) == 0.0)
    }

    @Test("Sparkline min/max and point normalization safely handle empty, flat, negative, and mixed arrays")
    func sparklineNormalizationAndMinMax() {
        #expect(FMChartMath.normalizedPoints([]).isEmpty)
        #expect(FMChartMath.minMax([]) == nil)
        #expect(FMChartMath.minMax([.nan, .infinity]) == nil)

        // Single and flat series center at 0.5
        #expect(FMChartMath.normalizedPoints([42]) == [0.5])
        #expect(FMChartMath.normalizedPoints([10, 10, 10]) == [0.5, 0.5, 0.5])

        // Mixed negative to positive
        let series: [Double] = [-20, 0, 20, 60]
        let bounds = FMChartMath.minMax(series)
        #expect(bounds?.min == -20)
        #expect(bounds?.max == 60)

        let normalized = FMChartMath.normalizedPoints(series)
        #expect(normalized.count == 4)
        #expect(abs(normalized[0] - 0.0) < 0.0001)
        #expect(abs(normalized[1] - 0.25) < 0.0001)
        #expect(abs(normalized[2] - 0.5) < 0.0001)
        #expect(abs(normalized[3] - 1.0) < 0.0001)

        // Non-finite handling inside valid series
        let withNonFinite = FMChartMath.normalizedPoints([0, .nan, 10, .infinity, -.infinity])
        #expect(withNonFinite == [0.0, 0.0, 1.0, 1.0, 0.0])
    }

    @Test("Sparkline nearestIndex maps normalized horizontal hover positions accurately")
    func sparklineNearestIndex() {
        #expect(FMChartMath.nearestIndex(forNormalizedX: 0.5, count: 0) == nil)
        #expect(FMChartMath.nearestIndex(forNormalizedX: .nan, count: 5) == nil)
        #expect(FMChartMath.nearestIndex(forNormalizedX: 0.7, count: 1) == 0)

        #expect(FMChartMath.nearestIndex(forNormalizedX: 0.0, count: 5) == 0)
        #expect(FMChartMath.nearestIndex(forNormalizedX: 0.24, count: 5) == 1)
        #expect(FMChartMath.nearestIndex(forNormalizedX: 0.5, count: 5) == 2)
        #expect(FMChartMath.nearestIndex(forNormalizedX: 1.0, count: 5) == 4)

        // Out-of-bounds clamping
        #expect(FMChartMath.nearestIndex(forNormalizedX: -0.4, count: 5) == 0)
        #expect(FMChartMath.nearestIndex(forNormalizedX: 1.8, count: 5) == 4)
    }

    @Test("Sparkline canvas point projection respects insets and flips Y to SwiftUI top-left coordinates")
    func sparklineCanvasPointProjection() {
        let size = CGSize(width: 120, height: 60)

        #expect(FMChartMath.canvasPoints(normalizedValues: [], in: size, inset: 10).isEmpty)

        let single = FMChartMath.canvasPoints(normalizedValues: [0.5], in: size, inset: 10)
        #expect(single.count == 1)
        #expect(abs(single[0].x - 60) < 0.0001)
        #expect(abs(single[0].y - 30) < 0.0001)

        let points = FMChartMath.canvasPoints(normalizedValues: [0.0, 0.5, 1.0], in: size, inset: 10)
        #expect(points.count == 3)
        // x spans 10 -> 60 -> 110; y spans 50 (bottom) -> 30 -> 10 (top)
        #expect(abs(points[0].x - 10) < 0.0001)
        #expect(abs(points[0].y - 50) < 0.0001)
        #expect(abs(points[1].x - 60) < 0.0001)
        #expect(abs(points[1].y - 30) < 0.0001)
        #expect(abs(points[2].x - 110) < 0.0001)
        #expect(abs(points[2].y - 10) < 0.0001)
    }

    // MARK: - FMStepsMath Tests

    @Test("Steps state resolves completed, active, pending, and error precedence accurately")
    func stepsStateResolution() {
        let errors: Set<Int> = [1, 3]

        #expect(FMStepsMath.state(for: 0, currentStep: 2, errorSteps: errors) == .completed)
        #expect(FMStepsMath.state(for: 1, currentStep: 2, errorSteps: errors) == .error)
        #expect(FMStepsMath.state(for: 2, currentStep: 2, errorSteps: errors) == .active)
        #expect(FMStepsMath.state(for: 3, currentStep: 2, errorSteps: errors) == .error)
        #expect(FMStepsMath.state(for: 4, currentStep: 2, errorSteps: errors) == .pending)

        // Error overrides active state too
        #expect(FMStepsMath.state(for: 1, currentStep: 1, errorSteps: errors) == .error)
    }

    @Test("Steps completionRatio, clamping, segment fill, and selection eligibility behave deterministically")
    func stepsMathProgressAndSelection() {
        #expect(FMStepsMath.completionRatio(currentStep: 0, totalSteps: 0) == 0.0)
        #expect(FMStepsMath.completionRatio(currentStep: 0, totalSteps: 1) == 0.0)
        #expect(FMStepsMath.completionRatio(currentStep: 1, totalSteps: 1) == 1.0)

        #expect(FMStepsMath.completionRatio(currentStep: 0, totalSteps: 4) == 0.0)
        #expect(abs(FMStepsMath.completionRatio(currentStep: 1, totalSteps: 4) - (1.0 / 3.0)) < 0.0001)
        #expect(abs(FMStepsMath.completionRatio(currentStep: 2, totalSteps: 4) - (2.0 / 3.0)) < 0.0001)
        #expect(FMStepsMath.completionRatio(currentStep: 3, totalSteps: 4) == 1.0)
        #expect(FMStepsMath.completionRatio(currentStep: 9, totalSteps: 4) == 1.0)
        #expect(FMStepsMath.completionRatio(currentStep: -2, totalSteps: 4) == 0.0)

        #expect(FMStepsMath.clampedStep(-1, totalSteps: 4) == 0)
        #expect(FMStepsMath.clampedStep(2, totalSteps: 4) == 2)
        #expect(FMStepsMath.clampedStep(8, totalSteps: 4) == 3)
        #expect(FMStepsMath.clampedStep(3, totalSteps: 0) == 0)

        #expect(FMStepsMath.segmentFill(at: 0, currentStep: 2) == 1)
        #expect(FMStepsMath.segmentFill(at: 1, currentStep: 2) == 1)
        #expect(FMStepsMath.segmentFill(at: 2, currentStep: 2) == 0)
        #expect(FMStepsMath.segmentFill(at: -1, currentStep: 2) == 0)

        // Selection rules
        #expect(!FMStepsMath.canSelectStep(at: 0, currentStep: 2, errorSteps: [], allowsStepSelection: false))
        #expect(FMStepsMath.canSelectStep(at: 0, currentStep: 2, errorSteps: [], allowsStepSelection: true))
        #expect(!FMStepsMath.canSelectStep(at: 2, currentStep: 2, errorSteps: [], allowsStepSelection: true))
        #expect(!FMStepsMath.canSelectStep(at: 3, currentStep: 2, errorSteps: [], allowsStepSelection: true))
        #expect(FMStepsMath.canSelectStep(at: 3, currentStep: 2, errorSteps: [3], allowsStepSelection: true))
        #expect(!FMStepsMath.canSelectStep(at: -1, currentStep: 2, errorSteps: [], allowsStepSelection: true))
    }

    // MARK: - FMCodeTokenizer Tests

    @Test("Code line splitting normalizes CRLF, CR, and LF while preserving blank lines")
    func codeLineSplitting() {
        #expect(FMCodeTokenizer.splitLines("").isEmpty)
        #expect(FMCodeTokenizer.splitLines("single line") == ["single line"])
        #expect(FMCodeTokenizer.splitLines("a\nb\nc") == ["a", "b", "c"])
        #expect(FMCodeTokenizer.splitLines("a\r\nb\r\nc") == ["a", "b", "c"])
        #expect(FMCodeTokenizer.splitLines("a\rb\rc") == ["a", "b", "c"])
        #expect(FMCodeTokenizer.splitLines("line 1\n\nline 3") == ["line 1", "", "line 3"])
        #expect(FMCodeTokenizer.splitLines("line 1\n") == ["line 1", ""])

        #expect(FMCodeTokenizer.lineNumberColumnWidth(lineCount: 0) == 2)
        #expect(FMCodeTokenizer.lineNumberColumnWidth(lineCount: 9) == 2)
        #expect(FMCodeTokenizer.lineNumberColumnWidth(lineCount: 99) == 2)
        #expect(FMCodeTokenizer.lineNumberColumnWidth(lineCount: 100) == 3)
        #expect(FMCodeTokenizer.lineNumberColumnWidth(lineCount: 1200) == 4)
    }

    @Test("Swift tokenizer classifies keywords, attributes, strings, comments, numbers, and properties losslessly")
    func swiftTokenization() {
        #expect(FMCodeTokenizer.tokenizeLine("", language: .swift).isEmpty)

        let line = #"@State private let count = 42 // "ignored" comment"#
        let tokens = FMCodeTokenizer.tokenizeLine(line, language: .swift)

        #expect(tokens.map(\.text).joined() == line)
        #expect(tokens.contains(FMCodeToken(text: "@State", kind: .keyword)))
        #expect(tokens.contains(FMCodeToken(text: "private", kind: .keyword)))
        #expect(tokens.contains(FMCodeToken(text: "let", kind: .keyword)))
        #expect(tokens.contains(FMCodeToken(text: "42", kind: .number)))
        #expect(tokens.contains(FMCodeToken(text: #"// "ignored" comment"#, kind: .comment)))

        let stringAndProp = #"let label = "Hello \"Mac\"".uppercased /* note */ + 0xFF"#
        let propTokens = FMCodeTokenizer.tokenizeLine(stringAndProp, language: .swift)
        #expect(propTokens.map(\.text).joined() == stringAndProp)
        #expect(propTokens.contains(FMCodeToken(text: #""Hello \"Mac\"""#, kind: .string)))
        #expect(propTokens.contains(FMCodeToken(text: "uppercased", kind: .property)))
        #expect(propTokens.contains(FMCodeToken(text: "/* note */", kind: .comment)))
        #expect(propTokens.contains(FMCodeToken(text: "0xFF", kind: .number)))
    }

    @Test("JSON tokenizer distinguishes property keys from string values and parses literals and numbers losslessly")
    func jsonTokenization() {
        let line = #"  "version": "1.0.0", "enabled": true, "delta": -42.5e+2, "extra": null"#
        let tokens = FMCodeTokenizer.tokenizeLine(line, language: .json)

        #expect(tokens.map(\.text).joined() == line)
        #expect(tokens.contains(FMCodeToken(text: #""version""#, kind: .property)))
        #expect(tokens.contains(FMCodeToken(text: #""1.0.0""#, kind: .string)))
        #expect(tokens.contains(FMCodeToken(text: #""enabled""#, kind: .property)))
        #expect(tokens.contains(FMCodeToken(text: "true", kind: .keyword)))
        #expect(tokens.contains(FMCodeToken(text: "-42.5e+2", kind: .number)))
        #expect(tokens.contains(FMCodeToken(text: "null", kind: .keyword)))
    }

    @Test("Shell tokenizer highlights commands, flags, env vars, strings, and comments losslessly")
    func shellTokenization() {
        let line = #"swift test --filter DataV1Tests "$HOME/app" # run suite"#
        let tokens = FMCodeTokenizer.tokenizeLine(line, language: .shell)

        #expect(tokens.map(\.text).joined() == line)
        #expect(tokens.contains(FMCodeToken(text: "swift", kind: .keyword)))
        #expect(tokens.contains(FMCodeToken(text: "--filter", kind: .property)))
        #expect(tokens.contains(FMCodeToken(text: #""$HOME/app""#, kind: .string)))
        #expect(tokens.contains(FMCodeToken(text: "# run suite", kind: .comment)))

        let envLine = "export PATH=${HOME}/bin 8080"
        let envTokens = FMCodeTokenizer.tokenizeLine(envLine, language: .shell)
        #expect(envTokens.map(\.text).joined() == envLine)
        #expect(envTokens.contains(FMCodeToken(text: "export", kind: .keyword)))
        #expect(envTokens.contains(FMCodeToken(text: "${HOME}", kind: .property)))
        #expect(envTokens.contains(FMCodeToken(text: "8080", kind: .number)))
    }

    @Test("Plain tokenizer preserves text verbatim in a single token")
    func plainTokenization() {
        let line = "struct Foo = 123 # plain"
        let tokens = FMCodeTokenizer.tokenizeLine(line, language: .plain)
        #expect(tokens == [FMCodeToken(text: line, kind: .plain)])
    }

    // MARK: - View Initialization Smoke Tests

    @Test("Batch C views initialize cleanly across all public configurations")
    func batchCViewsSmokeInitialization() {
        _ = FMGauge(value: 0.72, in: 0...1, label: "CPU", style: .arc)
        _ = FMGauge(value: 48, in: 0...100, label: "RAM", valueText: "48 GB", style: .ring, gradient: [FMColor.blue, FMColor.purple])
        _ = FMGauge(value: 0.85, label: "Disk", style: .linearCapacity)
        _ = FMSparkline(values: [12, 18, 15, 29, 24, 38], color: FMColor.green)

        var step = 1
        let binding = Binding(get: { step }, set: { step = $0 })
        let items = [
            FMStepItem(id: "1", title: "Account", subtitle: "Sign in"),
            FMStepItem(id: "2", title: "Workspace", icon: "folder"),
            FMStepItem(id: "3", title: "Deploy")
        ]
        _ = FMStepsIndicator(steps: items, currentStep: binding, errorSteps: [], axis: .horizontal, allowsStepSelection: true)
        _ = FMStepsIndicator(steps: items, currentStep: binding, errorSteps: [2], axis: .vertical, allowsStepSelection: false)

        _ = FMCodeBlock("let x = 1", language: .swift, title: "Example.swift", showsLineNumbers: true, showsCopyButton: true)
        _ = FMCodeBlock("{\"ok\": true}", language: .json, maxHeight: nil)
    }
}
