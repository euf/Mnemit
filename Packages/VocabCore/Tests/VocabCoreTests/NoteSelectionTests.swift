import Foundation
import Testing

@testable import VocabCore

/// How a study session treats the cards of a note: recognition and production cards
/// of one word.
struct NoteSelectionTests {
    let calendar = StudyCalendar.testing
    /// 2026-10-05 18:00 in Berlin.
    let now = Date(timeIntervalSince1970: 1_791_216_000)

    func options() -> LearningOptions {
        var options = LearningOptions()
        options.fuzzing = false
        options.newCardsPerSession = nil
        return options
    }

    /// A card in the review phase whose last review was `daysAgo` days ago and whose
    /// scheduled interval is `interval` days.
    func review(_ question: String, note: String? = nil, kind: CardKind? = nil, interval: Int, daysAgo: Int) -> Card {
        let last = now.addingTimeInterval(-Double(daysAgo) * 86400)
        let due = calendar.start(ofDay: calendar.dayNumber(for: last) + interval)
        let state = LearningState(phase: .review, stability: Double(interval), difficulty: 5, lastReview: last, due: due)
        return Card(question: question, answer: question, note: note, kind: kind, learningState: state)
    }

    func learning(_ question: String, note: String? = nil, kind: CardKind? = nil, lastReview: Date? = nil) -> Card {
        let state = LearningState(phase: .learning, step: 1, stability: 1, difficulty: 5, lastReview: lastReview ?? now.addingTimeInterval(-60), due: now.addingTimeInterval(-30))
        return Card(question: question, answer: question, note: note, kind: kind, learningState: state)
    }

    func fresh(_ question: String, note: String? = nil, kind: CardKind? = nil) -> Card {
        Card(question: question, answer: question, note: note, kind: kind)
    }

    func selected(_ cards: [Card], options: LearningOptions? = nil, seed: UInt64 = 1) throws -> Set<String> {
        let deck = try Deck(learningOptions: options ?? self.options(), cards: cards)
        var random = SeededRandom(seed: seed)
        // These cards are overdue by days to set their urgency apart.
        let ids = StudySession.selectCards(from: deck, at: now, calendar: calendar, using: &random)
        #expect(ids.count == Set(ids).count)
        return Set(ids.map { id in deck.card(withID: id)!.question })
    }

    // MARK: Locked production cards

    @Test func productionStaysLockedUntilTheRecognitionIntervalIsLongEnough() throws {
        // Last reviewed a day ago, so due in 5 or 6 days: only the production card is due.
        let production = fresh("p", note: "n", kind: .production)
        let short = review("r", note: "n", kind: .recognition, interval: 6, daysAgo: 1)
        #expect(try selected([short, production]) == [])
        let long = review("r", note: "n", kind: .recognition, interval: 7, daysAgo: 1)
        #expect(try selected([long, production]) == ["p"])
    }

    @Test func productionStaysLockedWhileTheRecognitionCardIsNewLearningOrRelapsed() throws {
        let production = fresh("p", note: "n", kind: .production)
        // Not due, so the sibling doesn't bury the production card either.
        var notDue = learning("r", note: "n", kind: .recognition)
        notDue.learningState?.due = now.addingTimeInterval(86400)
        #expect(try selected([notDue, production]) == [])

        var relearning = review("r", note: "n", kind: .recognition, interval: 40, daysAgo: 10)
        relearning.learningState?.phase = .relearning
        relearning.learningState?.due = now.addingTimeInterval(86400)
        #expect(try selected([relearning, production]) == [])

        // A new recognition card is asked instead, and holds the production card back.
        #expect(try selected([fresh("r", note: "n", kind: .recognition), production]) == ["r"])
    }

    @Test func productionUnlocksAfterSevenDays() {
        #expect(StudySession.unlockDays == 7)
    }

    @Test func productionWithoutRecognitionOrNoteIsNotLocked() throws {
        let orphan = fresh("orphan", note: "x", kind: .production)
        let noNote = fresh("noNote", kind: .production)
        let plain = fresh("plain")
        let other = review("r", note: "other", kind: .recognition, interval: 3, daysAgo: 1)
        #expect(try selected([orphan, noNote, plain, other]) == ["orphan", "noNote", "plain"])
    }

