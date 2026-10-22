import Foundation
import Testing
import VocabCore

@testable import MacVocTrain

/// The Mac side of the Anki import: the preview of a package, built here from notes, as the
/// sandbox of the test host can't read the fixtures of VocabCore (the iPhone's tests read them),
/// and the requests that make a new deck's window start the import.
@MainActor
struct AnkiImportMacTests {
    let calendar = StudyCalendar.testing
    let created = Date(timeIntervalSince1970: 1_791_216_000)

    @Test func aPackageIsRecognisedByItsExtension() {
        #expect(URL(fileURLWithPath: "/Downloads/Greek.apkg").isAnkiPackage)
        #expect(URL(fileURLWithPath: "/Downloads/GREEK.APKG").isAnkiPackage)
        #expect(!URL(fileURLWithPath: "/Downloads/Greek.mnemit", isDirectory: true).isAnkiPackage)
        #expect(!URL(fileURLWithPath: "/Downloads/words.tsv").isAnkiPackage)
    }

    @Test func thePreviewCountsTheCardsTheirHistoryAndWhatWasLeftOut() {
        let review = ReviewLogEntry(date: created, grade: .good, mode: .revealed)
        let package = AnkiImport(
            notes: [
                .init(front: "γάτα", back: "cat", reviews: [review]),
                .init(front: "σκύλος", back: "dog", isSuspended: true),
                .init(front: "γάτα", back: "kitty"),
            ],
            skippedCloze: 2, skippedMediaRefs: 3, skippedEmpty: 1, deckNames: ["Greek::Lesson 1"])
        let existing = [Card(question: "σκύλος", answer: "hound")]
        let made = CardImport.ankiCandidates(of: package, existing: existing, learningOptions: LearningOptions(), calendar: calendar, created: created)
        #expect(made.candidates.map(\.card.question) == ["γάτα", "σκύλος", "γάτα"])
        #expect(made.candidates.map(\.duplicate) == [nil, .inDeck, .inFile(question: "γάτα", answer: "cat")])
        #expect(made.summary == CardImport.AnkiSummary(deckNames: ["Greek::Lesson 1"], withHistory: 1, skippedCloze: 2, skippedMediaRefs: 3, skippedEmpty: 1))
        #expect(made.summary.lines.count == 4)

        let preview = CardImport.Preview(fileName: "greek.apkg", candidates: made.candidates, skippedRows: 0, anki: made.summary)
        #expect(preview.selectedCards.map(\.answer) == ["cat"])
    }

    /// A note whose text the rules of a card leave out is counted with the empty ones.
    @Test func aNoteThatMakesNoCardIsCountedAsEmpty() {
        let package = AnkiImport(notes: [.init(front: "  ", back: "x"), .init(front: "a", back: "b")], skippedEmpty: 1)
        let made = CardImport.ankiCandidates(of: package, existing: [], learningOptions: LearningOptions(), calendar: calendar, created: created)
        #expect(made.candidates.count == 1)
        #expect(made.summary.skippedEmpty == 2)
    }

    @Test func requestsFromTheWelcomeWindowAreTakenInOrderAndOnce() {
        while WelcomeRequest.takeImportCards() != nil {}
        let package = URL(fileURLWithPath: "/Downloads/Greek.apkg")
        WelcomeRequest.requestImportCards()
        WelcomeRequest.requestImportCards(from: package)
        #expect(WelcomeRequest.takeImportCards()?.file == nil)
        #expect(WelcomeRequest.takeImportCards()?.file == package)
        #expect(WelcomeRequest.takeImportCards() == nil)
    }
}
