import Foundation
import Testing

@testable import VocabCore

/// Merging two versions of a deck when both devices edit cards, not only study them:
/// what each device did survives, and no review is ever lost.
struct DeckMergeEditingTests {
    let calendar = StudyCalendar.testing
    /// 2026-10-05 18:00 in Berlin.
    let start = Date(timeIntervalSince1970: 1_791_216_000)
    let dom = Card(question: "dom", answer: "Haus")
    let kot = Card(question: "kot", answer: "Katze")
    let pies = Card(question: "pies", answer: "Hund")

    func day(_ days: Double) -> Date {
        start.addingTimeInterval(days * 86400)
    }

    /// The deck both devices start from: three cards, "dom" and "pies" reviewed.
    func baseDeck() throws -> Deck {
        var options = LearningOptions()
        options.fuzzing = false
        var deck = try Deck(learningOptions: options, cards: [])
        _ = deck.apply(try #require(DeckChange.adding([dom, kot, pies], to: deck)), at: start, calendar: calendar)
        review(&deck, dom.id, .good, at: start.addingTimeInterval(60))
        review(&deck, pies.id, .hard, at: start.addingTimeInterval(180))
        return deck
    }

    func review(_ deck: inout Deck, _ id: Card.ID, _ grade: Grade, at date: Date) {
        let card = deck.card(withID: id)!
        var random = SeededRandom(seed: 1)
        let reviewed = Scheduler(learningOptions: deck.learningOptions, calendar: calendar).review(card, grade: grade, at: date, mode: .revealed, using: &random)
        _ = deck.apply(DeckChange(upserts: [reviewed], contentStamp: .keep), at: date, calendar: calendar)
    }

    func edit(_ deck: inout Deck, _ id: Card.ID, answer: String, at date: Date) throws {
        let card = deck.card(withID: id)!
        let change = try #require(DeckChange.editingText(of: id, to: CardText(question: card.question, answer: answer)!, in: deck))
        _ = deck.apply(change, at: date, calendar: calendar)
    }

    func delete(_ deck: inout Deck, _ id: Card.ID, at date: Date) throws {
        _ = deck.apply(try #require(DeckChange.removing([id], from: deck)), at: date, calendar: calendar)
    }

    func add(_ deck: inout Deck, _ card: Card, at date: Date) throws {
        _ = deck.apply(try #require(DeckChange.adding([card], to: deck)), at: date, calendar: calendar)
    }

    func merging(_ other: Deck, into deck: Deck, at now: Date) -> Deck {
        var deck = deck
        if let change = DeckChange.merging(other, into: deck, calendar: calendar) {
            _ = deck.apply(change, at: now, calendar: calendar)
        }
        return deck
    }

    /// What a merge settles. The progress is left out: applying a merge records the
    /// snapshot of its day, which a device that had nothing to take in doesn't. So is the
    /// order of the cards: a merge puts cards it takes in at their place in the order of
    /// the version with the later content, but leaves the others where they are.
    struct State: Equatable {
        var cards: [Card]
        var learningOptions: LearningOptions
        var deletedCards: [Card.ID: Date]
        var contentModified: Date?
        var learningOptionsChanged: Date?

        init(_ deck: Deck) {
            cards = deck.cards.sorted { $0.id.uuidString < $1.id.uuidString }
            learningOptions = deck.learningOptions
            deletedCards = deck.deletedCards
            contentModified = deck.contentModified
            learningOptionsChanged = deck.learningOptionsChanged
        }
    }

    /// Both devices end up with the same state, and merging again changes nothing.
    func expectConverged(_ mac: Deck, _ phone: Deck, at now: Date, sourceLocation: SourceLocation = #_sourceLocation) -> Deck {
        let onMac = merging(phone, into: mac, at: now)
        let onPhone = merging(mac, into: phone, at: now)
        #expect(State(onMac) == State(onPhone), sourceLocation: sourceLocation)
        #expect(State(merging(onPhone, into: onMac, at: now)) == State(onMac), sourceLocation: sourceLocation)
        #expect(State(merging(onMac, into: onPhone, at: now)) == State(onPhone), sourceLocation: sourceLocation)
        return onMac
    }

    // MARK: (a) Cards added on both devices

    @Test func aCardAddedOnEachDeviceIsKept() throws {
        var mac = try baseDeck()
        try add(&mac, Card(question: "mysz", answer: "Maus", created: day(2)), at: day(2))
        var phone = try baseDeck()
        try add(&phone, Card(question: "ryba", answer: "Fisch", created: day(3)), at: day(3))

        let merged = expectConverged(mac, phone, at: day(4))
        #expect(merged.cards.map(\.question).sorted() == ["dom", "kot", "mysz", "pies", "ryba"])
        // The cards of the version with the later content first, as every version sees them.
        #expect(merged.cards.map(\.question) == ["dom", "kot", "pies", "ryba", "mysz"])
        #expect(merged.deletedCards.isEmpty)
    }

    @Test func cardsAddedOnOneDeviceInTheMiddleOfTheListKeepTheirPlace() throws {
        let mac = try baseDeck()
        var phone = mac
        let mysz = Card(question: "mysz", answer: "Maus", created: day(2))
        _ = phone.apply(DeckChange(upserts: [mysz]), at: day(2), calendar: calendar)
        // Several cards at once, as an import does, and each of them is new for the Mac.
        let more = [Card(question: "ryba", answer: "Fisch", created: day(3)), Card(question: "ptak", answer: "Vogel", created: day(3))]
        try add(&phone, more[0], at: day(3))
        try add(&phone, more[1], at: day(3))

        let merged = merging(phone, into: mac, at: day(4))
        #expect(merged.cards.map(\.question) == ["dom", "kot", "pies", "mysz", "ryba", "ptak"])
        #expect(merged.cards.dropFirst(3).allSatisfy { $0.isNew })
    }

    // MARK: (b) Edited on one device, graded on the other

    @Test func anEditAndAReviewOfTheSameCardAreBothKept() throws {
        var mac = try baseDeck()
        try edit(&mac, dom.id, answer: "Haus / Heim", at: day(2))
        var phone = try baseDeck()
        review(&phone, dom.id, .good, at: day(3))
        review(&phone, dom.id, .good, at: day(4))

        let merged = expectConverged(mac, phone, at: day(5))
        let card = try #require(merged.card(withID: dom.id))
        #expect(card.answer == "Haus / Heim")
        #expect(card.log.count == 3)
        #expect(card.learningState?.lastReview == day(4))
        #expect(card.hasCompleteLog)
    }

    @Test func aReviewAfterTheEditOfTheOtherDeviceDoesNotTakeTheEditBack() throws {
        var mac = try baseDeck()
        var phone = try baseDeck()
        // The phone's version has the later `contentModified`, from an edit of another card.
        try edit(&phone, kot.id, answer: "Kater", at: day(1))
        try edit(&mac, dom.id, answer: "Haus / Heim", at: day(2))
        review(&phone, dom.id, .good, at: day(5))

        let merged = expectConverged(mac, phone, at: day(6))
        #expect(merged.card(withID: dom.id)?.answer == "Haus / Heim")
        #expect(merged.card(withID: dom.id)?.log.count == 2)
        #expect(merged.card(withID: kot.id)?.answer == "Kater")
    }

    // MARK: (c) The same card edited on both devices

    @Test func theLaterEditOfACardWins() throws {
        var mac = try baseDeck()
        try edit(&mac, dom.id, answer: "Haus / Heim", at: day(2))
        var phone = try baseDeck()
        try edit(&phone, dom.id, answer: "Haus / Gebäude", at: day(3))

        #expect(expectConverged(mac, phone, at: day(4)).card(withID: dom.id)?.answer == "Haus / Gebäude")
        // The other way round.
        #expect(expectConverged(phone, mac, at: day(4)).card(withID: dom.id)?.answer == "Haus / Gebäude")
    }

    /// Each card goes by its own stamp, not by which version changed something last.
    @Test func eachCardTakesItsLatestEditWhateverVersionChangedLast() throws {
        var mac = try baseDeck()
        try edit(&mac, dom.id, answer: "Haus / Heim", at: day(3))
        try edit(&mac, kot.id, answer: "Kater", at: day(1))
        var phone = try baseDeck()
        try edit(&phone, dom.id, answer: "Gebäude", at: day(2))
        try edit(&phone, kot.id, answer: "Kätzchen", at: day(4))

        let merged = expectConverged(mac, phone, at: day(5))
        #expect(merged.card(withID: dom.id)?.answer == "Haus / Heim")
        #expect(merged.card(withID: kot.id)?.answer == "Kätzchen")
        #expect(merged.card(withID: dom.id)?.contentChanged == day(3))
    }

    @Test func undoingAnEditIsALaterEdit() throws {
        var mac = try baseDeck()
        try edit(&mac, dom.id, answer: "Haus / Heim", at: day(2))
        // The phone has taken in the edit; then the Mac undoes it.
        let phone = merging(mac, into: try baseDeck(), at: day(2))
        var undone = mac
        let undo = try #require(DeckChange.editingText(of: dom.id, to: CardText(question: "dom", answer: "Haus")!, in: undone))
        _ = undone.apply(undo, at: day(3), calendar: calendar)

        #expect(merging(undone, into: phone, at: day(4)).card(withID: dom.id)?.answer == "Haus")
        #expect(merging(phone, into: undone, at: day(4)).card(withID: dom.id)?.answer == "Haus")
    }

    @Test func noteAndKindFollowTheirCardsLastEdit() throws {
        var mac = try baseDeck()
        _ = mac.apply(try #require(DeckChange.settingNote("dom", kind: .recognition, of: dom.id, in: mac)), at: day(2), calendar: calendar)
        var phone = try baseDeck()
        _ = phone.apply(try #require(DeckChange.settingNote("dom2", kind: .production, of: dom.id, in: phone)), at: day(3), calendar: calendar)

        let card = try #require(expectConverged(mac, phone, at: day(4)).card(withID: dom.id))
        #expect((card.note, card.kind) == ("dom2", .production))
    }

    // MARK: (d) Deleted on one device, changed on the other

    @Test func aCardDeletedOnOneDeviceAndLeftAloneOnTheOtherIsDeleted() throws {
        var mac = try baseDeck()
        try delete(&mac, pies.id, at: day(3))
        let phone = try baseDeck()

        let merged = expectConverged(mac, phone, at: day(4))
        #expect(merged.cards.map(\.question) == ["dom", "kot"])
        #expect(merged.deletedCards == [pies.id: day(3)])
    }

    @Test func aReviewBeforeTheDeletionDoesNotKeepTheCard() throws {
        var mac = try baseDeck()
        try delete(&mac, pies.id, at: day(3))
        var phone = try baseDeck()
        review(&phone, pies.id, .good, at: day(2))

        #expect(expectConverged(mac, phone, at: day(4)).cards.map(\.question) == ["dom", "kot"])
    }

    /// Losing review history is the worst outcome: a review after the deletion keeps the
    /// card, with all its reviews.
    @Test func aReviewAfterTheDeletionKeepsTheCardAndItsReviews() throws {
        var mac = try baseDeck()
        try delete(&mac, pies.id, at: day(3))
        var phone = try baseDeck()
        review(&phone, pies.id, .good, at: day(4))

        let merged = expectConverged(mac, phone, at: day(5))
        let card = try #require(merged.card(withID: pies.id))
        #expect(card.log.map(\.grade) == [.hard, .good])
        #expect(merged.cards.count == 3)
        #expect(merged.deletedCards.isEmpty)
    }

    @Test func anEditAfterTheDeletionKeepsTheCard() throws {
        var mac = try baseDeck()
        try delete(&mac, pies.id, at: day(3))
        var phone = try baseDeck()
        try edit(&phone, pies.id, answer: "Hund / Köter", at: day(4))

        let merged = expectConverged(mac, phone, at: day(5))
        #expect(merged.card(withID: pies.id)?.answer == "Hund / Köter")
        #expect(merged.card(withID: pies.id)?.log.count == 1)
    }

    @Test func aSuspensionAfterTheDeletionKeepsTheCard() throws {
        var mac = try baseDeck()
        try delete(&mac, pies.id, at: day(3))
        var phone = try baseDeck()
        _ = phone.apply(try #require(DeckChange.settingSuspended(true, of: [pies.id], in: phone, at: day(4))), at: day(4), calendar: calendar)

        let merged = expectConverged(mac, phone, at: day(5))
        #expect(merged.card(withID: pies.id)?.isSuspended == true)
    }

    @Test func aChangeAtTheSecondOfTheDeletionKeepsTheCard() throws {
        var mac = try baseDeck()
        try delete(&mac, pies.id, at: day(3))
        var phone = try baseDeck()
        review(&phone, pies.id, .good, at: day(3))

        #expect(expectConverged(mac, phone, at: day(4)).card(withID: pies.id)?.log.count == 2)
    }

    /// A card deleted on both devices stays deleted, with the later time.
    @Test func aCardDeletedOnBothDevicesStaysDeleted() throws {
        var mac = try baseDeck()
        try delete(&mac, pies.id, at: day(2))
        var phone = try baseDeck()
        try delete(&phone, pies.id, at: day(3))

        let merged = expectConverged(mac, phone, at: day(4))
        #expect(merged.cards.map(\.question) == ["dom", "kot"])
        #expect(merged.deletedCards == [pies.id: day(3)])
    }

    /// The Mac undoes a deletion after the iPhone took it in: the card comes back.
    @Test func undoingADeletionBringsTheCardBackOnTheOtherDevice() throws {
        var mac = try baseDeck()
        let undo = mac.apply(try #require(DeckChange.removing([pies.id], from: mac)), at: day(3), calendar: calendar)
        let phone = merging(mac, into: try baseDeck(), at: day(3))
        #expect(phone.cards.map(\.question) == ["dom", "kot"])
        _ = mac.apply(undo, at: day(4), calendar: calendar)
        #expect(mac.cards.map(\.question) == ["dom", "kot", "pies"])
        #expect(mac.deletedCards.isEmpty)

        let merged = expectConverged(mac, phone, at: day(5))
        #expect(merged.cards.map(\.question) == ["dom", "kot", "pies"])
        #expect(merged.card(withID: pies.id)?.log.count == 1)
    }

    @Test func deletionsAreNotedAndTakenBackWithTheirCards() throws {
        var deck = try baseDeck()
        let undo = deck.apply(try #require(DeckChange.removing([pies.id, kot.id], from: deck)), at: day(1).addingTimeInterval(0.5), calendar: calendar)
        #expect(deck.deletedCards == [pies.id: day(1), kot.id: day(1)])

        let redo = deck.apply(undo, at: day(2), calendar: calendar)
        #expect(deck.deletedCards.isEmpty)
        // The cards are back, later than their removal.
        #expect(deck.cards.map(\.contentChanged) == [nil, day(2), day(2)])
        _ = deck.apply(redo, at: day(3), calendar: calendar)
        #expect(deck.deletedCards == [pies.id: day(3), kot.id: day(3)])
    }

    @Test func aCardAddedAgainIsNoLongerDeleted() throws {
        var deck = try baseDeck()
        try delete(&deck, pies.id, at: day(1))
        try add(&deck, Card(id: pies.id, question: "pies", answer: "Hund", created: day(2)), at: day(2))
        #expect(deck.deletedCards.isEmpty)
    }

    // MARK: (e) Learning options

    @Test func changedLearningOptionsSurviveEditsOnTheOtherDevice() throws {
        var mac = try baseDeck()
        var options = mac.learningOptions
        options.steps = 3
        _ = mac.apply(try #require(DeckChange.changingLearningOptions(options, in: mac, calendar: calendar)), at: day(2), calendar: calendar)
        var phone = try baseDeck()
        try edit(&phone, dom.id, answer: "Haus / Heim", at: day(3))
        try add(&phone, Card(question: "mysz", answer: "Maus", created: day(3)), at: day(3))

        let merged = expectConverged(mac, phone, at: day(4))
        #expect(merged.learningOptions.steps == 3)
        #expect(merged.learningOptionsChanged == day(2))
        #expect(merged.card(withID: dom.id)?.answer == "Haus / Heim")
        #expect(merged.cards.count == 4)
    }

    @Test func changedLearningOptionsSurviveReviewsOnTheOtherDevice() throws {
        var mac = try baseDeck()
        var options = mac.learningOptions
        options.targetRecall = 0.8
        _ = mac.apply(try #require(DeckChange.changingLearningOptions(options, in: mac, calendar: calendar)), at: day(2), calendar: calendar)
        var phone = try baseDeck()
        review(&phone, kot.id, .good, at: day(3))

        let merged = expectConverged(mac, phone, at: day(4))
        #expect(merged.learningOptions.targetRecall == 0.8)
        #expect(merged.card(withID: kot.id)?.log.count == 1)
    }

    @Test func theLaterChangeOfTheLearningOptionsWins() throws {
        var mac = try baseDeck()
        var macOptions = mac.learningOptions
        macOptions.steps = 3
        _ = mac.apply(try #require(DeckChange.changingLearningOptions(macOptions, in: mac, calendar: calendar)), at: day(3), calendar: calendar)
        var phone = try baseDeck()
        var phoneOptions = phone.learningOptions
        phoneOptions.steps = 4
        _ = phone.apply(try #require(DeckChange.changingLearningOptions(phoneOptions, in: phone, calendar: calendar)), at: day(2), calendar: calendar)
        // An edit after the change of the options doesn't make the options newer.
        try edit(&phone, dom.id, answer: "Haus / Heim", at: day(4))

        let merged = expectConverged(mac, phone, at: day(5))
        #expect(merged.learningOptions.steps == 3)
        #expect(merged.card(withID: dom.id)?.answer == "Haus / Heim")
    }

    /// Pausing and resuming travel with the options, so the later of the two changes wins whichever
    /// device made it, and reviews on the other device don't undo it.
    @Test func theLaterPauseOrResumeWins() throws {
        func setPaused(_ isPaused: Bool, in deck: inout Deck, at date: Date) throws {
            var options = deck.learningOptions
            options.isPaused = isPaused
            _ = deck.apply(try #require(DeckChange.changingLearningOptions(options, in: deck, calendar: calendar)), at: date, calendar: calendar)
        }
        var mac = try baseDeck()
        try setPaused(true, in: &mac, at: day(3))
        var phone = try baseDeck()
        try setPaused(true, in: &phone, at: day(1))
        try setPaused(false, in: &phone, at: day(2))
        review(&phone, kot.id, .good, at: day(4))
        // The pause on the Mac is the later change: the deck is paused on both.
        #expect(expectConverged(mac, phone, at: day(5)).learningOptions.isPaused)

        // Paused on the phone too, and resumed there after the pause on the Mac.
        var resumed = try baseDeck()
        try setPaused(true, in: &resumed, at: day(1))
        review(&resumed, kot.id, .good, at: day(4))
        try setPaused(false, in: &resumed, at: day(6))
        let merged = expectConverged(mac, resumed, at: day(7))
        #expect(!merged.learningOptions.isPaused)
        #expect(merged.card(withID: kot.id)?.log.count == 1)
    }

    @Test func undoingAMergeRestoresTheDeletedCardsToo() throws {
        var mac = try baseDeck()
        try delete(&mac, pies.id, at: day(3))
        try add(&mac, Card(question: "mysz", answer: "Maus", created: day(3)), at: day(3))
        var phone = try baseDeck()
        try add(&phone, Card(question: "ryba", answer: "Fisch", created: day(2)), at: day(2))

        var merged = phone
        let change = try #require(DeckChange.merging(mac, into: merged, calendar: calendar))
        let undo = merged.apply(change, at: day(4), calendar: calendar)
        #expect(merged.deletedCards == [pies.id: day(3)])
        #expect(merged.cards.map(\.question) == ["dom", "kot", "mysz", "ryba"])

        let redo = merged.apply(undo, at: day(4), calendar: calendar)
        #expect(State(merged) == State(phone))
        // Taking back the merge notes no deletion, so a card of the other device stays.
        #expect(merged.deletedCards.isEmpty)
        _ = merged.apply(redo, at: day(4), calendar: calendar)
        #expect(merged.deletedCards == [pies.id: day(3)])
    }

    // MARK: Stamps

    @Test func onlyAChangeOfContentStampsTheCard() throws {
        var deck = try baseDeck()
        try edit(&deck, dom.id, answer: "Haus / Heim", at: day(1).addingTimeInterval(0.5))
        #expect(deck.card(withID: dom.id)?.contentChanged == day(1))
        #expect(deck.card(withID: kot.id)?.contentChanged == nil)

        _ = deck.apply(try #require(DeckChange.resettingLearningState(of: [pies.id], in: deck, at: day(2))), at: day(2), calendar: calendar)
        _ = deck.apply(try #require(DeckChange.settingSuspended(true, of: [kot.id], in: deck, at: day(2))), at: day(2), calendar: calendar)
        review(&deck, dom.id, .good, at: day(2))
        #expect(deck.cards.map(\.contentChanged) == [day(1), nil, nil])

        // The same text again changes nothing.
        #expect(DeckChange.editingText(of: dom.id, to: CardText(question: "dom", answer: "Haus / Heim")!, in: deck) == nil)
    }

    @Test func undoingAnEditStampsTheCardAgain() throws {
        var deck = try baseDeck()
        let change = try #require(DeckChange.editingText(of: dom.id, to: CardText(question: "dom", answer: "Heim")!, in: deck))
        let undo = deck.apply(change, at: day(1), calendar: calendar)
        let redo = deck.apply(undo, at: day(2), calendar: calendar)
        #expect(deck.card(withID: dom.id)?.answer == "Haus")
        #expect(deck.card(withID: dom.id)?.contentChanged == day(2))
        _ = deck.apply(redo, at: day(3), calendar: calendar)
        #expect(deck.card(withID: dom.id)?.contentChanged == day(3))
    }

    @Test func theOptionsAreStampedWithTheChange() throws {
        var deck = try baseDeck()
        #expect(deck.learningOptionsChanged == nil)
        var options = deck.learningOptions
        options.steps = 3
        let undo = deck.apply(try #require(DeckChange.changingLearningOptions(options, in: deck, calendar: calendar)), at: day(1).addingTimeInterval(0.5), calendar: calendar)
        #expect(deck.learningOptionsChanged == day(1))
        _ = deck.apply(undo, at: day(2), calendar: calendar)
        #expect(deck.learningOptionsChanged == day(2))
        // A card edit doesn't touch the stamp of the options.
        try edit(&deck, dom.id, answer: "Heim", at: day(3))
        #expect(deck.learningOptionsChanged == day(2))
    }

    // MARK: Random edits on two devices

    /// Whatever the devices did, in whatever order they merge: they end up with the same
    /// deck, merging again changes nothing, and no review of a card that stays is lost.
    @Test(arguments: (1...200).map { UInt64($0) }) func randomEditsOnTwoDevicesMergeWithoutLosingReviews(seed: UInt64) throws {
        var random = SeededRandom(seed: seed)
        let base = try baseDeck()
        var decks = [base, base]
        var seconds = 100.0
        var counter = 0
        for _ in 0..<40 {
            let device = Int.random(in: 0...1, using: &random)
            seconds += Double(Int.random(in: 1...600, using: &random))
            let now = start.addingTimeInterval(seconds)
            let cards = decks[device].cards
            // Without cards there is only something to add.
            switch cards.isEmpty ? 0 : Int.random(in: 0..<7, using: &random) {
            case 0:
                counter += 1
                try add(&decks[device], Card(question: "n\(counter)", answer: "x", created: now), at: now)
            case 1:
                counter += 1
                try edit(&decks[device], cards.randomElement(using: &random)!.id, answer: "e\(counter)", at: now)
            case 2:
                try delete(&decks[device], cards.randomElement(using: &random)!.id, at: now)
            case 3, 4:
                review(&decks[device], cards.randomElement(using: &random)!.id, [.again, .hard, .good, .easy].randomElement(using: &random)!, at: now)
            case 5:
                let card = cards.randomElement(using: &random)!
                if let change = DeckChange.settingSuspended(!card.isSuspended, of: [card.id], in: decks[device], at: now) {
                    _ = decks[device].apply(change, at: now, calendar: calendar)
                }
            default:
                var options = decks[device].learningOptions
                options.steps = Int.random(in: 1...5, using: &random)
                if let change = DeckChange.changingLearningOptions(options, in: decks[device], calendar: calendar) {
                    _ = decks[device].apply(change, at: now, calendar: calendar)
                }
            }
        }

        let now = start.addingTimeInterval(seconds + 1000)
        let merged = expectConverged(decks[0], decks[1], at: now)
        let mergedIDs = Set(merged.cards.map(\.id))
        for deck in decks {
            for card in deck.cards {
                if mergedIDs.contains(card.id) {
                    let kept = try #require(merged.card(withID: card.id))
                    let reviews = Set(kept.log.map { Int($0.date.timeIntervalSince1970) })
                    #expect(card.log.allSatisfy { reviews.contains(Int($0.date.timeIntervalSince1970)) }, "seed \(seed): reviews of \(card.question)")
                } else {
                    // Dropped only for a deletion later than everything done to the card.
                    let other = decks.first { $0 != deck } ?? deck
                    let deletion = try #require(other.deletedCards[card.id], "seed \(seed): \(card.question) left without a deletion")
                    #expect(deletion > card.lastChange, "seed \(seed): \(card.question) deleted before its last change")
                }
            }
        }
    }
}
