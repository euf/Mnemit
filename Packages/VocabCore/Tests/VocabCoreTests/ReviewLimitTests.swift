import Foundation
import Testing

@testable import VocabCore

/// Maximum reviews/day (`LearningOptions.maximumReviewsPerDay`): at most that many cards in the review phase
/// a study day, the reviews already made today counting against it; learning and new cards stay out of it.
struct ReviewLimitTests {
    let calendar = StudyCalendar.testing
    /// 2026-10-05 18:00 in Berlin.
    let now = Date(timeIntervalSince1970: 1_791_216_000)
    var today: Int { calendar.dayNumber(for: now) }

    func deck(_ cards: [Card], limit: Int? = nil, newPerDay: Int? = nil) throws -> Deck {
        var options = LearningOptions()
        options.fuzzing = false
        options.maximumReviewsPerDay = limit
        options.newCardsPerSession = newPerDay
        return try Deck(learningOptions: options, cards: cards)
    }

    /// A review card due `overdue` days ago: the more overdue, the less it is remembered, the more urgent it is. Its
    /// log doesn't reach back to its first review, as after an import: it counts as a review card from the start.
    func review(_ name: String, overdue: Int = 1, note: String? = nil) -> Card {
        Card(
            question: name, answer: name, note: note,
            learningState: LearningState(
                phase: .review, stability: 10, difficulty: 5, lastReview: now.addingTimeInterval(-Double(10 + overdue) * 86400),
                due: now.addingTimeInterval(-Double(overdue) * 86400), reviews: 5))
    }

    func reviews(_ count: Int) -> [Card] {
        (0..<count).map { review("r\($0)", overdue: $0 * 30 + 1) }
    }

    func learning(_ count: Int) -> [Card] {
        (0..<count).map {
            Card(
                question: "l\($0)", answer: "l\($0)",
                learningState: LearningState(phase: .learning, stability: 1, difficulty: 5, lastReview: now.addingTimeInterval(-600), due: now.addingTimeInterval(-60)))
        }
    }

    /// Grades the cards of the plan at `time` with `grade`, as a session does, and returns what the plan promised.
    @discardableResult
    func study(_ deck: inout Deck, at time: Date, grade: Grade = .good, stoppingAfter limit: Int = .max) -> StudyCounts {
        let counts = StudySession.counts(for: deck, at: time, calendar: calendar)
        var study = StudySession(deck: deck, at: time, calendar: calendar, random: SeededRandom(seed: 1))
        #expect(study.session.totalCount == counts.total)
        var done = 0
        while done < limit, let id = study.session.currentCardID {
            let card = study.review(grade, of: deck.card(withID: id)!, with: deck.learningOptions, at: time, calendar: calendar)!
            deck.cards[deck.index(of: id)!] = card
            done += 1
        }
        return counts
    }

