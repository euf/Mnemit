import Foundation
import Testing

@testable import VocabCore

/// A deleted card keeps its reviews: it moves to `Deck.retiredCards` with its learning state and log, in
/// step with the deck's changes, the merge and the package, and only the ring's done cards, the reviews by
/// day and the refit see it.
struct RetiredCardsTests {
    let calendar = StudyCalendar.testing
    /// 2026-10-05 18:00 in Berlin.
    let start = Date(timeIntervalSince1970: 1_791_216_000)
    let dom = Card(question: "dom", answer: "Haus")
    let kot = Card(question: "kot", answer: "Katze")
    let pies = Card(question: "pies", answer: "Hund")

    func day(_ days: Double) -> Date { start.addingTimeInterval(days * 86400) }

    /// Three cards, "dom" and "pies" reviewed once.
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

    func delete(_ deck: inout Deck, _ id: Card.ID, at date: Date) throws -> DeckChange {
        deck.apply(try #require(DeckChange.removing([id], from: deck)), at: date, calendar: calendar)
    }

    func edit(_ deck: inout Deck, _ id: Card.ID, answer: String, at date: Date) throws {
        let card = deck.card(withID: id)!
        let change = try #require(DeckChange.editingText(of: id, to: CardText(question: card.question, answer: answer)!, in: deck))
        _ = deck.apply(change, at: date, calendar: calendar)
    }

    func merging(_ other: Deck, into deck: Deck, at now: Date) -> Deck {
        var deck = deck
        if let change = DeckChange.merging(other, into: deck, calendar: calendar) {
            _ = deck.apply(change, at: now, calendar: calendar)
        }
        return deck
    }

    // MARK: Apply

    @Test func aDeletedCardWithReviewsIsRetiredWithItsLog() throws {
        var deck = try baseDeck()
        let before = try #require(deck.card(withID: dom.id))
        _ = try delete(&deck, dom.id, at: day(1))

        #expect(deck.cards.map(\.question) == ["kot", "pies"])
        #expect(deck.retiredCards == [before])
        #expect(deck.retiredCards[0].log.count == 1)
        #expect(deck.deletedCards[dom.id] != nil)
    }

    @Test func aDeletedCardWithoutReviewsIsNotRetired() throws {
        var deck = try baseDeck()
        _ = try delete(&deck, kot.id, at: day(1))

        #expect(deck.retiredCards.isEmpty)
        #expect(deck.deletedCards[kot.id] != nil)
    }

    @Test func undoingTheDeletionTakesTheCardOutOfTheRetiredOnes() throws {
        var deck = try baseDeck()
        let original = deck
        let undo = try delete(&deck, dom.id, at: day(1))
        let redo = deck.apply(undo, at: day(1), calendar: calendar)

        #expect(deck.cards.map(\.id) == original.cards.map(\.id))
        #expect(deck.card(withID: dom.id)?.log == original.card(withID: dom.id)?.log)
        #expect(deck.card(withID: dom.id)?.learningState == original.card(withID: dom.id)?.learningState)
        #expect(deck.retiredCards.isEmpty)
        #expect(deck.deletedCards.isEmpty)

        _ = deck.apply(redo, at: day(1), calendar: calendar)
        #expect(deck.retiredCards.map(\.id) == [dom.id])
    }

    // MARK: Package

    @Test func retiredCardsAreWrittenWithTheirReviewsAndReadBack() throws {
        var deck = try baseDeck()
        _ = try delete(&deck, dom.id, at: day(1))
        let package = try DeckFile.fileWrapper(for: deck)

        let json = String(decoding: package.fileWrappers![DeckFile.deckFileName]!.regularFileContents!, as: UTF8.self)
        #expect(json.contains("\"version\" : 6") && json.contains("\"retired\""))
        let lines = String(decoding: package.fileWrappers![DeckFile.reviewsFileName]!.regularFileContents!, as: UTF8.self).split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines.contains { $0.contains(dom.id.uuidString) })

        let read = try DeckFile.decode(package)
        #expect(read.retiredCards == deck.retiredCards)
        #expect(read.cards == deck.cards)
        #expect(read.deletedCards == deck.deletedCards)
    }

    @Test func aDeckWithoutRetiredCardsLeavesTheKeyOut() throws {
        let json = String(decoding: try DeckFile.encodeDeck(try baseDeck()), as: UTF8.self)
        #expect(!json.contains("retired"))
    }

