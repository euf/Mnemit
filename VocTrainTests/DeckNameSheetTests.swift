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

    @Test func successLeavesNoMessage() async {
        var received: [String] = []
        let message = await DeckNameSheet.attempt("Greek B2") { received.append($0) }
        #expect(received == ["Greek B2"])
        #expect(message == nil)
    }
}
