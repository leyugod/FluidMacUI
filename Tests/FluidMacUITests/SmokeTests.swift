import Testing
@testable import FluidMacUI

@Suite("FluidMacUI Smoke Tests")
struct SmokeTests {
    @Test("Package version is defined")
    func versionDefined() {
        #expect(!FluidMacUI.version.isEmpty)
    }
}