    @Test func aProductionCardAlreadyStudiedIsNotLockedAgain() throws {
        // The recognition card lapsed after the production card was introduced.
        var relearning = review("r", note: "n", kind: .recognition, interval: 40, daysAgo: 10)
        relearning.learningState?.phase = .relearning
        relearning.learningState?.due = now.addingTimeInterval(86400)
        let production = review("p", note: "n", kind: .production, interval: 3, daysAgo: 5)
        #expect(try selected([relearning, production]) == ["p"])
    }

    // MARK: Burying siblings

    @Test func siblingReviewedTodayBuriesNewAndReviewCards() throws {
        let today = now.addingTimeInterval(-3600)
        // Not due: reviewed an hour ago with an interval that has unlocked the production card.
        var done = review("done", note: "n", kind: .recognition, interval: StudySession.unlockDays, daysAgo: 0)
        done.learningState?.lastReview = today
        #expect(try selected([done, fresh("p", note: "n", kind: .production)]) == [])
        #expect(try selected([done, review("p", note: "n", kind: .production, interval: 3, daysAgo: 5)]) == [])
        // Another note is not affected.
        #expect(try selected([done, fresh("p", note: "m", kind: .production)]) == ["p"])
    }

    @Test func siblingReviewedOnAnEarlierStudyDayBuriesNothing() throws {
        var done = review("done", note: "n", kind: .recognition, interval: StudySession.unlockDays, daysAgo: 0)
        let production = fresh("p", note: "n", kind: .production)
        // 02:00 in Berlin is before the rollover at 04:00: still the study day before.
        done.learningState?.lastReview = Date(timeIntervalSince1970: 1_791_158_400)
        #expect(calendar.dayNumber(for: done.learningState!.lastReview) == calendar.dayNumber(for: now) - 1)
        #expect(try selected([done, production]) == ["p"])
        // 05:00 in Berlin is the same study day.
        done.learningState?.lastReview = Date(timeIntervalSince1970: 1_791_169_200)
        #expect(try selected([done, production]) == [])
    }

    @Test func onlyOneDueSiblingIsSelectedPerSession() throws {
        let both = [
            review("r", note: "n", kind: .recognition, interval: 3, daysAgo: 5),
            review("p", note: "n", kind: .production, interval: 3, daysAgo: 5),
            review("other", note: "m", kind: .recognition, interval: 3, daysAgo: 5),
        ]
        let chosen = try selected(both)
        #expect(chosen.count == 2)
        #expect(chosen.contains("other"))
        #expect(chosen.contains("r") != chosen.contains("p"))
    }

    @Test func theMoreUrgentSiblingWins() throws {
        let overdue = review("overdue", note: "n", kind: .recognition, interval: 3, daysAgo: 60)
        let recent = review("recent", note: "n", kind: .production, interval: 3, daysAgo: 4)
        for seed in 1...5 {
            #expect(try selected([recent, overdue], seed: UInt64(seed)) == ["overdue"])
        }
    }

    @Test func learningCardsAreNeverBuried() throws {
        var done = review("done", note: "n", kind: .recognition, interval: 3, daysAgo: 0)
        done.learningState?.lastReview = now.addingTimeInterval(-3600)
        let production = learning("p", note: "n", kind: .production)
        #expect(try selected([done, production]) == ["p"])

        // A learning card in the session buries the due review or new card of its note.
        let sibling = review("sibling", note: "n", kind: .recognition, interval: 3, daysAgo: 5)
        #expect(try selected([sibling, production]) == ["p"])
        #expect(try selected([fresh("new", note: "n", kind: .recognition), production]) == ["p"])
        // Two learning cards of a note are both asked.
        #expect(try selected([learning("a", note: "n"), learning("b", note: "n")]) == ["a", "b"])
    }

    @Test func buriedCardsDoNotUseUpTheLimit() throws {
        var options = options()
        options.newCardsPerSession = 2
        let cards = [
            fresh("a", note: "n", kind: .recognition),
            fresh("a2", note: "n", kind: .recognition),
            fresh("b", note: "m", kind: .recognition),
            fresh("c", note: "k", kind: .recognition),
            fresh("c2", note: "k", kind: .recognition),
        ]
        // "a2" is buried by "a" without taking one of the two places, so "b" still gets it.
        #expect(try selected(cards, options: options) == ["a", "b"])
        options.newCardsPerSession = 3
        #expect(try selected(cards, options: options) == ["a", "b", "c"])
    }

