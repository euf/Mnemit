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
        let url = directory.appending(path: "Polish.mnemit", directoryHint: .isDirectory)
        try DeckFile.fileWrapper(for: Deck(learningOptions: options, cards: cards)).write(to: url, options: .atomic, originalContentsURL: nil)

        let counts = try #require(KnownDeckCounts.counts(at: url))
        #expect(counts.new == 2)
        #expect(counts.total == 2)
    }

    /// The row on Today and the header of the deck screen are one plan: the daily limit on
    /// new cards loses the cards introduced today, which only the review log knows.
    @Test func theRowSubtractsTheCardsIntroducedTodayAsTheDeckScreenDoes() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        var options = LearningOptions()
        options.newCardsPerSession = 3
        let now = Date()
        // Two cards first reviewed just now, waiting for their next step, and five never studied.
        let introduced = ["a", "b"].map { question in
            let state = LearningState(phase: .learning, stability: 1, difficulty: 5, lastReview: now, due: now.addingTimeInterval(600), reviews: 1)
            return Card(
                question: question, answer: "x", created: now, learningState: state,
                log: [ReviewLogEntry(date: now, grade: .good)])
        }
        let fresh = (0..<5).map { Card(text: CardText(question: "n\($0)", answer: "x")!, created: now) }
        let deck = try Deck(learningOptions: options, cards: introduced + fresh)
        let url = directory.appending(path: "Greek.mnemit", directoryHint: .isDirectory)
        try DeckFile.fileWrapper(for: deck).write(to: url, options: .atomic, originalContentsURL: nil)

        let row = try #require(KnownDeckCounts.counts(at: url))
        let screen = StudySession.counts(for: try DeckFile.decode(FileWrapper(url: url, options: .immediate)), at: Date(), calendar: StudyCalendar())
        #expect(row.new == 1)
        #expect(row == screen)
    }

    @Test func aDeckThatCannotBeReadHasNoCounts() {
        let missing = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).mnemit", directoryHint: .isDirectory)
        #expect(KnownDeckCounts.counts(at: missing) == nil)
    }
}
