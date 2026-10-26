import Foundation
import Testing
import VocabCore

@testable import VocTrain

/// The one stepper of a limit that ends in Unlimited.
@MainActor @Suite(.timeLimit(.minutes(1)))
struct LimitStepperTests {
    @Test func plusPastTheCeilingIsUnlimitedAndMinusComesBackToIt() {
        var value: Int? = 90
        value = LimitStepper.raised(value, step: 5, ceiling: 100)
        #expect(value == 95)
        value = LimitStepper.raised(value, step: 5, ceiling: 100)
        #expect(value == 100)
        value = LimitStepper.raised(value, step: 5, ceiling: 100)
        #expect(value == nil)
        #expect(LimitStepper.raised(value, step: 5, ceiling: 100) == nil)
        value = LimitStepper.lowered(value, step: 5, ceiling: 100, lowerBound: 1)
        #expect(value == 100)
    }

    @Test func minusStopsAtTheLowerBoundAndAValueAboveTheCeilingStepsDown() {
        #expect(LimitStepper.lowered(3, step: 5, ceiling: 100, lowerBound: 1) == 1)
        #expect(LimitStepper.lowered(0, step: 1, ceiling: 30, lowerBound: 0) == 0)
        #expect(LimitStepper.lowered(250, step: 5, ceiling: 100, lowerBound: 1) == 245)
        #expect(LimitStepper.raised(250, step: 5, ceiling: 100) == nil)
    }
}
