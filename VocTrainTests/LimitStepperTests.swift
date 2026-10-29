import Foundation
import Testing
import VocabCore

@testable import VocTrain

/// The one stepper of a limit that begins at Unlimited.
@MainActor @Suite(.timeLimit(.minutes(1)))
struct LimitStepperTests {
    @Test func plusFromUnlimitedGivesOneStepAndStopsAtTheCeiling() {
        var value: Int? = nil
        value = LimitStepper.raised(value, step: 5, ceiling: 100)
        #expect(value == 5)
        #expect(LimitStepper.raised(90, step: 5, ceiling: 100) == 95)
        #expect(LimitStepper.raised(95, step: 5, ceiling: 100) == 100)
        #expect(LimitStepper.raised(100, step: 5, ceiling: 100) == 100)
        #expect(LimitStepper.raised(98, step: 5, ceiling: 100) == 100)
        #expect(LimitStepper.raised(nil, step: 1, ceiling: 30) == 1)
        #expect(LimitStepper.raised(250, step: 5, ceiling: 100) == 100)
    }

    @Test func minusStopsAtTheLowerBoundAndComesBackToUnlimitedFromIt() {
        #expect(LimitStepper.lowered(nil, step: 5, lowerBound: 1) == nil)
        #expect(LimitStepper.lowered(1, step: 5, lowerBound: 1) == nil)
        #expect(LimitStepper.lowered(3, step: 5, lowerBound: 1) == 1)
        #expect(LimitStepper.lowered(6, step: 5, lowerBound: 1) == 1)
        #expect(LimitStepper.lowered(100, step: 5, lowerBound: 1) == 95)
        #expect(LimitStepper.lowered(0, step: 1, lowerBound: 0) == nil)
        // A value above the ceiling, as a file may have it, steps down.
        #expect(LimitStepper.lowered(250, step: 5, lowerBound: 1) == 245)
    }
}
