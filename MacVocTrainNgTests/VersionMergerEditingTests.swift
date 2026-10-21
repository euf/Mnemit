import Foundation
import Testing

@testable import MacVocTrain
@testable import VocabCore

/// What the `VersionMerger` does when both devices edit cards, not only study them: the
/// edit made here on the document, the other device's version in conflict or read again.
/// The rules themselves are tested in `DeckMergeEditingTests` of VocabCore.
@MainActor
struct VersionMergerEditingTests {
    let url = URL(fileURLWithPath: "/Users/learner/Library/Mobile Documents/com~apple~CloudDocs/Polish.mnemit")
    /// 2026-10-05 18:00 in Berlin.
    let start = Date(timeIntervalSince1970: 1_791_216_000)
    let dom: Card
    let kot: Card
    let pies: Card
    let base: Deck
    let store = FakeVersionStore()
    /// The document's clock: its edits are made at day 5.
    let clock: ManualClock
    private let undoManagers = Keeper()

    init() throws {
        let dom = Card(question: "dom", answer: "Haus")
        let kot = Card(question: "kot", answer: "Katze")
        let pies = Card(question: "pies", answer: "Hund")
        self.dom = dom
        self.kot = kot
        self.pies = pies
        base = try Deck(cards: [dom, kot, pies])
        clock = ManualClock(start.addingTimeInterval(5 * 86400))
    }

    func day(_ days: Double) -> Date {
        start.addingTimeInterval(days * 86400)
    }

    func makeMerger() -> VersionMerger {
        VersionMerger(saveDelay: .seconds(3600), checkDelay: .zero) { [store] _, onChange in
            store.onChange = onChange
            return store
        }
    }

    func open(_ deck: Deck) -> (VocabularyDocument, UndoManager) {
        let document = VocabularyDocument(deck: deck, clock: clock.studyClock, calendar: .testing)
        let undoManager = makeUndoManager(for: document)
        undoManagers.all.append(undoManager)
        return (document, undoManager)
    }

    /// The other device's version: `base` with what `changes` does to it, at the times it does it.
    func otherDevice(_ changes: (inout Deck) throws -> Void) rethrows -> Deck {
        var deck = base
        try changes(&deck)
        return deck
    }

    func apply(_ change: DeckChange?, to deck: inout Deck, at date: Date) {
        _ = deck.apply(change!, at: date, calendar: .testing)
    }

    func edit(_ id: Card.ID, answer: String, in deck: Deck) -> DeckChange? {
        let card = deck.card(withID: id)!
        return DeckChange.editingText(of: id, to: CardText(question: card.question, answer: answer)!, in: deck)
    }

    func review(_ id: Card.ID, in deck: inout Deck, at date: Date) {
        let scheduler = Scheduler(learningOptions: deck.learningOptions, calendar: .testing)
        var random = Scheduler.random(forReviewOf: id, at: date)
        let reviewed = scheduler.review(deck.card(withID: id)!, grade: .good, at: date, mode: .revealed, using: &random)
        _ = deck.apply(DeckChange(upserts: [reviewed], contentStamp: .keep), at: date, calendar: .testing)
    }

    /// Merges `version` as a version in conflict into `document` and returns the merger.
    @discardableResult
    func mergeConflict(_ version: Deck, into document: VocabularyDocument) async -> VersionMerger {
        let conflict = FakeConflict(deck: version, store: store)
        store.conflicts = [conflict]
        let merger = makeMerger()
        merger.attach(document, fileURL: url, isEditable: true)
        await merger.merging?.value
        #expect(conflict.isResolved)
        return merger
    }

    // MARK: (a) A card added on each device

    @Test func aCardAddedHereAndOneThereAreBothKept() async throws {
        let (document, undoManager) = open(base)
        step(undoManager) { document.add(CardText(question: "ryba", answer: "Fisch")!) }
        let other = try otherDevice { deck in
            apply(DeckChange.adding([Card(question: "mysz", answer: "Maus", created: day(3))], to: deck), to: &deck, at: day(3))
        }

        await mergeConflict(other, into: document)
        #expect(Set(document.deck.cards.map(\.question)) == ["dom", "kot", "pies", "ryba", "mysz"])
        #expect(Array(store.events.prefix(2)) == ["save", "resolve"])

        // Undo takes back the merge only: the card added here stays.
        undoManager.undo()
        #expect(document.deck.cards.map(\.question) == ["dom", "kot", "pies", "ryba"])
    }

    // MARK: (b) Edited here, studied there

    @Test func anEditHereAndAReviewThereAreBothKept() async throws {
        let (document, undoManager) = open(base)
        step(undoManager) { document.editText(of: dom.id, to: CardText(question: "dom", answer: "Haus / Heim")!) }
        let other = try otherDevice { deck in
            review(dom.id, in: &deck, at: day(3))
            review(dom.id, in: &deck, at: day(4))
        }

        await mergeConflict(other, into: document)
        let card = try #require(document.deck.card(withID: dom.id))
        #expect(card.answer == "Haus / Heim")
        #expect(card.log.count == 2)
    }