    @Test func cardsWithoutNoteBehaveAsBefore() throws {
        let cards = [fresh("a"), fresh("b"), review("c", interval: 3, daysAgo: 5), learning("d")]
        #expect(try selected(cards) == ["a", "b", "c", "d"])
    }

    // MARK: Limits and order of new cards

    @Test func newCardsPerSessionIsOneLimitOverBothKinds() throws {
        var options = options()
        options.newCardsPerSession = 3
        let cards =
            (0..<6).map { fresh("r\($0)", note: "r\($0)", kind: .recognition) }
            + (0..<6).map { fresh("p\($0)", note: "orphan\($0)", kind: .production) }
            + (0..<3).map { fresh("x\($0)") }
        // The words go in deck order and the opened production cards alternate with them, a word first.
        #expect(try selected(cards, options: options) == ["r0", "p0", "r1"])
        options.newCardsPerSession = 4
        #expect(try selected(cards, options: options) == ["r0", "p0", "r1", "p1"])
        options.newCardsPerSession = nil
        #expect(try selected(cards, options: options).count == 15)
    }

    @Test func aDeckWithNewCardsPerSessionIgnoresTheAllowance() throws {
        var options = options()
        let cards = (0..<8).map { fresh("c\($0)") }
        func taken(allowance: Int?) throws -> Int {
            let deck = try Deck(learningOptions: options, cards: cards)
            var random = SeededRandom(seed: 1)
            return StudySession.selectCards(from: deck, at: now, calendar: calendar, newCardAllowance: allowance, using: &random).count
        }
        // Without New cards/day the allowance of the day is the limit, and nil leaves the deck all of it.
        #expect(try taken(allowance: 3) == 3)
        #expect(try taken(allowance: nil) == 8)
        // With it the deck takes its own number, more or less than the allowance.
        options.newCardsPerSession = 5
        #expect(try taken(allowance: 3) == 5)
        options.newCardsPerSession = 2
        #expect(try taken(allowance: 6) == 2)
        #expect(try taken(allowance: nil) == 2)
    }

    @Test func newCardsComeNewestDayFirstAndWithinADayAsTheyWereAdded() throws {
        let created = now.addingTimeInterval(-86400)
        // Cards 0...3 are a day older than 4...9.
        let cards = (0..<10).map { index in
            Card(id: UUID(), question: "c\(index)", answer: "a", created: index < 4 ? created : now)
        }
        var options = options()
        options.newCardsPerSession = 3
        // Cards created together stay in deck order.
        #expect(try selected(cards, options: options) == ["c4", "c5", "c6"])
        options.newCardsPerSession = 8
        // The older day follows the newer one, again in deck order.
        #expect(try selected(cards, options: options) == ["c4", "c5", "c6", "c7", "c8", "c9", "c0", "c1"])

        // Within a day the card added first comes first, wherever the deck lists it.
        let typed = [
            Card(id: UUID(), question: "second", answer: "a", created: now),
            Card(id: UUID(), question: "first", answer: "a", created: now.addingTimeInterval(-600)),
            Card(id: UUID(), question: "yesterday", answer: "a", created: created),
        ]
        options.newCardsPerSession = 1
        #expect(try selected(typed, options: options) == ["first"])
        options.newCardsPerSession = 2
        #expect(try selected(typed, options: options) == ["first", "second"])
    }

    @Test func theNewestDayStillOrdersProductionCardsWithoutALearnedWord() throws {
        var options = options()
        options.newCardsPerSession = 1
        let old = Card(id: UUID(), text: CardText(question: "old", answer: "a")!, note: "o", kind: .production, created: now.addingTimeInterval(-86400))
        let young = Card(id: UUID(), text: CardText(question: "young", answer: "a")!, note: "y", kind: .production, created: now)
        #expect(try selected([old, young], options: options) == ["young"])
    }

