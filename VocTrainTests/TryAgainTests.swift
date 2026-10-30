import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// Try Again on the screens that say a deck could not be opened: the deck is opened anew, as the file may be readable now.
@MainActor @Suite(.timeLimit(.minutes(1)))
struct TryAgainTests {
    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// A deck package that has no deck.json: it can't be read.
    func brokenDeck(_ name: String) throws -> URL {
        let url = directory.appending(path: "\(name).mnemit", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Writes a deck at `url`, over what is there.
    @discardableResult
    func writeDeck(at url: URL) throws -> URL {
        try? FileManager.default.removeItem(at: url)
        try DeckFile.fileWrapper(for: Deck()).write(to: url, options: .atomic, originalContentsURL: nil)
        return url
    }

    func wait(_ condition: () -> Bool) async throws {
        while !condition() {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test func aDeckScreenOpensItsDeckAnewOnTryAgain() async throws {
        let url = try brokenDeck("Broken")
        let pushed = PushedDecks()
        let slot = pushed.open(url)
        try await wait { pushed.deck(slot)?.failure != nil }

        try writeDeck(at: url)
        await pushed.retry(slot)
        let again = try #require(pushed.deck(slot))
        try await wait { again.document != nil }
        #expect(again.failure == nil)
        await pushed.close(except: [])
    }

    @Test func aRunThatCouldNotOpenADeckBeginsAgainOverTheSameDecksOpenedAnew() async throws {
        let broken = try brokenDeck("Broken")
        let fine = try writeDeck(at: directory.appending(path: "Fine.mnemit", directoryHint: .isDirectory))
        let run = StudyRun(deck: OpenDeck(url: broken), entry: .pushOn, upcoming: [fine])
        try await wait { run.deck.failure != nil }

        try writeDeck(at: broken)
        await run.close()
        let again = try #require(run.triedAgain())
        #expect(again !== run)
        #expect(again.decks.map(\.url) == [broken, fine])
        #expect(again.entry == .pushOn)
        try await wait { again.decks.allSatisfy { $0.document != nil } }
        await again.close()
    }

    @Test func aRunOnTheDeckOfAScreenLeavesTryAgainToThatScreen() async throws {
        let deck = OpenDeck(url: try writeDeck(at: directory.appending(path: "Fine.mnemit", directoryHint: .isDirectory)))
        let run = StudyRun(deck: deck, ownsDeck: false)
        #expect(run.triedAgain() == nil)
        await deck.close()
    }
}
