import Testing
import SwiftUI
@testable import FluidMacUI

@Suite("Theme, Density & Spring Engine Tests")
struct ThemeAndDensityTests {
    @Test("Density metrics scale monotonically from compact to comfortable")
    func densityMonotonicScale() {
        #expect(FMDensity.compact.controlHeight < FMDensity.regular.controlHeight)
        #expect(FMDensity.regular.controlHeight < FMDensity.comfortable.controlHeight)

        #expect(FMDensity.compact.rowMinHeight < FMDensity.regular.rowMinHeight)
        #expect(FMDensity.regular.rowMinHeight < FMDensity.comfortable.rowMinHeight)

        #expect(FMDensity.compact.toggleSize.width < FMDensity.regular.toggleSize.width)
        #expect(FMDensity.regular.toggleSize.width < FMDensity.comfortable.toggleSize.width)

        #expect(FMDensity.compact.iconBadgeSize < FMDensity.regular.iconBadgeSize)
        #expect(FMDensity.regular.iconBadgeSize < FMDensity.comfortable.iconBadgeSize)
    }

    @Test("Theme clamps animationSpeed within safe bounds")
    func themeAnimationSpeedClamping() {
        let tooSlow = FMTheme(animationSpeed: 0.001)
        let tooFast = FMTheme(animationSpeed: 100.0)
        let normal = FMTheme(animationSpeed: 0.5)

        #expect(tooSlow.animationSpeed == 0.1)
        #expect(tooFast.animationSpeed == 3.0)
        #expect(normal.animationSpeed == 0.5)
    }

    @Test("Spring levels have distinct calibrated response and damping values")
    func springCalibration() {
        #expect(FMSpringLevel.interactive.response < FMSpringLevel.micro.response)
        #expect(FMSpringLevel.micro.response < FMSpringLevel.navigation.response)
        #expect(FMSpringLevel.navigation.response < FMSpringLevel.modal.response)

        // Reduced motion returns valid animations without crashing
        let reduced = FMSpring.animation(.modal, reduceMotion: true, speed: 1.0)
        let normal = FMSpring.animation(.modal, reduceMotion: false, speed: 1.0)
        #expect(reduced != normal)
    }

    @Test("Adaptive accent desaturates cleanly when window is inactive")
    func adaptiveAccentInactiveWindow() {
        let active = FMColor.adaptiveAccent(FMColor.blue, activeState: .active, scheme: .dark)
        let inactive = FMColor.adaptiveAccent(FMColor.blue, activeState: .inactive, scheme: .dark)
        #expect(active == FMColor.blue)
        #expect(inactive != FMColor.blue)
    }
}