    /// A recognition card first reviewed `learnedDaysAgo` days ago, again yesterday, and not due for 10 days.
    func learned(_ question: String, note: String, learnedDaysAgo: Int) -> Card {
        let first = now.addingTimeInterval(-Double(learnedDaysAgo) * 86400)
        let last = now.addingTimeInterval(-86400)
        let due = calendar.start(ofDay: calendar.dayNumber(for: last) + 10)
        let state = LearningState(phase: .review, stability: 10, difficulty: 5, lastReview: last, due: due, reviews: 2)
        let log = [ReviewLogEntry(date: first, grade: .good), ReviewLogEntry(date: last, grade: .good)]
        return Card(question: question, answer: question, note: note, kind: .recognition, created: first, learningState: state, log: log)
    }

    func production(_ question: String, note: String, created: Date) -> Card {
        Card(id: UUID(), text: CardText(question: question, answer: "a")!, note: note, kind: .production, created: created)
    }

    @Test func unlockedProductionCardsGoByWhenTheirWordsWereLearnedWhateverTheirAddition() throws {
        var options = options()
        options.newCardsPerSession = 7
        // Word i was learned 10...39 days ago, in an order unrelated to the deck's and to the creation dates
        // of the production cards, of which p0 is the newest.
        func age(_ i: Int) -> Int { (i * 7) % 30 + 10 }
        var cards: [Card] = []
        for i in 0..<30 {
            cards.append(learned("r\(i)", note: "n\(i)", learnedDaysAgo: age(i)))
            cards.append(production("p\(i)", note: "n\(i)", created: now.addingTimeInterval(-Double(i) * 3600)))
        }
        let oldest = Set((0..<30).sorted { age($0) > age($1) }.prefix(7).map { "p\($0)" })
        #expect(oldest != Set((0..<7).map { "p\($0)" }))
        #expect(try selected(cards, options: options) == oldest)
    }

    @Test func newWordsAndOpenedProductionCardsAlternateOneForOneTheOldestLearnedFirst() throws {
        var options = options()
        let cards = [
            Card(id: UUID(), text: CardText(question: "old", answer: "a")!, note: "a", kind: .recognition, created: now.addingTimeInterval(-86400)),
            Card(id: UUID(), text: CardText(question: "mid", answer: "a")!, note: "b", kind: .recognition, created: now.addingTimeInterval(-3600)),
            Card(id: UUID(), text: CardText(question: "new", answer: "a")!, note: "c", kind: .recognition, created: now),
            learned("r1", note: "x", learnedDaysAgo: 12),
            learned("r2", note: "y", learnedDaysAgo: 30),
            production("p1", note: "x", created: now),
            production("p2", note: "y", created: now.addingTimeInterval(-86400)),
        ]
        // The words come as they were added (the day before last), the production cards by when their words were
        // learned: p2's word is 30 days old, p1's 12; the two lists alternate, a word first.
        options.newCardsPerSession = 3
        #expect(try selected(cards, options: options) == ["mid", "p2", "new"])
        options.newCardsPerSession = 4
        #expect(try selected(cards, options: options) == ["mid", "p2", "new", "p1"])
        options.newCardsPerSession = 5
        #expect(try selected(cards, options: options) == ["mid", "p2", "new", "p1", "old"])
    }

    @Test func theLongerListOfNewCardsFollowsTheShorterOneAlternating() throws {
        var options = options()
        func words(_ count: Int) -> [Card] { (0..<count).map { fresh("w\($0)") } }
        func unlocked(_ count: Int) -> [Card] {
            (0..<count).flatMap { [learned("r\($0)", note: "n\($0)", learnedDaysAgo: 40 - $0), production("p\($0)", note: "n\($0)", created: now)] }
        }
        func order(_ cards: [Card]) throws -> [String] {
            let deck = try Deck(learningOptions: options, cards: cards)
            var random = SeededRandom(seed: 1)
            let ids = StudySession.selectCards(from: deck, at: now, calendar: calendar, using: &random)
            return ids.compactMap { deck.card(withID: $0)?.question }.sorted()
        }
        options.newCardsPerSession = 6
        // Two words, four opened cards: w0 p0 w1 p1 p2 p3.
        #expect(try order(words(2) + unlocked(4)) == ["p0", "p1", "p2", "p3", "w0", "w1"])
        // Four words, one opened card: w0 p0 w1 w2 w3.
        #expect(try order(words(4) + unlocked(1)) == ["p0", "w0", "w1", "w2", "w3"])
        options.newCardsPerSession = 3
        // A limit short of the lists still takes them alternating: w0 p0 w1.
        #expect(try order(words(4) + unlocked(4)) == ["p0", "w0", "w1"])
    }

