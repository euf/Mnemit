import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// What the screens pushed on Today stand on: the decks held open for the stack, the search
/// over all decks, and the Undo of the screens.
@MainActor @Suite(.timeLimit(.minutes(1)))
struct DeckNavigationTests {
    let directory: URL
    let created = Date(timeIntervalSince1970: 1_791_216_000)

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func card(_ question: String, answer: String = "x", note: String? = nil) -> Card {
        Card(question: question, answer: answer, note: note, created: created, learningState: nil)
    }

    @discardableResult
    func writeDeck(_ name: String, cards: [Card] = []) throws -> URL {
        let url = directory.appending(path: "\(name).mnemit", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: url)
        try DeckFile.fileWrapper(for: Deck(cards: cards)).write(to: url, options: .atomic, originalContentsURL: nil)
        return url
    }

    /// Waits until `condition` holds, or fails the test when the suite's time limit is up.
    func wait(_ condition: () -> Bool) async throws {
        while !condition() {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    // MARK: Pushed decks

    @Test func aDeckStaysOpenWhileItsRouteIsOnThePathAndClosesWhenItLeaves() async throws {
        let pushed = PushedDecks()
        let first = pushed.open(try writeDeck("First", cards: [card("dom")]))
        let second = pushed.open(try writeDeck("Second"))
        let deck = try #require(pushed.deck(first))
        try await wait { deck.document != nil && pushed.deck(second)?.document != nil }
        #expect(pushed.openDecks.count == 2)

        await pushed.close(except: [first])
        #expect(pushed.openDecks.map(\.name) == ["First"])
        // The screen that was popped still has its deck until the next push.
        #expect(pushed.deck(second) != nil)

        let third = pushed.open(try writeDeck("Third"))
        #expect(pushed.deck(second) == nil)
        #expect(pushed.deck(third) != nil)

        await pushed.close(except: [])
        #expect(pushed.openDecks.isEmpty)
    }

    @Test func aSlotOpensTheDeckAgainAtItsNewFile() async throws {
        let pushed = PushedDecks()
        let old = try writeDeck("Polish", cards: [card("dom")])
        let slot = pushed.open(old)
        try await wait { pushed.deck(slot)?.document != nil }

        await pushed.close(slot)
        #expect(pushed.openDecks.isEmpty)
        let new = directory.appending(path: "Czech.mnemit", directoryHint: .isDirectory)
        try FileManager.default.moveItem(at: old, to: new)
        pushed.reopen(slot, at: new)

        let deck = try #require(pushed.deck(slot))
        #expect(deck.name == "Czech")
        #expect(pushed.openDecks.count == 1)
        try await wait { deck.document != nil }
        #expect(deck.document?.deck.cards.map(\.question) == ["dom"])
        await pushed.close(except: [])
    }

    /// What a screen changes is saved when its deck closes, so the file has it afterwards.
    @Test func closingTheDeckOfARouteSavesWhatTheScreensChanged() async throws {
        let pushed = PushedDecks()
        let dom = card("dom")
        let url = try writeDeck("Polish", cards: [dom, card("kot")])
        let slot = pushed.open(url)
        let deck = try #require(pushed.deck(slot))
        try await wait { deck.document != nil && deck.isEditable }
        let document = try #require(deck.document)
        document.delete([dom.id])
        // Lets the run loop close the undo group, which the UIDocument counts.
        try await Task.sleep(for: .milliseconds(200))

        await pushed.close(except: [])
        let saved = try DeckFile.decode(FileWrapper(url: url, options: .immediate))
        #expect(saved.cards.map(\.question) == ["kot"])
    }

    // MARK: Search over all decks

    @Test func theSearchFindsCardsOfEveryDeckAndReadsAgainAfterInvalidate() async throws {
        let house = card("το σπίτι", answer: "дом · the house", note: "σπίτι|house")
        let first = KnownDeck(url: try writeDeck("A1", cards: [house, card("ο Άγγλος", answer: "англичанин")]))
        let second = KnownDeck(url: try writeDeck("B1", cards: [card("the house", answer: "το σπίτι")]))
        let search = AllCardsSearch()
        #expect(!search.isLoaded)
        #expect(search.hits(for: "σπιτι").isEmpty)

        await search.load([first, second])
        #expect(search.isLoaded)
        let hits = search.hits(for: "ΣΠΙΤΙ")
        #expect(hits.map(\.deck) == [first, second])
        #expect(hits.map(\.question) == ["το σπίτι", "the house"])
        #expect(hits.first?.card == house.id)
        #expect(search.hits(for: "αγγλος").map(\.answer) == ["англичанин"])
        #expect(search.hits(for: "  ").isEmpty)
        #expect(search.hits(for: "nothing like it").isEmpty)

        // A card changed meanwhile: what was read stays until the screens are left.
        try writeDeck("B1", cards: [card("the flat", answer: "το διαμέρισμα")])
        #expect(search.hits(for: "flat").isEmpty)
        search.invalidate()
        #expect(!search.isLoaded)
        await search.load([first, second])
        #expect(search.hits(for: "flat").map(\.deck) == [second])
    }

    @Test func aDeckThatCantBeReadHasNoHits() async throws {
        let broken = directory.appending(path: "Broken.mnemit", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: broken, withIntermediateDirectories: true)
        let good = KnownDeck(url: try writeDeck("Good", cards: [card("kot")]))
        let search = AllCardsSearch()
        await search.load([KnownDeck(url: broken), good])
        #expect(search.hits(for: "kot").map(\.deck) == [good])
    }

    // MARK: Undo

    @Test func theUndoWatchFollowsWhatTheDocumentCanTakeBack() async throws {
        let kot = card("kot")
        let document = try VocabularyDocument(deck: Deck(cards: [kot, card("pies")]))
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        let watch = UndoWatch(undoManager)
        #expect(!watch.canUndo)

        undoManager.beginUndoGrouping()
        document.delete([kot.id])
        undoManager.endUndoGrouping()
        try await wait { watch.canUndo }
        #expect(watch.actionName == String(localized: "Delete Card"))

        watch.undo()
        #expect(document.deck.cards.map(\.question) == ["kot", "pies"])
        #expect(!watch.canUndo)
    }

    @Test func theUndoWatchOfNoManagerCantUndo() {
        let watch = UndoWatch(nil)
        #expect(!watch.canUndo)
        watch.undo()
        #expect(watch.actionName.isEmpty)
    }
}
