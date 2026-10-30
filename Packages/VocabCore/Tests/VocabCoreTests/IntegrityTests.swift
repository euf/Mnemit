import Foundation
import Testing

@testable import VocabCore

/// Integrity of the review history across undo, merge and the files (audit B, Mnemit 10.1.2).
struct IntegrityTests {
    let calendar = StudyCalendar.testing
    let start = Date(timeIntervalSince1970: 1_791_216_000)
    let dom = Card(question: "dom", answer: "Haus")
    let kot = Card(question: "kot", answer: "Katze")

    func day(_ days: Double) -> Date { start.addingTimeInterval(days * 86400) }

    func baseDeck() throws -> Deck {
        var options = LearningOptions()
        options.fuzzing = false
        var deck = try Deck(learningOptions: options, cards: [])
        _ = deck.apply(try #require(DeckChange.adding([dom, kot], to: deck)), at: start, calendar: calendar)
        review(&deck, dom.id, .good, at: start.addingTimeInterval(60))
        review(&deck, dom.id, .good, at: start.addingTimeInterval(120))
        return deck
    }

    func scheduled(_ deck: Deck, _ id: Card.ID, _ grade: Grade, at date: Date) -> Card {
        var random = SeededRandom(seed: 1)
        return Scheduler(learningOptions: deck.learningOptions, calendar: calendar).review(deck.card(withID: id)!, grade: grade, at: date, mode: .typed, duration: nil, using: &random)
    }

    /// A review as `SessionMode.grade` returns it: `learningOnly`. Returns the inverse the undo action holds.
    @discardableResult
    func review(_ deck: inout Deck, _ id: Card.ID, _ grade: Grade, at date: Date) -> DeckChange {
        var change = DeckChange(upserts: [scheduled(deck, id, grade, at: date)], contentStamp: .keep)
        change.learningOnly = true
        return deck.apply(change, at: date, calendar: calendar)
    }

    func merging(_ other: Deck, into deck: Deck, at now: Date) -> Deck {
        var deck = deck
        if let change = DeckChange.merging(other, into: deck, calendar: calendar) {
            _ = deck.apply(change, at: now, calendar: calendar)
        }
        return deck
    }

    /// (e) Mac grades "dom", then rereads the file in which the iPhone's later review of "dom" has been merged;
    /// undoing the Mac's grade must take back only that grade.
    @Test func undoOfGradeKeepsReviewOfOtherDeviceMergedAfterIt() throws {
        var mac = try baseDeck()
        let phoneStart = mac
        let undo = review(&mac, dom.id, .good, at: day(2))
        var phone = phoneStart
        review(&phone, dom.id, .good, at: day(3))
        mac = merging(phone, into: mac, at: day(4))
        #expect(mac.card(withID: dom.id)!.log.count == 4)

        _ = mac.apply(undo, at: day(5), calendar: calendar)
        // base 2 + the phone's review = 3
        #expect(mac.card(withID: dom.id)!.log.count == 3)
    }

    /// (a)/(e) A grade the learner took back with Undo, after the other device took the saved version in:
    /// merging the other device's copy must not bring the grade back.
    @Test func undoneGradeStaysUndoneAfterMergeWithOtherDevicesCopy() throws {
        var mac = try baseDeck()
        let undoGrade = review(&mac, dom.id, .again, at: day(2))
        let phone = mac // the phone read the saved version with the grade
        _ = mac.apply(undoGrade, at: day(2).addingTimeInterval(30), calendar: calendar)
        #expect(mac.card(withID: dom.id)!.log.count == 2)
        let merged = merging(phone, into: mac, at: day(2).addingTimeInterval(60))
        #expect(merged.card(withID: dom.id)!.log.count == 2)
    }

    /// (c) A reviews.jsonl that lost its tail (torn write, partial sync) is not a healthy deck: the next save would
    /// make the loss permanent. The card says it has had 2 reviews, the log lists 1 that ends before the last.
    @Test func truncatedReviewLogIsRejected() throws {
        let deck = try baseDeck()
        let wrapper = try DeckFile.fileWrapper(for: deck)
        let reviews = try #require(wrapper.fileWrappers?[DeckFile.reviewsFileName]?.regularFileContents)
        let lines = String(decoding: reviews, as: UTF8.self).split(separator: "\n")
        #expect(lines.count == 2)
        let cut = FileWrapper(regularFileWithContents: Data((lines.dropLast().joined(separator: "\n") + "\n").utf8))
        cut.preferredFilename = DeckFile.reviewsFileName
        wrapper.removeFileWrapper(wrapper.fileWrappers![DeckFile.reviewsFileName]!)
        wrapper.addFileWrapper(cut)

        #expect(throws: DeckFile.Error.reviewLogTooShort(question: "dom")) { try DeckFile.decode(wrapper) }
    }

    /// A log that is short because the card came from MacVocTrain 1 with its count of reviews ends with the last
    /// review and still opens, as does a card whose log is empty (an import not studied since looks the same as
    /// a reviews.jsonl that lost every line of the card: the one case this rule can't tell apart).
    @Test func logOfAnImportedCardStillOpens() throws {
        var deck = try baseDeck()
        var card = deck.card(withID: dom.id)!
        card.learningState?.reviews = 5
        deck.cards[deck.cards.firstIndex { $0.id == dom.id }!] = card
        let decoded = try DeckFile.decode(DeckFile.fileWrapper(for: deck))
        #expect(decoded.card(withID: dom.id)!.log.count == 2)

        card.log = []
        deck.cards[deck.cards.firstIndex { $0.id == dom.id }!] = card
        #expect(try DeckFile.decode(DeckFile.fileWrapper(for: deck)).card(withID: dom.id)!.log.isEmpty)
    }

    /// (a) Both devices grade the same card offline; merged either way, every review is there once.
    @Test func offlineGradesOfBothDevicesJoinOnceInBothDirections() throws {
        let base = try baseDeck()
        var mac = base
        var phone = base
        review(&mac, dom.id, .good, at: day(2))
        review(&mac, dom.id, .hard, at: day(3))
        review(&phone, dom.id, .again, at: day(2).addingTimeInterval(5))
        review(&phone, kot.id, .good, at: day(2))
        let a = merging(phone, into: mac, at: day(4))
        let b = merging(mac, into: phone, at: day(4))
        #expect(a.card(withID: dom.id)!.log.count == 5)
        #expect(b.card(withID: dom.id)!.log.count == 5)
        #expect(a.card(withID: dom.id)!.log.map(\.date) == b.card(withID: dom.id)!.log.map(\.date))
        #expect(a.card(withID: kot.id)!.log.count == 1)
        #expect(merging(a, into: a, at: day(5)) == a)
    }

    /// (b) Mac deletes "dom"; the phone grades it, once before and once after the deletion. No review is dropped either way.
    @Test func deletionAndGradeOfOtherDeviceKeepEveryReview() throws {
        let base = try baseDeck()
        for gradeAfterDeletion in [false, true] {
            var mac = base
            var phone = base
            let deletion = day(3)
            _ = mac.apply(try #require(DeckChange.removing([dom.id], from: mac)), at: deletion, calendar: calendar)
            review(&phone, dom.id, .good, at: gradeAfterDeletion ? day(4) : day(2))
            for merged in [merging(phone, into: mac, at: day(5)), merging(mac, into: phone, at: day(5))] {
                let all = merged.trainingCards.first { $0.id == dom.id }
                #expect(all?.log.count == 3, "after deletion: \(gradeAfterDeletion)")
            }
        }
    }

    /// Undo and redo of a grade are exact when nothing else touched the card: the state, fuzz included, comes back.
    @Test func undoAndRedoOfAGradeRestoreTheCardExactly() throws {
        var deck = try baseDeck()
        var options = deck.learningOptions
        options.fuzzing = true
        _ = deck.apply(DeckChange(learningOptions: options), at: day(1), calendar: calendar)
        let before = deck.card(withID: dom.id)!
        let undo = review(&deck, dom.id, .good, at: day(2))
        let after = deck.card(withID: dom.id)!

        let redo = deck.apply(undo, at: day(3), calendar: calendar)
        var undone = deck.card(withID: dom.id)!
        #expect(undone.log == before.log && undone.learningState == before.learningState)
        #expect(undone.undone.count == 1)

        _ = deck.apply(redo, at: day(4), calendar: calendar)
        #expect(deck.card(withID: dom.id)! == after)
        undone.undone = []
        #expect(undone == before)
    }

    /// A suspension the other device made after the grade stays when the grade is undone.
    @Test func undoOfAGradeKeepsTheOtherDevicesSuspension() throws {
        var mac = try baseDeck()
        let undo = review(&mac, dom.id, .good, at: day(2))
        var phone = mac
        _ = phone.apply(try #require(DeckChange.settingSuspended(true, of: [dom.id], in: phone, at: day(3))), at: day(3), calendar: calendar)
        mac = merging(phone, into: mac, at: day(4))
        _ = mac.apply(undo, at: day(5), calendar: calendar)
        #expect(mac.card(withID: dom.id)!.isSuspended)
        #expect(mac.card(withID: dom.id)!.log.count == 2)
    }

    /// An undone review is a line of its own in reviews.jsonl: the log reads back without it, the note comes back.
    @Test func undoneGradeSurvivesTheFile() throws {
        var mac = try baseDeck()
        let encoder = ReviewLogEncoder()
        let undo = review(&mac, dom.id, .again, at: day(2))
        let phone = mac
        _ = mac.apply(undo, at: day(3), calendar: calendar)

        let wrapper = try DeckFile.fileWrapper(for: mac, reviewLog: encoder)
        let lines = String(decoding: try #require(wrapper.fileWrappers?[DeckFile.reviewsFileName]?.regularFileContents), as: UTF8.self).split(separator: "\n")
        #expect(lines.count == 3)
        #expect(lines.filter { $0.contains("\"undone\":true") }.count == 1)

        let read = try DeckFile.decode(wrapper)
        #expect(read.card(withID: dom.id) == mac.card(withID: dom.id))
        // The deck read back still keeps the other device's copy from bringing the grade back.
        #expect(merging(phone, into: read, at: day(4)).card(withID: dom.id)!.log.count == 2)
        // Written again with the same encoder, the lines stay the same.
        let again = try DeckFile.fileWrapper(for: read, reviewLog: encoder)
        #expect(again.fileWrappers?[DeckFile.reviewsFileName]?.regularFileContents == wrapper.fileWrappers?[DeckFile.reviewsFileName]?.regularFileContents)
    }

    /// S3-3: the encoder reuses a card's lines only while its log is the one encoded; a duration filled in
    /// at an earlier entry, with the same count and last entry, shows in the lines.
    @Test func encoderNoticesAChangeToAnEarlierEntry() throws {
        var card = Card(question: "a", answer: "b", created: start)
        card.log = [ReviewLogEntry(date: day(1), grade: .good), ReviewLogEntry(date: day(2), grade: .good)]
        let encoder = ReviewLogEncoder()
        let first = String(decoding: encoder.encode([card]), as: UTF8.self)
        #expect(!first.contains("\"ms\""))
        card.log[0].duration = .milliseconds(500)
        let second = String(decoding: encoder.encode([card]), as: UTF8.self)
        #expect(second.split(separator: "\n")[0].contains("\"ms\":500"))
        #expect(encoder.lastEncodedCardCount == 1)
        _ = encoder.encode([card])
        #expect(encoder.lastEncodedCardCount == 0)
    }
}