    @Test func theLinesOfARetiredCardWithoutItsRecordBelongToNoCard() throws {
        var deck = try baseDeck()
        _ = try delete(&deck, dom.id, at: day(1))
        let package = try DeckFile.fileWrapper(for: deck)
        let plain = try DeckFile.fileWrapper(for: Deck())
        plain.removeFileWrapper(plain.fileWrappers![DeckFile.reviewsFileName]!)
        plain.addRegularFile(withContents: package.fileWrappers![DeckFile.reviewsFileName]!.regularFileContents!, preferredFilename: DeckFile.reviewsFileName)
        #expect(throws: DeckFile.Error.reviewsOfUnknownCard(line: 1)) { try DeckFile.decode(plain) }
    }

    // MARK: Who sees them

    @Test func aCardDoneTodayStaysDoneAfterItsDeletion() throws {
        var deck = try baseDeck()
        // Goes through the learning steps until FSRS lets the card go to another day.
        var moment = start.addingTimeInterval(300)
        while deck.doneCards(onDayOf: moment, calendar: calendar) == 0, deck.card(withID: dom.id)?.log.count ?? 0 < 6 {
            review(&deck, dom.id, .good, at: moment)
            moment = moment.addingTimeInterval(60)
        }
        let done = deck.doneCards(onDayOf: moment, calendar: calendar)
        let underway = deck.cardsUnderway(onDayOf: moment, calendar: calendar)
        #expect(done >= 1)

        _ = try delete(&deck, dom.id, at: moment)
        #expect(deck.doneCards(onDayOf: moment, calendar: calendar) == done)
        #expect(deck.cardsUnderway(onDayOf: moment, calendar: calendar) == underway)
    }

    @Test func theReviewsOfARetiredCardCountByDayAndTrainTheRefit() throws {
        var deck = try baseDeck()
        let activity = DeckActivity(deck: deck, calendar: calendar)
        _ = try delete(&deck, dom.id, at: day(1))
        let after = DeckActivity(deck: deck, calendar: calendar)

        #expect(after.reviewsByDay == activity.reviewsByDay)
        #expect(deck.trainingCards.map(\.id) == [kot.id, pies.id, dom.id])
        #expect(Set(deck.trainingCards.map(\.id)) == Set([dom.id, kot.id, pies.id]))
    }

    @Test func aRetiredCardIsNoCardOfTheDeck() throws {
        var deck = try baseDeck()
        _ = try delete(&deck, dom.id, at: day(1))

        #expect(deck.card(withID: dom.id) == nil)
        #expect(deck.index(of: dom.id) == nil)
        var without = deck
        without.retiredCards = []
        #expect(StudySession.counts(for: deck, at: day(1), calendar: calendar) == StudySession.counts(for: without, at: day(1), calendar: calendar))
    }

    // MARK: Merge

    /// What a merge settles about the retired cards, by ID.
    func retired(_ deck: Deck) -> [Card.ID: Card] {
        Dictionary(deck.retiredCards.map { ($0.id, $0) }) { first, _ in first }
    }

    @Test func aCardDeletedOnTheOtherDeviceIsRetiredWithTheReviewsOfBoth() throws {
        let base = try baseDeck()
        var mac = base
        _ = try delete(&mac, dom.id, at: day(1))
        var phone = base
        review(&phone, dom.id, .good, at: start.addingTimeInterval(120))

        for merged in [merging(mac, into: phone, at: day(2)), merging(phone, into: mac, at: day(2))] {
            #expect(merged.cards.map(\.question) == ["kot", "pies"])
            #expect(merged.retiredCards.map(\.id) == [dom.id])
            #expect(merged.retiredCards[0].log.count == 2)
            #expect(merged.deletedCards[dom.id] != nil)
        }
        #expect(retired(merging(mac, into: phone, at: day(2))) == retired(merging(phone, into: mac, at: day(2))))
    }

    @Test func aCardStaysWithTheReviewsItsDeletionKept() throws {
        let base = try baseDeck()
        var mac = base
        review(&mac, dom.id, .good, at: start.addingTimeInterval(300))
        _ = try delete(&mac, dom.id, at: day(1))
        var phone = base
        try edit(&phone, dom.id, answer: "Haus, Heim", at: day(2))

        let merged = merging(mac, into: phone, at: day(3))
        let card = try #require(merged.card(withID: dom.id))
        #expect(card.answer == "Haus, Heim")
        #expect(card.log.count == 2)
        #expect(merged.retiredCards.isEmpty)
        #expect(merged.deletedCards[dom.id] == nil)
    }

