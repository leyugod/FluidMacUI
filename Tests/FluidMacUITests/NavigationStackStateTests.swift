import Testing
import SwiftUI
@testable import FluidMacUI

@Suite("Navigation Stack State Machine Tests")
struct NavigationStackStateTests {
    @Test("Push, pop, pop(count:), and popToRoot maintain stack integrity")
    func stackTransitions() {
        let nav = FMNavigationController()
        #expect(nav.depth == 0)
        #expect(!nav.canPop)
        #expect(nav.topTitle == nil)

        nav.push(title: "Step 1") { Text("1") }
        nav.push(title: "Step 2") { Text("2") }
        nav.push(title: "Step 3") { Text("3") }

        #expect(nav.depth == 3)
        #expect(nav.canPop)
        #expect(nav.topTitle == "Step 3")

        let popped = nav.pop()
        #expect(popped?.title == "Step 3")
        #expect(nav.depth == 2)
        #expect(nav.topTitle == "Step 2")

        nav.replaceTop(title: "Step 2B") { Text("2B") }
        #expect(nav.depth == 2)
        #expect(nav.topTitle == "Step 2B")

        nav.popToRoot()
        #expect(nav.depth == 0)
        #expect(!nav.canPop)

        // Popping on an empty stack is a safe no-op
        #expect(nav.pop() == nil)
    }

    @Test("pop(count:) safely clamps counts larger than stack depth")
    func popCountClamping() {
        let nav = FMNavigationController()
        nav.push(title: "A") { EmptyView() }
        nav.push(title: "B") { EmptyView() }

        nav.pop(count: 10)
        #expect(nav.depth == 0)
    }

    @Test("Swipe-back threshold honors both distance ratio and high-velocity flicks")
    func swipeBackCommitThresholds() {
        // Below threshold and slow
        #expect(!FMNavigationController.shouldCommitSwipeBack(translation: 80, velocity: 100, containerWidth: 800))
        // Exceeds 28% width threshold
        #expect(FMNavigationController.shouldCommitSwipeBack(translation: 240, velocity: 10, containerWidth: 800))
        // Short distance but high flick velocity
        #expect(FMNavigationController.shouldCommitSwipeBack(translation: 70, velocity: 450, containerWidth: 800))
    }
}
