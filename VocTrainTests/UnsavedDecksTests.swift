import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// A deck that can't save when its screen lets go of it stays open with its changes: the run, the pushed screens and
/// the registry keep it, and a file under it is not moved. `merger.saves.hasFailed` stands for the failed save.
@MainActor @Suite(.serialized, .timeLimit(.minutes(2)))
struct UnsavedDecksTests {
    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func deckFile(_ name: String = "Polish") throws -> URL {
        let url = directory.appending(path: "\(name).mnemit", directoryHint: .isDirectory)
        let card = Card(text: CardText(question: "dom", answer: "x")!, created: .now.addingTimeInterval(-60))
        try DeckFile.fileWrapper(for: Deck(cards: [card])).write(to: url, options: .atomic, originalContentsURL: nil)
        return url
    }

    /// A deck that is open and whose save failed.
    private func failingDeck(_ url: URL) async throws -> OpenDeck {
        let deck = OpenDeck(url: url)
        try await waitUntil("the deck is open and can be changed") { deck.document != nil && deck.isEditable }
        deck.merger.saves.hasFailed = true
        return deck
    }

    @Test func aDeckThatCantSaveIsKeptByTheRegistryUntilItHas() async throws {
        let deck = try await failingDeck(deckFile())

        #expect(await UnsavedDecks.close(deck) == false)
        #expect(UnsavedDecks.decks.contains { $0 === deck })
        #expect(deck.merger.failure != nil)

        deck.merger.saves.hasFailed = false
        await UnsavedDecks.retry()
        #expect(!UnsavedDecks.decks.contains { $0 === deck })
    }

    @Test func aRunThatCantSaveItsDeckKeepsIt() async throws {
        let deck = try await failingDeck(deckFile())
        let run = StudyRun(deck: deck)

        #expect(await run.close() == false)
        #expect(UnsavedDecks.decks.contains { $0 === deck })

        deck.merger.saves.hasFailed = false
        await UnsavedDecks.retry()
    }

    @Test func aRunThatSavedItsDeckKeepsNothing() async throws {
        let deck = OpenDeck(url: try deckFile())
        try await waitUntil("the deck is open and can be changed") { deck.document != nil && deck.isEditable }
        let run = StudyRun(deck: deck)

        #expect(await run.close())
        #expect(!UnsavedDecks.decks.contains { $0 === deck })
    }

    @Test func aPushedDeckThatCantSaveStaysOpenInItsSlot() async throws {
        let url = try deckFile()
        let pushed = PushedDecks()
        let slot = pushed.open(url)
        let deck = try #require(pushed.deck(slot))
        try await waitUntil("the deck is open and can be changed") { deck.document != nil && deck.isEditable }
        deck.merger.saves.hasFailed = true

        #expect(await pushed.close(slot) == false)
        #expect(pushed.openDecks.contains { $0 === deck })

        deck.merger.saves.hasFailed = false
        #expect(await pushed.close(slot))
        #expect(pushed.openDecks.isEmpty)
    }

    /// The text the learner reads when a rename or a delete is refused.
    @Test func theRefusalToMoveAnUnsavedDeckSaysWhy() {
        #expect(DeckFiles.Failure.unsaved.errorDescription == VersionMerger.saveFailure)
    }
}
