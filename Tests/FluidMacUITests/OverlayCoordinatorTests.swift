import Testing
@testable import FluidMacUI

@Suite("Window-Scoped Overlay Coordinator Tests")
struct OverlayCoordinatorTests {
    @Test("HUD items present immediately when idle and queue FIFO when busy")
    func hudQueueingAndAdvancement() {
        let coordinator = FMOverlayCoordinator()
        #expect(coordinator.activeHUD == nil)
        #expect(coordinator.hudQueue.isEmpty)

        coordinator.show(title: "First", style: .info, duration: nil, hapticsEnabled: false)
        coordinator.show(title: "Second", style: .success, duration: nil, hapticsEnabled: false)
        coordinator.show(title: "Third", style: .warning, duration: nil, hapticsEnabled: false)

        #expect(coordinator.activeHUD?.title == "First")
        #expect(coordinator.hudQueue.count == 2)

        coordinator.dismissCurrent()
        #expect(coordinator.activeHUD?.title == "Second")
        #expect(coordinator.hudQueue.count == 1)

        coordinator.dismissAll()
        #expect(coordinator.activeHUD == nil)
        #expect(coordinator.hudQueue.isEmpty)
    }

    @Test("Loading HUD morphs seamlessly in place when updated or replaced by completion state")
    func hudLoadingMorph() {
        let coordinator = FMOverlayCoordinator()
        let id = coordinator.show(title: "Optimizing...", style: .loading, hapticsEnabled: false)
        #expect(coordinator.activeHUD?.style == .loading)

        coordinator.update(
            id: id,
            title: "Freed 2.4 GB",
            style: .success,
            duration: nil,
            hapticsEnabled: false
        )
        #expect(coordinator.activeHUD?.id == id)
        #expect(coordinator.activeHUD?.style == .success)
        #expect(coordinator.activeHUD?.title == "Freed 2.4 GB")
        #expect(coordinator.hudQueue.isEmpty)
    }

    @Test("Two windows own strictly isolated overlay coordinators")
    func multiWindowIsolation() {
        let windowA = FMOverlayCoordinator()
        let windowB = FMOverlayCoordinator()

        windowA.show(title: "Window A Notice", style: .success, duration: nil, hapticsEnabled: false)
        windowA.activeSheetCount = 1

        #expect(windowA.activeHUD?.title == "Window A Notice")
        #expect(windowB.activeHUD == nil)
        #expect(windowA.activeSheetCount == 1)
        #expect(windowB.activeSheetCount == 0)
    }
}