    @Test func bothDevicesRetireTheirReviewsOfTheSameCardIntoOne() throws {
        let base = try baseDeck()
        var mac = base
        review(&mac, dom.id, .good, at: start.addingTimeInterval(300))
        _ = try delete(&mac, dom.id, at: day(1))
        var phone = base
        review(&phone, dom.id, .again, at: start.addingTimeInterval(400))
        _ = try delete(&phone, dom.id, at: day(1))

        let merged = merging(phone, into: mac, at: day(2))
        #expect(merged.retiredCards.map(\.id) == [dom.id])
        #expect(merged.retiredCards[0].log.count == 3)
        #expect(retired(merged) == retired(merging(mac, into: phone, at: day(2))))
    }

    @Test func aMergeThatTakesNothingNewChangesNothing() throws {
        let base = try baseDeck()
        var mac = base
        _ = try delete(&mac, dom.id, at: day(1))
        let phone = base

        let merged = merging(mac, into: phone, at: day(2))
        #expect(DeckChange.merging(mac, into: merged, calendar: calendar) == nil)
        // The progress aside, which a merge records for its own day.
        let onMac = merging(merged, into: mac, at: day(3))
        #expect(onMac.retiredCards == mac.retiredCards)
        #expect(onMac.cards == mac.cards)
    }

    @Test func undoingAMergeBringsBackTheCardsAndTheRetiredOnes() throws {
        let base = try baseDeck()
        var mac = base
        _ = try delete(&mac, dom.id, at: day(1))
        var phone = base
        let before = phone
        let change = try #require(DeckChange.merging(mac, into: phone, calendar: calendar))
        let inverse = phone.apply(change, at: day(2), calendar: calendar)
        #expect(phone.retiredCards.map(\.id) == [dom.id])

        _ = phone.apply(inverse, at: day(2), calendar: calendar)
        #expect(phone.cards == before.cards)
        #expect(phone.retiredCards.isEmpty)
        #expect(phone.deletedCards == before.deletedCards)
    }

    // MARK: Undoing a review

    /// The change a study session makes of grading the card it asks.
    func grade(_ deck: Deck, at date: Date) throws -> DeckChange {
        var mode = SessionMode.study(StudySession(cardIDs: [dom.id], at: date, random: SeededRandom(seed: 1), reviewMode: .revealed))
        let outcome = mode.grade(.good, in: deck, at: date, calendar: calendar)
        guard case let .rescheduled(change)? = outcome else {
            throw GradeError()
        }
        return change
    }

    struct GradeError: Error {}

    @Test func undoingAReviewTakesBackOnlyTheReviewNotATextThatCameInMeanwhile() throws {
        var deck = try baseDeck()
        let reviewed = try #require(deck.card(withID: dom.id))
        let undo = deck.apply(try grade(deck, at: day(1)), at: day(1), calendar: calendar)
        #expect(deck.card(withID: dom.id)?.log.count == 2)
        // The other device's edit is merged in.
        try edit(&deck, dom.id, answer: "Haus, Heim", at: day(1))

        let redo = deck.apply(undo, at: day(1), calendar: calendar)
        let card = try #require(deck.card(withID: dom.id))
        #expect(card.log == reviewed.log)
        #expect(card.learningState == reviewed.learningState)
        #expect(card.answer == "Haus, Heim")

        _ = deck.apply(redo, at: day(1), calendar: calendar)
        #expect(deck.card(withID: dom.id)?.log.count == 2)
        #expect(deck.card(withID: dom.id)?.answer == "Haus, Heim")
    }

    @Test func undoingAReviewOfACardDeletedMeanwhileBringsNothingBack() throws {
        var deck = try baseDeck()
        let undo = deck.apply(try grade(deck, at: day(1)), at: day(1), calendar: calendar)
        _ = try delete(&deck, dom.id, at: day(1))
        let retired = deck.retiredCards

        _ = deck.apply(undo, at: day(1), calendar: calendar)
        #expect(deck.card(withID: dom.id) == nil)
        #expect(deck.cards.map(\.question) == ["kot", "pies"])
        #expect(deck.retiredCards == retired)
        #expect(deck.deletedCards[dom.id] != nil)
    }
}
