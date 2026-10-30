import Foundation
import Testing

@testable import VocTrain

/// What the sheets of a deck's name make of what the creating or renaming does.
@MainActor @Suite(.timeLimit(.minutes(1)))
struct DeckNameSheetTests {
    @Test func aFailureBecomesTheMessageUnderTheField() async {
        var received: [String] = []
        let message = await DeckNameSheet.attempt("Greek B1") { name in
            received.append(name)
            throw DeckFiles.Failure.nameTaken("Greek B1")
        }
        #expect(received == ["Greek B1"])
        #expect(message == DeckFiles.Failure.nameTaken("Greek B1").errorDescription)
        #expect(message?.contains("Greek B1") == true)

        let invalid = await DeckNameSheet.attempt("a/b") { _ in throw DeckFiles.Failure.invalidName }
        #expect(invalid == DeckFiles.Failure.invalidName.errorDescription)
    }

    @Test func theActionStaysOffWhileTheFieldShowsAnError() {
        let taken = DeckNameSheet(
            title: "New Deck", actionTitle: "Create", current: nil, prefill: "Greek B1", failure: "A deck named “Greek B1” already exists.",
            perform: { _ in })
        #expect(!taken.canSubmit)
        let fresh = DeckNameSheet(title: "New Deck", actionTitle: "Create", current: nil, prefill: "Greek B1", perform: { _ in })
        #expect(fresh.canSubmit)
    }

    @Test func successLeavesNoMessage() async {
        var received: [String] = []
        let message = await DeckNameSheet.attempt("Greek B2") { received.append($0) }
        #expect(received == ["Greek B2"])
        #expect(message == nil)
    }
}
