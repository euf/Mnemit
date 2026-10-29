import Foundation
import Testing

@testable import VocabCore

/// Today's counts must be what a study session started now takes.
struct StudyCountsTests {
    let calendar = StudyCalendar.testing
    /// 2026-10-05 18:00 in Berlin.
    let now = Date(timeIntervalSince1970: 1_791_216_000)

    func options() -> LearningOptions {
        var options = LearningOptions()
        options.newCardsPerSession = nil
        return options
    }

    /// A card in the review phase, due `dueInDays` study days from now.
    func review(_ question: String, note: String? = nil, kind: CardKind? = nil, interval: Int = 3, dueInDays: Int = 0) -> Card {
        let last = now.addingTimeInterval(-Double(interval - dueInDays) * 86400)
        let due = calendar.start(ofDay: calendar.dayNumber(for: last) + interval)
        let state = LearningState(phase: .review, stability: Double(interval), difficulty: 5, lastReview: last, due: due)
        return Card(question: question, answer: question, note: note, kind: kind, learningState: state)
    }

    func learning(_ question: String, phase: LearningPhase = .learning, note: String? = nil, dueIn seconds: TimeInterval = -30) -> Card {
        let state = LearningState(phase: phase, step: 1, stability: 1, difficulty: 5, lastReview: now.addingTimeInterval(-60), due: now.addingTimeInterval(seconds))
        return Card(question: question, answer: question, note: note, learningState: state)
    }

    func fresh(_ question: String, note: String? = nil, kind: CardKind? = nil) -> Card {
        Card(question: question, answer: question, note: note, kind: kind)
    }

    func taken(_ cards: [Card], options: LearningOptions? = nil) throws -> StudyCounts {
        let deck = try Deck(learningOptions: options ?? self.options(), cards: cards)
        let counts = StudySession.counts(for: deck, at: now, calendar: calendar)
        // The session takes the plan, as much of it as its size allows, whatever its seed.
        for seed in 1...5 {
            let session = StudySession(deck: deck, at: now, calendar: calendar, random: SeededRandom(seed: UInt64(seed))).session
            #expect(session.totalCount == min(StudySession.segmentSize, counts.total))
        }
        return counts
    }

    @Test func countsNewLearningAndReviewCardsThatAreDue() throws {
        var suspended = fresh("suspended")
        suspended.isSuspended = true
        let cards = [
            fresh("n1"), fresh("n2"), fresh("n3"), suspended,
            review("r1"), review("r2"), review("later", dueInDays: 2),
            learning("l1"), learning("l2", phase: .relearning), learning("soon", dueIn: 600),
        ]
        let counts = try taken(cards)
        #expect(counts.new == 3)
        #expect(counts.learning == 2)
        #expect(counts.review == 2)
        #expect(counts.total == 7)
    }

    @Test func theNewCardLimitHoldsForBothKindsTogether() throws {
        var options = options()
        options.newCardsPerSession = 3
        let cards = (0..<5).map { fresh("r\($0)", note: "r\($0)", kind: .recognition) } + (0..<3).map { fresh("p\($0)", note: "orphan\($0)", kind: .production) }
        // The words and the opened production cards alternate, a word first.
        var counts = try taken(cards, options: options)
        #expect(counts.newOther == 2)
        #expect(counts.newProduction == 1)
        #expect(counts.new == 3)
        #expect(counts.total == 3)
        options.newCardsPerSession = 6
        counts = try taken(cards, options: options)
        #expect(counts.newOther == 3)
        #expect(counts.newProduction == 3)
        // The shorter list runs out and the longer one goes on.
        options.newCardsPerSession = 8
        counts = try taken(cards, options: options)
        #expect(counts.newOther == 5)
        #expect(counts.newProduction == 3)
    }

