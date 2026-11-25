import Testing
@testable import FluidMacUI

@Suite("Control Logic & Math Tests")
struct ControlLogicTests {
    @Test("Slider math computes normalized progress and clamps out-of-bounds values")
    func sliderProgressCalculation() {
        #expect(FMSliderMath.progress(value: 50, in: 0...100) == 0.5)
        #expect(FMSliderMath.progress(value: -20, in: 0...100) == 0.0)
        #expect(FMSliderMath.progress(value: 180, in: 0...100) == 1.0)
        #expect(FMSliderMath.progress(value: 15, in: 10...20) == 0.5)
    }

    @Test("Slider math snaps accurately to configured steps within bounds")
    func sliderStepSnapping() {
        let snapped = FMSliderMath.value(forProgress: 0.37, in: 0...100, step: 10)
        #expect(snapped == 40)

        let lowerClamped = FMSliderMath.value(forProgress: -0.5, in: 10...50, step: 5)
        #expect(lowerClamped == 10)

        let upperClamped = FMSliderMath.value(forProgress: 1.4, in: 10...50, step: 5)
        #expect(upperClamped == 50)
    }

    @Test("Stepper math enforces lower and upper closed bounds")
    func stepperClamping() {
        #expect(FMStepperMath.stepped(from: 5, delta: 2, in: 0...10) == 7)
        #expect(FMStepperMath.stepped(from: 9, delta: 5, in: 0...10) == 10)
        #expect(FMStepperMath.stepped(from: 1, delta: -5, in: 0...10) == 0)
    }
}
