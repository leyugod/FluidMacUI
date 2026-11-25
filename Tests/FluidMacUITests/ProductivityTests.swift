import Testing
import SwiftUI
@testable import FluidMacUI

@Suite("Productivity & Editorial Logic Tests")
struct ProductivityTests {
    @Test("Command palette matcher filters by title, subtitle, group, and keywords")
    func commandPaletteFiltering() {
        let commands = [
            FMCommandItem(title: "Open Inspector", subtitle: "Toggle right drawer", group: "View", keywords: ["panel", "debug"]) {},
            FMCommandItem(title: "Clear Cache", subtitle: "Delete derived data", group: "System", keywords: ["clean", "xcode"]) {},
            FMCommandItem(title: "Switch Theme", group: "Appearance", keywords: ["dark", "glass"]) {}
        ]

        #expect(FMCommandMatcher.filter(commands, query: "").count == 3)
        #expect(FMCommandMatcher.filter(commands, query: "inspector").map(\.title) == ["Open Inspector"])
        #expect(FMCommandMatcher.filter(commands, query: "xcode").map(\.title) == ["Clear Cache"])
        #expect(FMCommandMatcher.filter(commands, query: "appearance").map(\.title) == ["Switch Theme"])
        #expect(FMCommandMatcher.filter(commands, query: "nonexistent").isEmpty)
    }

    @Test("Token field math trims whitespace and prevents case-insensitive duplicates")
    func tokenNormalizationAndDeduplication() {
        let initial = ["SwiftUI", "macOS 26"]
        #expect(FMTokenMath.appendToken("   ", to: initial) == initial)
        #expect(FMTokenMath.appendToken("swiftui", to: initial) == initial)
        #expect(FMTokenMath.appendToken("  Liquid Glass  ", to: initial) == ["SwiftUI", "macOS 26", "Liquid Glass"])
    }

    @Test("Sort direction toggles cleanly between ascending and descending")
    func sortDirectionToggle() {
        var dir: FMSortDirection = .ascending
        dir.toggle()
        #expect(dir == .descending)
        dir.toggle()
        #expect(dir == .ascending)
    }
}
