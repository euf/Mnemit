import Foundation
import Testing

@testable import VocabCore

/// The scheduling findings of the audit of 30.10.2026: the plan of a paused deck, the fuzz of a live review against the
/// replay of a merge, and what counts towards a leech.
struct SchedulingAuditTests {
    let now = Date(timeIntervalSince1970: 1_791_216_000)
    let calendar = StudyCalendar.testing

    // MARK: - A paused deck studied by itself

    func deck(paused: Bool = true, newCardsPerDay: Int? = nil, cards count: Int = 150) throws -> Deck {
        var options = LearningOptions()
        options.isPaused = paused
        options.newCardsPerSession = newCardsPerDay
        return try Deck(learningOptions: options, cards: (0..<count).map { Card(question: "q\($0)", answer: "a\($0)") })
    }

    /// The deck asks nothing of the day, so the ring has no allowance for it: its plan holds no new card by itself,
    /// and Learn 10 New Words offers the next ten.
    @Test func aPausedDeckOnAutoTakesNoNewCardsFromTheDay() throws {
        let deck = try deck()
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).new == 0)
        #expect(StudyStream.extraNewCards(in: deck, at: now, calendar: calendar) == StudyStream.newCardChunk)
    }

    @Test func aPausedDeckWithItsOwnNewCardsPerDayTakesThem() throws {
        #expect(StudySession.counts(for: try deck(newCardsPerDay: 7), at: now, calendar: calendar).new == 7)
    }

    @Test func aDeckThatIsNotPausedStillTakesTheLimitsOnly() throws {
        let deck = try deck(paused: false, cards: 30)
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).new == 30)
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar, newCardAllowance: 4).new == 4)
    }

    // MARK: - Live review and replay

    /// A merge replays the joined log; the card gets the due date the session set.
    @Test func aReplayGivesTheDueDateOfTheLiveReview() {
        let options = LearningOptions()
        let scheduler = Scheduler(learningOptions: options, calendar: calendar)
        for k in 0..<40 {
            let card = Card(question: "q\(k)", answer: "a")
            var study = StudySession(cardIDs: [card.id], at: now, random: SeededRandom(seed: UInt64(k)), reviewMode: .revealed)
            guard let live = study.review(.easy, of: card, with: options, at: now, calendar: calendar) else {
                Issue.record("no review")
                continue
            }
            #expect(scheduler.replaying(live.log, of: card).learningState?.due == live.learningState?.due)
        }
    }

    /// The seed of the session has no say in the interval: the same review in two sessions gives the same date.
    @Test func theDueDateDoesNotDependOnTheSessionSeed() {
        let options = LearningOptions()
        let card = Card(question: "q", answer: "a")
        let dues = (0..<10).compactMap { seed -> Date? in
            var study = StudySession(cardIDs: [card.id], at: now, random: SeededRandom(seed: UInt64(seed)), reviewMode: .revealed)
            return study.review(.easy, of: card, with: options, at: now, calendar: calendar)?.learningState?.due
        }
        #expect(dues.count == 10 && Set(dues).count == 1)
    }

    // MARK: - Leeches

    /// A new card answered `times` times with Forgot, a minute apart.
    func forgotten(_ times: Int) -> Card {
        var options = LearningOptions()
        options.fuzzing = false
        let scheduler = Scheduler(learningOptions: options, calendar: calendar)
        var random = SeededRandom(seed: 1)
        var card = Card(question: "q", answer: "a")
        for index in 0..<times {
            card = scheduler.review(card, grade: .again, at: now.addingTimeInterval(Double(index) * 60), using: &random)
        }
        return card
    }

    /// EF's card with 16 Forgots in 27 reviews had three lapses: the Forgots of the first showing, of learning and of
    /// relearning count, the first answer of a new card does not.
    @Test func forgotsOutsideTheReviewPhaseCountTowardsALeech() {
        let card = forgotten(9)
        #expect(card.learningState?.lapses == 0)
        #expect(card.forgotCount == 8)
        #expect(card.isLeech(threshold: 8))
        #expect(!card.isLeech(threshold: 9))
        #expect(!forgotten(8).isLeech(threshold: 8))
        #expect(!card.isLeech(threshold: 0))
    }

    @Test func aCardWithMoreLapsesThanItsLogShowsKeepsThem() {
        let state = LearningState(phase: .review, step: 0, stability: 5, difficulty: 5, lastReview: now, due: now, reviews: 30, lapses: 9)
        let imported = Card(question: "q", answer: "a", learningState: state, log: [ReviewLogEntry(date: now, grade: .good)])
        #expect(imported.forgotCount == 9)
        #expect(imported.isLeech(threshold: 8))
    }

    /// The leech moments of one more answer to `card`.
    func moments(of card: Card, grade: Grade = .again) -> [Card.ID] {
        var study = StudySession(cardIDs: [card.id], at: now, random: SeededRandom(seed: 3), reviewMode: .revealed)
        _ = study.review(grade, of: card, with: LearningOptions(), at: now.addingTimeInterval(86400 * 30), calendar: calendar)
        return study.session.leechIDs
    }

    /// The moment comes with the Forgot that reaches the threshold, then at every half threshold. A card that is a leech
    /// by its log already meets its moment at its next checkpoint (8, 12, 16, 20), not at the next Forgot and not
    /// before one: the first launch does not stop the stream for every old card.
    @Test func theLeechMomentFollowsTheForgotCount() {
        let seven = forgotten(8)
        #expect(seven.forgotCount == 7)
        #expect(moments(of: seven) == [seven.id])
        #expect(moments(of: forgotten(7)).isEmpty)
        #expect(moments(of: seven, grade: .good).isEmpty)
        let sixteen = forgotten(17)
        #expect(sixteen.forgotCount == 16)
        #expect(moments(of: sixteen).isEmpty)
        let nineteen = forgotten(20)
        #expect(nineteen.forgotCount == 19)
        #expect(moments(of: nineteen) == [nineteen.id])
    }
}