    @Test func lockedProductionCardsAreNotCounted() throws {
        let production = fresh("p", note: "n", kind: .production)
        // The interval of the recognition card is still short: not due, production locked.
        var counts = try taken([review("r", note: "n", kind: .recognition, interval: 6, dueInDays: 3), production])
        #expect(counts.total == 0)
        // A new recognition card is asked instead, and the production card still waits.
        counts = try taken([fresh("r", note: "n", kind: .recognition), production])
        #expect(counts.new == 1)
        #expect(counts.newProduction == 0)
        // Once the interval has reached the unlock days, the production card is counted.
        counts = try taken([review("r", note: "n", kind: .recognition, interval: 40, dueInDays: 10), production])
        #expect(counts.newProduction == 1)
        #expect(counts.total == 1)
    }

    @Test func buriedSiblingsAreNotCounted() throws {
        // Two due cards of a note: one is taken.
        var counts = try taken([review("r", note: "n", kind: .recognition), review("p", note: "n", kind: .production), review("other", note: "m")])
        #expect(counts.review == 2)
        // A card of the note was reviewed today: its new sibling waits for tomorrow.
        var done = review("done", note: "n", kind: .recognition, interval: 10, dueInDays: 5)
        done.learningState?.lastReview = now.addingTimeInterval(-3600)
        done.learningState?.due = calendar.start(ofDay: calendar.dayNumber(for: now) + 10)
        counts = try taken([done, fresh("p", note: "n", kind: .production), fresh("q", note: "m", kind: .production)])
        #expect(counts.newProduction == 1)
        // A learning card is never buried, and buries its new sibling.
        counts = try taken([learning("l", note: "n"), fresh("p", note: "n", kind: .production)])
        #expect(counts.learning == 1)
        #expect(counts.new == 0)
    }

    @Test func segmentSizeCapsTheSessionTakingLearningThenReviewThenNewCardsButNotThePlan() throws {
        let cards = (0..<3).map { learning("l\($0)") } + (0..<110).map { review("r\($0)") } + (0..<10).map { fresh("n\($0)") }
        let deck = try Deck(learningOptions: options(), cards: cards)
        // The plan is all of it, whatever the size of a session is.
        let counts = try taken(cards)
        #expect(counts.learning == 3)
        #expect(counts.review == 110)
        #expect(counts.new == 10)
        #expect(counts.total == 123)
        // A session takes the learning cards, then the reviews, up to its size.
        var random = SeededRandom(seed: 1)
        let ids = StudySession.selectCards(from: deck, at: now, calendar: calendar, using: &random)
        let selected = ids.map { deck.card(withID: $0)! }
        #expect(selected.count == StudySession.segmentSize)
        #expect(selected.filter { $0.learningState?.phase == .learning }.count == 3)
        #expect(selected.filter { $0.learningState?.phase == .review }.count == StudySession.segmentSize - 3)
        #expect(selected.filter(\.isNew).isEmpty)

        // With room left after the reviews, the new cards fill it.
        let fewer = Array(cards.prefix(3 + 90)) + cards.suffix(10)
        let narrower = try Deck(learningOptions: options(), cards: fewer)
        random = SeededRandom(seed: 1)
        let narrowerSelected = StudySession.selectCards(from: narrower, at: now, calendar: calendar, using: &random).map { narrower.card(withID: $0)! }
        #expect(narrowerSelected.filter { $0.learningState?.phase == .review }.count == 90)
        #expect(narrowerSelected.filter(\.isNew).count == StudySession.segmentSize - 93)
        #expect(narrowerSelected.count == StudySession.segmentSize)
    }