    @Test func noLimitAsksEveryReviewThatIsDue() throws {
        let deck = try deck(reviews(12))
        #expect(deck.learningOptions.maximumReviewsPerDay == nil)
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).review == 12)
    }

    @Test func theLimitCapsTheReviewsAndKeepsTheMostUrgent() throws {
        let deck = try deck(reviews(12), limit: 5)
        let counts = StudySession.counts(for: deck, at: now, calendar: calendar)
        #expect(counts.review == 5)
        #expect(counts.total == 5)
        // The longest overdue cards, the most forgotten, are the ones taken.
        var random = SeededRandom(seed: 1)
        let taken = StudySession.selectCards(from: deck, at: now, calendar: calendar, using: &random)
        #expect(Set(taken) == Set(deck.cards.filter { ["r7", "r8", "r9", "r10", "r11"].contains($0.question) }.map(\.id)))
        // The cards left over are due still, and the deck says when the rest comes back: the next study day.
        #expect(counts.due == 12)
        #expect(counts.nextDue == calendar.start(ofDay: today + 1))
    }

    @Test func aLimitAboveTheDueReviewsChangesNothing() throws {
        let capped = try deck(reviews(4), limit: 50)
        let open = try deck(reviews(4))
        #expect(StudySession.counts(for: capped, at: now, calendar: calendar) == StudySession.counts(for: open, at: now, calendar: calendar))
    }

    @Test func theStreamAndTheCountsAgree() throws {
        let deck = try deck(reviews(12), limit: 5)
        let stream = StudyStream(deck: deck, at: now, calendar: calendar)
        #expect(stream.session.totalCount == 5)
    }

    @Test func reviewsMadeTodayCountAgainstTheLimit() throws {
        var deck = try deck(reviews(8), limit: 5)
        // The first session takes five and grades them Good: they go to later days.
        #expect(study(&deck, at: now).review == 5)
        // The same day, an hour on: nothing is left, however many reviews wait.
        let later = now.addingTimeInterval(3600)
        #expect(StudySession.counts(for: deck, at: later, calendar: calendar).total == 0)
        #expect(study(&deck, at: later).total == 0)
        // The next study day asks the three that waited, the limit whole again.
        let tomorrow = calendar.start(ofDay: today + 1).addingTimeInterval(3600)
        #expect(study(&deck, at: tomorrow).review == 3)
        #expect(deck.cards.filter { $0.learningState!.lastReview > now.addingTimeInterval(-3600) }.count == 8)
    }

    @Test func aSessionStoppedHalfwayLeavesTheRestOfTheLimit() throws {
        var deck = try deck(reviews(8), limit: 5)
        study(&deck, at: now, stoppingAfter: 2)
        #expect(StudySession.counts(for: deck, at: now.addingTimeInterval(60), calendar: calendar).review == 3)
    }

    @Test func aLapseCountsAndItsRelearningDoesNot() throws {
        var deck = try deck(reviews(8), limit: 3)
        // Forgot on three review cards: each is a review of the day, and each goes into relearning.
        let scheduler = Scheduler(learningOptions: deck.learningOptions, calendar: calendar)
        var random = SeededRandom(seed: 1)
        for index in 0..<3 { deck.cards[index] = scheduler.review(deck.cards[index], grade: .again, at: now, using: &random) }
        let counts = StudySession.counts(for: deck, at: now.addingTimeInterval(60), calendar: calendar)
        #expect(counts.review == 0)
        // The relearning cards are due and asked: the limit does not hold them back.
        #expect(counts.learning == 3)
    }

    @Test func cardsInLearningAndNewCardsAreNotPartOfTheLimit() throws {
        let new = (0..<6).map { Card(question: "n\($0)", answer: "n\($0)", note: "n\($0)") }
        let deck = try deck(reviews(6) + learning(4) + new, limit: 2, newPerDay: 3)
        let counts = StudySession.counts(for: deck, at: now, calendar: calendar)
        #expect(counts.review == 2)
        #expect(counts.learning == 4)
        #expect(counts.new == 3)
    }

    @Test func theFirstReviewsOfACardAreInLearningAndDoNotCount() throws {
        var deck = try deck([Card(question: "a", answer: "a")] + reviews(3), limit: 3)
        // A new card with two steps: Good, Good, and it is a review card, but both reviews were of a card in learning.
        let scheduler = Scheduler(learningOptions: deck.learningOptions, calendar: calendar)
        var random = SeededRandom(seed: 1)
        for _ in 0..<2 { deck.cards[0] = scheduler.review(deck.cards[0], grade: .good, at: now, using: &random) }
        #expect(deck.cards[0].learningState?.phase == .review)
        #expect(deck.cards[0].reviewPhaseReviews(onDayOf: now, calendar: calendar, steps: 2) == 0)
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).review == 3)
    }

    @Test func reviewPhaseReviewsReplayThePhaseFromTheGrades() {
        let day = now
        let lastWeek = now.addingTimeInterval(-7 * 86400)
        var card = Card(
            question: "a", answer: "a",
            learningState: LearningState(phase: .review, stability: 5, difficulty: 5, lastReview: day, due: day.addingTimeInterval(5 * 86400), reviews: 4, lapses: 1))
        // Learning (Good, Good), a review a week ago, then today a lapse and its relearning (Good, Good).
        card.log = [
            ReviewLogEntry(date: lastWeek.addingTimeInterval(-86400), grade: .good), ReviewLogEntry(date: lastWeek.addingTimeInterval(-86400 + 60), grade: .good),
            ReviewLogEntry(date: lastWeek, grade: .good),
            ReviewLogEntry(date: day.addingTimeInterval(-300), grade: .again), ReviewLogEntry(date: day.addingTimeInterval(-200), grade: .good),
            ReviewLogEntry(date: day.addingTimeInterval(-100), grade: .good),
        ]
        card.learningState?.reviews = card.log.count
        #expect(card.hasCompleteLog)
        #expect(card.reviewPhaseReviews(onDayOf: day, calendar: calendar, steps: 2) == 1)
        #expect(card.reviewPhaseReviews(onDayOf: lastWeek, calendar: calendar, steps: 2) == 1)
        #expect(card.reviewPhaseReviews(onDayOf: day.addingTimeInterval(86400), calendar: calendar, steps: 2) == 0)
        // A log that doesn't reach back to the first review starts as a review card.
        card.learningState?.reviews = 40
        #expect(card.reviewPhaseReviews(onDayOf: day, calendar: calendar, steps: 2) == 1)
    }

    @Test func aPastDaysPlanHasNothingReviewedYet() throws {
        var deck = try deck(reviews(8), limit: 5)
        study(&deck, at: now)
        // The live plan has used the limit up; the plan of a day seen from its start (`past`) asks the three that waited.
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).review == 0)
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar, past: StudySession.DayIndex(lockedNotes: [])).review == 3)
    }

    @Test func theOptionIsClampedLikeTheOthers() throws {
        var options = LearningOptions()
        options.maximumReviewsPerDay = 0
        #expect(try Deck(learningOptions: options, cards: []).learningOptions.maximumReviewsPerDay == LearningOptions.reviewLimitRange.lowerBound)
        options.maximumReviewsPerDay = 100_000
        #expect(try Deck(learningOptions: options, cards: []).learningOptions.maximumReviewsPerDay == LearningOptions.reviewLimitRange.upperBound)
        options.maximumReviewsPerDay = nil
        #expect(try Deck(learningOptions: options, cards: []).learningOptions.maximumReviewsPerDay == nil)
    }

    @Test func restoringDefaultsKeepsWhatTheReviewsMadeAndThePause() {
        var options = LearningOptions()
        options.targetRecall = 0.8
        options.maximumInterval = 365
        options.steps = 4
        options.newCardsPerSession = 12
        options.maximumReviewsPerDay = 150
        options.fuzzing = false
        options.leechThreshold = 0
        options.leechAction = .suspend
        options.updatesParametersAutomatically = false
        options.parameters = FSRSParameters([Double](repeating: 0.5, count: FSRSParameters.count))!
        options.lastAutoFit = LearningOptions.AutoFit(date: now, reviewCount: 900, adopted: true)
        options.isPaused = true

        let restored = options.restoringDefaults()
        var expected = LearningOptions()
        expected.parameters = options.parameters
        expected.lastAutoFit = options.lastAutoFit
        expected.isPaused = true
        #expect(restored == expected)
        #expect(restored.maximumReviewsPerDay == nil)
        #expect(LearningOptions().restoringDefaults() == LearningOptions())
    }
}