    @Test func aProductionCardWithoutALearnedWordFollowsTheOthersInTheOrderOfAdditions() throws {
        var options = options()
        let cards = [
            production("alone", note: "none", created: now),
            production("p1", note: "x", created: now.addingTimeInterval(-86400)),
            production("p2", note: "y", created: now.addingTimeInterval(-2 * 86400)),
            production("noNote", note: " ", created: now.addingTimeInterval(-3600)),
            learned("r1", note: "x", learnedDaysAgo: 12),
            learned("r2", note: "y", learnedDaysAgo: 30),
        ]
        options.newCardsPerSession = 2
        #expect(try selected(cards, options: options) == ["p1", "p2"])
        options.newCardsPerSession = 3
        // `noNote` has no note, so it is not locked either; both undated cards come after, the day's cards as they
        // were added.
        #expect(try selected(cards, options: options) == ["p1", "p2", "noNote"])
    }

    @Test func segmentSizeCapStopsTheSelectionBeforeBuryingMore() throws {
        // 120 notes of two due cards each: a note gives one card, and a buried card takes no place of the segment.
        let cards = (0..<120).flatMap { index in
            [
                review("a\(index)", note: "n\(index)", kind: .recognition, interval: 3, daysAgo: 9),
                review("b\(index)", note: "n\(index)", kind: .production, interval: 3, daysAgo: 9),
            ]
        }
        for seed in 1...3 {
            let chosen = try selected(cards, seed: UInt64(seed))
            #expect(chosen.count == StudySession.segmentSize)
            #expect(Set(chosen.map { $0.dropFirst() }).count == StudySession.segmentSize)
        }
    }

    // MARK: Whole sessions

    @Test func studySessionHoldsProductionBackThenIntroducesItOnALaterDay() throws {
        var deck = try Deck(learningOptions: options(), cards: [])
        let recognition = Card(id: UUID(), text: CardText(question: "σπίτι", answer: "house")!, note: "σπίτι", kind: .recognition, created: now)
        let production = Card(id: UUID(), text: CardText(question: "house", answer: "σπίτι")!, note: "σπίτι", kind: .production, created: now)
        _ = deck.apply(try #require(DeckChange.adding([recognition, production], to: deck)), at: now, calendar: calendar)
        deck.learningOptions.steps = 1

        var study = StudySession(deck: deck, at: now, calendar: calendar, random: SeededRandom(seed: 3))
        #expect(study.session.totalCount == 1)
        #expect(study.session.currentCardID == recognition.id)
        let reviewed = study.review(.good, of: recognition, with: deck.learningOptions, at: now, calendar: calendar)
        let scheduled = try #require(reviewed)
        _ = deck.apply(DeckChange(upserts: [scheduled], contentStamp: .keep), at: now, calendar: calendar)
        #expect(scheduled.learningState?.phase == .review)

        // The first interval is under 7 days: the production card waits, and the
        // recognition card isn't due.
        let interval = calendar.days(from: now, to: scheduled.learningState!.due)
        #expect(interval < StudySession.unlockDays)
        #expect(StudySession(deck: deck, at: now, calendar: calendar).session.isFinished)

        // With an interval of 7 days the production card is unlocked, but the sibling
        // was reviewed today: it comes on the next study day.
        deck.cards[0].learningState?.due = calendar.start(ofDay: calendar.dayNumber(for: now) + 7)
        #expect(StudySession(deck: deck, at: now, calendar: calendar).session.isFinished)
        let tomorrow = StudySession(deck: deck, at: now.addingTimeInterval(86400), calendar: calendar)
        #expect(tomorrow.session.totalCount == 1)
        #expect(tomorrow.session.currentCardID == production.id)
    }
}