    @Test func countsMatchTheSessionOfADeckWithEveryKindOfCard() throws {
        var options = LearningOptions()
        options.newCardsPerSession = 10
        var cards: [Card] = []
        for index in 0..<30 {
            // Words 0-9 are new. Words 10-19 are learned, so their production cards are open. Words 20-29 are new, but
            // their production cards are due for review and bury them.
            let learned = index >= 10 && index < 20
            cards.append(learned ? review("r\(index)", note: "n\(index)", kind: .recognition, interval: 30, dueInDays: 10) : fresh("r\(index)", note: "n\(index)", kind: .recognition))
            cards.append(index >= 20 ? review("p\(index)", note: "n\(index)", kind: .production) : fresh("p\(index)", note: "n\(index)", kind: .production))
        }
        cards += (0..<12).map { review("x\($0)", note: "x\($0)", kind: .recognition, interval: 30, dueInDays: -1) }
        cards += (0..<12).map { learning("l\($0)", note: "n\(20 + $0 % 10)") }
        let deck = try Deck(learningOptions: options, cards: cards)
        let expected = StudySession.counts(for: deck, at: now, calendar: calendar)
        for seed in 1...20 {
            var random = SeededRandom(seed: UInt64(seed))
            let ids = StudySession.selectCards(from: deck, at: now, calendar: calendar, using: &random)
            let selected = ids.map { deck.card(withID: $0)! }
            #expect(selected.count == expected.total)
            #expect(selected.filter { $0.learningState?.phase == .review }.count == expected.review)
            #expect(selected.filter { $0.learningState != nil && $0.learningState?.phase != .review }.count == expected.learning)
            #expect(selected.filter { $0.isNew && $0.kind == .production }.count == expected.newProduction)
            #expect(selected.filter { $0.isNew && $0.kind != .production }.count == expected.newOther)
        }
        // The ten new words that can be asked alternate with the ten open production cards, one for one, up to the limit of
        // ten for both kinds.
        #expect(expected.newOther == 5)
        #expect(expected.newProduction == 5)
    }

    @Test func nextDueIsTheFirstLaterDateOrTheNextStudyDayOfABuriedCard() throws {
        #expect(try taken([fresh("n")]).nextDue == nil)
        #expect(try taken([review("later", dueInDays: 2), learning("soon", dueIn: 600)]).nextDue == now.addingTimeInterval(600))
        var suspended = review("suspended", dueInDays: 1)
        suspended.isSuspended = true
        #expect(try taken([suspended]).nextDue == nil)

        let both = [review("r", note: "n", kind: .recognition), review("p", note: "n", kind: .production)]
        let tomorrow = calendar.start(ofDay: calendar.dayNumber(for: now) + 1)
        // One of the siblings is asked, the other is buried until tomorrow.
        #expect(try taken(both).nextDue == tomorrow)
        #expect(try taken(both + [learning("soon", dueIn: 600)]).nextDue == now.addingTimeInterval(600))
    }

    @Test func theDueCountIsAnkisAndTheDeckIsDoneWhenThePlanIsEmpty() throws {
        var options = options()
        options.newCardsPerSession = 1
        var suspended = review("suspended")
        suspended.suspend(at: now)
        let cards = [
            review("due1"), review("due2"), learning("learning"), learning("later", dueIn: 600), review("tomorrow", dueInDays: 1), suspended,
            fresh("new1"), fresh("new2"),
        ]
        let deck = try Deck(learningOptions: options, cards: cards)
        let counts = StudySession.counts(for: deck, at: now, calendar: calendar)
        // Due now: two review cards and the learning card due; not new, not suspended, not due later.
        #expect(counts.due == 3)
        #expect(counts.due == deck.filterCounts(at: now)[.due])
        // The plan has the new card within its limit on top.
        #expect(counts.total == 4 && !counts.isDone)

        let finished = try Deck(learningOptions: options, cards: [review("tomorrow", dueInDays: 1), suspended])
        let none = StudySession.counts(for: finished, at: now, calendar: calendar)
        #expect(none.due == 0 && none.isDone)
        // A deck with only new cards past the limit has nothing due and, once its limit is spent, nothing left.
        let spent = StudySession.counts(for: try Deck(learningOptions: self.options(), cards: [fresh("n")]), at: now, calendar: calendar, newCardAllowance: 0)
        #expect(spent.due == 0 && spent.isDone)
    }
}