    // MARK: (c) Edited on both

    @Test func theLaterEditWinsWhicheverDeviceMadeIt() async throws {
        // The other device edited before this document did: the document's text stays.
        let (document, undoManager) = open(base)
        step(undoManager) { document.editText(of: dom.id, to: CardText(question: "dom", answer: "Heim")!) }
        let earlier = try otherDevice { deck in apply(edit(dom.id, answer: "Gebäude", in: deck), to: &deck, at: day(3)) }
        await mergeConflict(earlier, into: document)
        #expect(document.deck.card(withID: dom.id)?.answer == "Heim")

        // After: the other device's text comes.
        let (second, secondUndo) = open(base)
        step(secondUndo) { second.editText(of: dom.id, to: CardText(question: "dom", answer: "Heim")!) }
        let later = try otherDevice { deck in apply(edit(dom.id, answer: "Gebäude", in: deck), to: &deck, at: day(7)) }
        await mergeConflict(later, into: second)
        #expect(second.deck.card(withID: dom.id)?.answer == "Gebäude")
        #expect(second.deck.card(withID: dom.id)?.contentChanged == day(7))
    }

    // MARK: (d) Deleted on one device

    /// Deleted after the last thing done to the card here: it goes.
    @Test func aCardDeletedThereAfterItsLastChangeHereIsDeleted() async throws {
        let (document, undoManager) = open(base)
        step(undoManager) { document.setSuspended(true, of: [pies.id]) }
        let other = try otherDevice { deck in apply(DeckChange.removing([pies.id], from: deck), to: &deck, at: day(6)) }

        await mergeConflict(other, into: document)
        #expect(document.deck.cards.map(\.question) == ["dom", "kot"])
        #expect(document.deck.deletedCards == [pies.id: day(6)])

        undoManager.undo()
        #expect(document.deck.cards.map(\.question) == ["dom", "kot", "pies"])
        #expect(document.deck.deletedCards.isEmpty)
    }

    /// Changed here after the deletion: the card stays, with its reviews. The worst outcome
    /// is losing review history.
    @Test func aCardChangedHereAfterItsDeletionThereStays() async throws {
        let (document, undoManager) = open(base)
        step(undoManager) { document.editText(of: pies.id, to: CardText(question: "pies", answer: "Hund / Köter")!) }
        let other = try otherDevice { deck in
            review(pies.id, in: &deck, at: day(1))
            apply(DeckChange.removing([pies.id], from: deck), to: &deck, at: day(4))
        }

        await mergeConflict(other, into: document)
        #expect(document.deck.card(withID: pies.id)?.answer == "Hund / Köter")
        #expect(document.deck.deletedCards.isEmpty)
    }

    // MARK: (e) Learning options

    @Test func changedOptionsHereSurviveAnEditThere() async throws {
        let (document, undoManager) = open(base)
        var options = document.deck.learningOptions
        options.steps = 3
        step(undoManager) { document.updateLearningOptions(options) }
        let other = try otherDevice { deck in
            apply(edit(kot.id, answer: "Kater", in: deck), to: &deck, at: day(7))
            apply(DeckChange.adding([Card(question: "mysz", answer: "Maus", created: day(7))], to: deck), to: &deck, at: day(7))
        }

        await mergeConflict(other, into: document)
        #expect(document.deck.learningOptions.steps == 3)
        #expect(document.deck.card(withID: kot.id)?.answer == "Kater")
        #expect(document.deck.cards.count == 4)
    }

    // MARK: The iPhone reads the file again

    /// The iPhone keeps its document and merges the deck it read (#303), edits included.
    @Test func aDeckReadAgainWithEditsIsMergedIntoTheDocument() async throws {
        let (document, undoManager) = open(base)
        step(undoManager) { document.add(CardText(question: "ryba", answer: "Fisch")!) }
        step(undoManager) { document.delete([kot.id]) }
        let other = try otherDevice { deck in
            apply(edit(dom.id, answer: "Haus / Heim", in: deck), to: &deck, at: day(3))
            apply(DeckChange.adding([Card(question: "mysz", answer: "Maus", created: day(3))], to: deck), to: &deck, at: day(3))
            // Studied on day 4, before the document deleted it on day 5: the deletion wins.
            review(kot.id, in: &deck, at: day(4))
        }
        let merger = makeMerger()
        let mergesReadAgain = ReadAgainCounter()
        merger.didMergeReadAgain = { mergesReadAgain.count += 1 }
        merger.attach(document, fileURL: url, isEditable: true)
        await merger.merging?.value

        merger.merge(readAgain: other)
        await merger.merging?.value
        #expect(Set(document.deck.cards.map(\.question)) == ["dom", "pies", "ryba", "mysz"])
        #expect(document.deck.card(withID: dom.id)?.answer == "Haus / Heim")
        #expect(mergesReadAgain.count == 1)
        #expect(store.events == ["save"])
    }
}

/// Keeps undo managers for as long as a test runs.
@MainActor
private final class Keeper {
    var all: [UndoManager] = []
}

@MainActor
private final class ReadAgainCounter {
    var count = 0
}
