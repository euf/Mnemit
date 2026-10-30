import Foundation
import Testing
import VocabCore

@testable import VocTrain

/// The menus of the deck's numbers: the presets, and a value off them kept in its place.
@MainActor @Suite(.timeLimit(.minutes(1)))
struct LimitMenuTests {
    @Test func aValueOnTheMenuLeavesItAsItIs() {
        let presets: [Int?] = [nil, 0, 5, 10]
        #expect(LimitMenu.menu(presets, keeping: 5, unsetLast: false) == presets)
        #expect(LimitMenu.menu(presets, keeping: nil, unsetLast: false) == presets)
        #expect(LimitMenu.menu(presets, keeping: 0, unsetLast: false) == presets)
    }

    @Test func aValueOffTheMenuTakesItsNumericPlace() {
        #expect(LimitMenu.menu([nil, 0, 5, 10], keeping: 7, unsetLast: false) == [nil, 0, 5, 7, 10])
        #expect(LimitMenu.menu([nil, 0, 5, 10], keeping: 250, unsetLast: false) == [nil, 0, 5, 10, 250])
        // No limit, last, stays last: a number above every preset goes before it.
        #expect(LimitMenu.menu([50, 100, nil], keeping: 120, unsetLast: true) == [50, 100, 120, nil])
        #expect(LimitMenu.menu([50, 100, nil], keeping: 9999, unsetLast: true) == [50, 100, 9999, nil])
        #expect(LimitMenu.menu([50, 100, nil], keeping: 10, unsetLast: true) == [10, 50, 100, nil])
        // Auto, first, stays first.
        #expect(LimitMenu.menu([nil, 0, 5], keeping: 3, unsetLast: false) == [nil, 0, 3, 5])
    }
}
