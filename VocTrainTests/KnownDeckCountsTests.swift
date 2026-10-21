import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// What the start screen shows beside each known deck.
struct KnownDeckCountsTests {
    @Test func countsAreReadFromTheFileAsASessionWouldTakeThem() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        var options = LearningOptions()
        options.newCardsPerSession = 2
        let cards = ["dom", "kot", "pies"].map { Card(text: CardText(question: $0, answer: "x")!, created: Date()) }
        let url = directory.appending(path: "Polish.voctrain", directoryHint: .isDirectory)
        try DeckFile.fileWrapper(for: Deck(learningOptions: options, cards: cards)).write(to: url, options: .atomic, originalContentsURL: nil)

        let counts = try #require(KnownDeckCounts.counts(at: url))
        #expect(counts.new == 2)
        #expect(counts.total == 2)
    }

    @Test func aDeckThatCannotBeReadHasNoCounts() {
        let missing = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).voctrain", directoryHint: .isDirectory)
        #expect(KnownDeckCounts.counts(at: missing) == nil)
    }
}
