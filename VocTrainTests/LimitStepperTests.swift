import Foundation
import Testing
import VocabCore

@testable import VocTrain

/// The one stepper of a limit that ends in Unlimited, and the mark a new deck starts with.
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

    @Test func aNewDeckStartsWithItsMark() {
        #expect(Deck.new(introducesNewCards: true).learningOptions.introducesNewCards)
        #expect(!Deck.new(introducesNewCards: false).learningOptions.introducesNewCards)
        #expect(Deck.new(introducesNewCards: true).cards.isEmpty)
    }

    @Test func aDeckFileMadeForNewWordsKeepsTheMark() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let marked = try await DeckFiles.create(named: "Marked", introducesNewCards: true, in: folder)
        let plain = try await DeckFiles.create(named: "Plain", in: folder)
        let read = { (url: URL) throws -> Deck in try DeckFile.decode(try FileWrapper(url: url)) }
        #expect(try read(marked).learningOptions.introducesNewCards)
        #expect(try !read(plain).learningOptions.introducesNewCards)
    }
}
