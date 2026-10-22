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
        options.cardsPerSession = nil
        options.newCardsPerSession = nil
        options.newProductionPerSession = nil
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
            #expect(session.totalCount == min(deck.learningOptions.cardsPerSession ?? Int.max, counts.total))
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

    @Test func newCardLimitsAreSeparateForProductionCards() throws {
        var options = options()
        options.newCardsPerSession = 2
        options.newProductionPerSession = 1
        let cards = (0..<5).map { fresh("r\($0)", note: "r\($0)", kind: .recognition) } + (0..<3).map { fresh("p\($0)", note: "orphan\($0)", kind: .production) }
        let counts = try taken(cards, options: options)
        #expect(counts.newOther == 2)
        #expect(counts.newProduction == 1)
        #expect(counts.new == 3)
        #expect(counts.total == 3)
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
        var options = options()
        options.productionUnlockDays = 0
        // Two due cards of a note: one is taken.
        var counts = try taken([review("r", note: "n", kind: .recognition), review("p", note: "n", kind: .production), review("other", note: "m")], options: options)
        #expect(counts.review == 2)
        // A card of the note was reviewed today: its new sibling waits for tomorrow.
        var done = review("done", note: "n", kind: .recognition, interval: 10, dueInDays: 5)
        done.learningState?.lastReview = now.addingTimeInterval(-3600)
        counts = try taken([done, fresh("p", note: "n", kind: .production), fresh("q", note: "m", kind: .production)], options: options)
        #expect(counts.newProduction == 1)
        // A learning card is never buried, and buries its new sibling.
        counts = try taken([learning("l", note: "n"), fresh("p", note: "n", kind: .production)], options: options)
        #expect(counts.learning == 1)
        #expect(counts.new == 0)
    }

    @Test func sessionSizeCapsTheSessionTakingLearningThenReviewThenNewCardsButNotThePlan() throws {
        var options = options()
        options.cardsPerSession = 5
        let cards = (0..<3).map { learning("l\($0)") } + (0..<10).map { review("r\($0)") } + (0..<10).map { fresh("n\($0)") }
        let deck = try Deck(learningOptions: options, cards: cards)
        // The plan is all of it, whatever the size of a session is.
        let counts = try taken(cards, options: options)
        #expect(counts.learning == 3)
        #expect(counts.review == 10)
        #expect(counts.new == 10)
        #expect(counts.total == 23)
        // A session takes the learning cards, then the reviews, up to its size.
        var random = SeededRandom(seed: 1)
        let ids = StudySession.selectCards(from: deck, at: now, calendar: calendar, using: &random)
        let selected = ids.map { deck.card(withID: $0)! }
        #expect(selected.count == 5)
        #expect(selected.filter { $0.learningState?.phase == .learning }.count == 3)
        #expect(selected.filter { $0.learningState?.phase == .review }.count == 2)
        options.cardsPerSession = 15
        let wider = try Deck(learningOptions: options, cards: cards)
        random = SeededRandom(seed: 1)
        let widerSelected = StudySession.selectCards(from: wider, at: now, calendar: calendar, using: &random).map { wider.card(withID: $0)! }
        #expect(widerSelected.filter { $0.learningState?.phase == .review }.count == 10)
        #expect(widerSelected.filter(\.isNew).count == 2)
        #expect(widerSelected.count == 15)
    }

    @Test func countsMatchTheSessionOfADeckWithEveryKindOfCard() throws {
        var options = LearningOptions()
        options.cardsPerSession = nil
        options.newCardsPerSession = 10
        options.newProductionPerSession = 4
        var cards: [Card] = []
        for index in 0..<30 {
            cards.append(fresh("r\(index)", note: "n\(index)", kind: .recognition))
            cards.append(index < 15 ? review("p\(index)", note: "n\(index)", kind: .production) : fresh("p\(index)", note: "n\(index)", kind: .production))
        }
        cards += (0..<12).map { review("x\($0)", note: "x\($0)", kind: .recognition, interval: 30, dueInDays: -1) }
        cards += (0..<12).map { learning("l\($0)", note: "n\($0)") }
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
        #expect(expected.newOther <= 10)
        #expect(expected.newProduction <= 4)
    }

    @Test func nextDueIsTheFirstLaterDateOrTheNextStudyDayOfABuriedCard() throws {
        #expect(try taken([fresh("n")]).nextDue == nil)
        #expect(try taken([review("later", dueInDays: 2), learning("soon", dueIn: 600)]).nextDue == now.addingTimeInterval(600))
        var suspended = review("suspended", dueInDays: 1)
        suspended.isSuspended = true
        #expect(try taken([suspended]).nextDue == nil)

        var options = options()
        options.productionUnlockDays = 0
        let both = [review("r", note: "n", kind: .recognition), review("p", note: "n", kind: .production)]
        let tomorrow = calendar.start(ofDay: calendar.dayNumber(for: now) + 1)
        // One of the siblings is asked, the other is buried until tomorrow.
        #expect(try taken(both, options: options).nextDue == tomorrow)
        #expect(try taken(both + [learning("soon", dueIn: 600)], options: options).nextDue == now.addingTimeInterval(600))
    }
}
