import Foundation
import Testing

@testable import MacVocTrain
@testable import VocabCore

extension DeckFileTests {
    /// Try Again on the Mac's pages that say a deck could not be opened: the deck is opened anew, as the file may be readable
    /// now.
    @MainActor @Suite(.timeLimit(.minutes(3)))
    struct TryAgainMacTests {
        /// A deck package that has no deck.json: it can't be read.
        func breakDeck(at url: URL) throws {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }

        func repairDeck(at url: URL) throws {
            try FileManager.default.removeItem(at: url)
            try ShellFixture.write(cards: 3, to: url)
        }

        @Test func aDeckPageOpensItsDeckAnewOnTryAgain() async throws {
            let f = try ShellFixture()
            let url = f.url("Broken")
            try breakDeck(at: url)
            let broken = f.shell.deck(for: url)
            try await f.waitFor("the deck failed") { broken.failure != nil }

            try repairDeck(at: url)
            await f.shell.reopenDeck(url)
            let again = try #require(f.shell.decks.deck(for: url))
            #expect(again !== broken)
            try await f.waitFor("the deck is open") { again.document != nil && again.isEditable }
            await f.finish()
        }

        @Test func theStreamsScreenBeginsTheRunAgainOnTryAgain() async throws {
            let f = try ShellFixture()
            let url = f.url("Broken")
            try breakDeck(at: url)
            f.shell.study(.deck(url))
            try await f.waitFor("the run failed") { f.shell.runFailure != nil }
            #expect(f.shell.session == nil)

            try repairDeck(at: url)
            await f.shell.retryStudy()
            try await f.waitFor("the stream is up") { f.shell.session != nil }
            #expect(f.shell.runFailure == nil)
            f.shell.endStudy()
            await f.finish()
        }
    }
}
