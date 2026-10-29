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
        options.cardsPerSession = nil
        options.newCardsPerSession = nil
        options.newProductionPerSession = nil
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

    @Test func productionUnlocksAfterSevenDaysByDefault() {
        #expect(LearningOptions().productionUnlockDays == 7)
    }

    @Test func unlockDaysZeroNeverLocks() throws {
        var options = options()
        options.productionUnlockDays = 0
        let production = fresh("p", note: "n", kind: .production)
        let young = review("r", note: "n", kind: .recognition, interval: 2, daysAgo: 1)
        #expect(try selected([young, production], options: options) == ["p"])
    }

    @Test func unlockDaysIsTheLimit() throws {
        var options = options()
        options.productionUnlockDays = 5
        let production = fresh("p", note: "n", kind: .production)
        #expect(try selected([review("r", note: "n", kind: .recognition, interval: 4, daysAgo: 1), production], options: options) == [])
        #expect(try selected([review("r", note: "n", kind: .recognition, interval: 5, daysAgo: 1), production], options: options) == ["p"])
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
        var options = options()
        options.productionUnlockDays = 0
        let today = now.addingTimeInterval(-3600)
        // Not due: reviewed an hour ago with an interval of a few days.
        var done = review("done", note: "n", kind: .recognition, interval: 3, daysAgo: 0)
        done.learningState?.lastReview = today
        #expect(try selected([done, fresh("p", note: "n", kind: .production)], options: options) == [])
        #expect(try selected([done, review("p", note: "n", kind: .production, interval: 3, daysAgo: 5)], options: options) == [])
        // Another note is not affected.
        #expect(try selected([done, fresh("p", note: "m", kind: .production)], options: options) == ["p"])
    }

    @Test func siblingReviewedOnAnEarlierStudyDayBuriesNothing() throws {
        var options = options()
        options.productionUnlockDays = 0
        var done = review("done", note: "n", kind: .recognition, interval: 3, daysAgo: 0)
        let production = fresh("p", note: "n", kind: .production)
        // 02:00 in Berlin is before the rollover at 04:00: still the study day before.
        done.learningState?.lastReview = Date(timeIntervalSince1970: 1_791_158_400)
        #expect(calendar.dayNumber(for: done.learningState!.lastReview) == calendar.dayNumber(for: now) - 1)
        #expect(try selected([done, production], options: options) == ["p"])
        // 05:00 in Berlin is the same study day.
        done.learningState?.lastReview = Date(timeIntervalSince1970: 1_791_169_200)
        #expect(try selected([done, production], options: options) == [])
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
        var options = options()
        options.productionUnlockDays = 0
        var done = review("done", note: "n", kind: .recognition, interval: 3, daysAgo: 0)
        done.learningState?.lastReview = now.addingTimeInterval(-3600)
        let production = learning("p", note: "n", kind: .production)
        #expect(try selected([done, production], options: options) == ["p"])

        // A learning card in the session buries the due review or new card of its note.
        let sibling = review("sibling", note: "n", kind: .recognition, interval: 3, daysAgo: 5)
        #expect(try selected([sibling, production], options: options) == ["p"])
        #expect(try selected([fresh("new", note: "n", kind: .recognition), production], options: options) == ["p"])
        // Two learning cards of a note are both asked.
        #expect(try selected([learning("a", note: "n"), learning("b", note: "n")], options: options) == ["a", "b"])
    }

    @Test func buriedCardsDoNotUseUpTheLimits() throws {
        var options = options()
        options.productionUnlockDays = 0
        options.newCardsPerSession = 2
        options.newProductionPerSession = 1
        let cards = [
            fresh("a", note: "n", kind: .recognition),
            fresh("a2", note: "n", kind: .production),
            fresh("b", note: "m", kind: .recognition),
            fresh("c", note: "k", kind: .recognition),
            fresh("c2", note: "k", kind: .production),
        ]
        // "a2" is buried by "a" without using the production slot, so "c2" still gets it
        // although the limit of two cut "c".
        #expect(try selected(cards, options: options) == ["a", "b", "c2"])
        options.newCardsPerSession = 3
        #expect(try selected(cards, options: options) == ["a", "b", "c"])
    }

    @Test func cardsWithoutNoteBehaveAsBefore() throws {
        let cards = [fresh("a"), fresh("b"), review("c", interval: 3, daysAgo: 5), learning("d")]
        #expect(try selected(cards) == ["a", "b", "c", "d"])
    }

    // MARK: Limits and order of new cards

    @Test func productionCardsHaveTheirOwnLimit() throws {
        var options = options()
        options.newCardsPerSession = 3
        options.newProductionPerSession = 2
        let cards =
            (0..<6).map { fresh("r\($0)", note: "r\($0)", kind: .recognition) }
            + (0..<6).map { fresh("p\($0)", note: "orphan\($0)", kind: .production) }
            + (0..<3).map { fresh("x\($0)") }
        let chosen = try selected(cards, options: options)
        #expect(chosen.count == 5)
        #expect(chosen.filter { $0.hasPrefix("p") }.count == 2)
        // The limit of 3 counts recognition and plain cards together, in deck order.
        #expect(Set(chosen.filter { !$0.hasPrefix("p") }) == ["r0", "r1", "r2"])

        options.newProductionPerSession = 0
        #expect(try selected(cards, options: options).count == 3)
        options.newProductionPerSession = nil
        #expect(try selected(cards, options: options).count == 9)
        options.newCardsPerSession = nil
        #expect(try selected(cards, options: options).count == 15)
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
        options.newProductionPerSession = 1
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
        options.newProductionPerSession = 7
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

    @Test func newRecognitionCardsKeepTheOrderOfAdditionsNextToProductionCardsOldestLearnedFirst() throws {
        var options = options()
        options.newCardsPerSession = 2
        options.newProductionPerSession = 1
        let cards = [
            Card(id: UUID(), text: CardText(question: "old", answer: "a")!, note: "a", kind: .recognition, created: now.addingTimeInterval(-86400)),
            Card(id: UUID(), text: CardText(question: "mid", answer: "a")!, note: "b", kind: .recognition, created: now.addingTimeInterval(-3600)),
            Card(id: UUID(), text: CardText(question: "new", answer: "a")!, note: "c", kind: .recognition, created: now),
            learned("r1", note: "x", learnedDaysAgo: 12),
            learned("r2", note: "y", learnedDaysAgo: 30),
            production("p1", note: "x", created: now),
            production("p2", note: "y", created: now.addingTimeInterval(-86400)),
        ]
        #expect(try selected(cards, options: options) == ["new", "mid", "p2"])
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
        options.newProductionPerSession = 2
        #expect(try selected(cards, options: options) == ["p1", "p2"])
        options.newProductionPerSession = 3
        // `noNote` has no note, so it is not locked either; both undated cards come after, the day's cards as they
        // were added.
        #expect(try selected(cards, options: options) == ["p1", "p2", "noNote"])
    }

    @Test func sessionSizeCapStopsTheSelectionBeforeBuryingMore() throws {
        var options = options()
        options.cardsPerSession = 2
        let cards = [
            review("a", note: "n", kind: .recognition, interval: 3, daysAgo: 9),
            review("a2", note: "n", kind: .production, interval: 3, daysAgo: 9),
            review("b", note: "m", kind: .recognition, interval: 3, daysAgo: 9),
            review("c", note: "k", kind: .recognition, interval: 3, daysAgo: 9),
        ]
        // Buried cards don't take a place: whichever sibling comes first, two others fill it.
        for seed in 1...10 {
            let chosen = try selected(cards, options: options, seed: UInt64(seed))
            #expect(chosen.count == 2)
            #expect(chosen.filter { $0 == "a" || $0 == "a2" }.count <= 1)
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
        #expect(interval < deck.learningOptions.productionUnlockDays)
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
