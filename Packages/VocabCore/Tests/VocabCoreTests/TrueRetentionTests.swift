import Foundation
import Testing

@testable import VocabCore

struct TrueRetentionTests {
    typealias Step = (date: Date, grade: Grade, mode: ReviewMode)

    let calendar = StudyCalendar.testing
    /// Wednesday, 2026-10-21 12:00 in Berlin: study day 2026-10-21.
    let now: Date
    let today: Int

    init() {
        now = Self.berlin(10, 21, 12)
        today = calendar.dayNumber(for: now)
    }

    static func berlin(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0, year: Int = 2026) -> Date {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = StudyCalendar.testing.timeZone
        return gregorian.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Noon of the study day `days` before today.
    func noon(daysAgo days: Int) -> Date {
        calendar.start(ofDay: today - days).addingTimeInterval(8 * 3600)
    }

    /// One step in a card's life; the mode defaults to typed.
    func step(_ date: Date, _ grade: Grade, _ mode: ReviewMode = .typed) -> Step {
        (date, grade, mode)
    }

    /// Without fuzz, and with a first interval of 20 days after `.good` and 21 after
    /// `.easy`, the two sides of the young/mature threshold.
    func options(steps: Int = 1, targetRecall: Double = 0.9) -> LearningOptions {
        var options = LearningOptions()
        options.steps = steps
        options.fuzzing = false
        options.targetRecall = targetRecall
        var weights = FSRSParameters.default.weights
        weights[2] = 20
        weights[3] = 21
        options.parameters = FSRSParameters(weights)!
        return options
    }

    /// A card that went through `steps` under `options`, with its real log and learning state.
    func card(_ steps: [Step], kind: CardKind? = nil, options: LearningOptions? = nil) -> Card {
        let scheduler = Scheduler(learningOptions: options ?? self.options(), calendar: calendar)
        var card = Card(question: "q", answer: "a", kind: kind)
        for step in steps {
            var random = SeededRandom(seed: 0)
            card = scheduler.review(card, grade: step.grade, at: step.date, mode: step.mode, using: &random)
        }
        return card
    }

    func retention(of cards: [Card], options: LearningOptions? = nil) throws -> TrueRetention {
        try TrueRetention(of: Deck(learningOptions: options ?? self.options(), cards: cards), at: now, calendar: calendar)
    }

    /// The periods that count a review of a review-phase card at `date`, a week after its first.
    func periods(ofReviewAt date: Date) throws -> [TrueRetention.Period] {
        let reviewed = card([step(date.addingTimeInterval(-7 * 86400), .good), step(date, .good)])
        let retention = try retention(of: [reviewed])
        return TrueRetention.Period.allCases.filter { retention.all[$0].total.reviews == 1 }
    }

    // MARK: - What counts

    @Test func reviewPhaseReviewsPassOrFail() throws {
        let reviewed = card([
            step(noon(daysAgo: 30), .good),  // new card: not counted
            step(noon(daysAgo: 10), .good),  // review phase, interval 20: young, passed
            step(noon(daysAgo: 5), .again),  // review phase, interval of weeks: mature, failed
            step(noon(daysAgo: 5), .good),  // relearning: not counted
            step(noon(daysAgo: 2), .hard),  // review phase, short interval: young, passed
        ])
        let retention = try retention(of: [reviewed])
        let split = retention.all[.last365Days]
        #expect(split.young == TrueRetention.Tally(passed: 2, failed: 0))
        #expect(split.mature == TrueRetention.Tally(passed: 0, failed: 1))
        #expect(split.total.reviews == 3)
        #expect(split.total.retention == 2.0 / 3)
    }

    @Test func learningStepsAndFirstReviewsAreNotCounted() throws {
        let options = options(steps: 2)
        let graduatesAtOnce = card(
            [
                step(noon(daysAgo: 10), .good),  // new
                step(noon(daysAgo: 10), .good),  // second step of learning
                step(noon(daysAgo: 5), .good),  // review phase: the only one counted
            ], options: options)
        let graduatesNextDay = card(
            [
                step(noon(daysAgo: 9), .good),  // new
                step(noon(daysAgo: 8), .good),  // learning, a day later: still a step
            ], options: options)
        let retention = try retention(of: [graduatesAtOnce, graduatesNextDay], options: options)
        #expect(retention.all[.last365Days].total == TrueRetention.Tally(passed: 1, failed: 0))
    }

    @Test func aRepeatOnTheSameStudyDayIsNotCounted() throws {
        let reviewed = card([
            step(noon(daysAgo: 10), .good),
            step(Self.berlin(10, 18, 8), .good),
            step(Self.berlin(10, 18, 20), .good),
        ])
        #expect(try retention(of: [reviewed]).all[.last365Days].total.reviews == 1)
    }

    /// The rollover at 4 AM puts a late-night review on the study day before.
    @Test func reviewsAroundTheRolloverAreOnDifferentStudyDays() throws {
        let reviewed = card([
            step(noon(daysAgo: 10), .good),
            step(Self.berlin(10, 18, 3, 30), .good),
            step(Self.berlin(10, 18, 4, 30), .good),
        ])
        #expect(try retention(of: [reviewed]).all[.last365Days].total.reviews == 2)
    }

    @Test func cardsWithIncompleteLogsAreLeftOut() throws {
        var imported = card([step(noon(daysAgo: 10), .good), step(noon(daysAgo: 5), .good)])
        // Reviews before the log began: the log is shorter than the review count.
        imported.learningState?.reviews = 6
        #expect(!imported.hasCompleteLog)
        #expect(try retention(of: [imported]).all[.last365Days].total.reviews == 0)
    }

    @Test func aDeckWithoutReviewsHasNoRetention() throws {
        let retention = try retention(of: [Card(question: "q", answer: "a")])
        for period in TrueRetention.Period.allCases {
            #expect(retention.all[period] == TrueRetention.Split())
            #expect(retention.all[period].total.retention == nil)
        }
        #expect(retention.byMode.isEmpty)
        #expect(retention.byKind.isEmpty)
    }

    // MARK: - Periods

    @Test func periodsFollowTheStudyDay() throws {
        // Study day 2026-10-21 starts at 04:00.
        #expect(try periods(ofReviewAt: Self.berlin(10, 21, 4)) == [.today, .last7Days, .last30Days, .last365Days])
        #expect(try periods(ofReviewAt: Self.berlin(10, 21, 3, 59)) == [.yesterday, .last7Days, .last30Days, .last365Days])
        #expect(try periods(ofReviewAt: Self.berlin(10, 20, 4)) == [.yesterday, .last7Days, .last30Days, .last365Days])
        #expect(try periods(ofReviewAt: Self.berlin(10, 20, 3, 59)) == [.last7Days, .last30Days, .last365Days])
        // Today and the six study days before it make 7 days.
        #expect(try periods(ofReviewAt: Self.berlin(10, 15, 12)) == [.last7Days, .last30Days, .last365Days])
        #expect(try periods(ofReviewAt: Self.berlin(10, 14, 12)) == [.last30Days, .last365Days])
        #expect(try periods(ofReviewAt: Self.berlin(9, 22, 12)) == [.last30Days, .last365Days])
        #expect(try periods(ofReviewAt: Self.berlin(9, 21, 12)) == [.last365Days])
        #expect(try periods(ofReviewAt: Self.berlin(10, 22, 12, year: 2025)) == [.last365Days])
        #expect(try periods(ofReviewAt: Self.berlin(10, 21, 12, year: 2025)) == [])
        // A review after now, e.g. from a device with a wrong clock, belongs to no period.
        #expect(try periods(ofReviewAt: Self.berlin(10, 22, 12)) == [])
    }

    // MARK: - Young and mature

    @Test func theIntervalThresholdSplitsYoungFromMature() throws {
        let young = card([step(noon(daysAgo: 8), .good), step(noon(daysAgo: 4), .good)])
        let mature = card([step(noon(daysAgo: 8), .easy), step(noon(daysAgo: 4), .good)])
        let matureFailed = card([step(noon(daysAgo: 8), .easy), step(noon(daysAgo: 4), .again)])
        // The first review gave intervals of 20 and 21 days, see the next test.
        let retention = try retention(of: [young, mature, matureFailed])
        let split = retention.all[.last7Days]
        #expect(split.young == TrueRetention.Tally(passed: 1, failed: 0))
        #expect(split.mature == TrueRetention.Tally(passed: 1, failed: 1))
        #expect(split.total.retention == 2.0 / 3)
        #expect(retention.all[.today].total.reviews == 0)
    }

    @Test func aFirstIntervalOf20DaysIsYoungAndOf21Mature() throws {
        let options = options()
        let scheduler = Scheduler(learningOptions: options, calendar: calendar)
        var random = SeededRandom(seed: 0)
        let good = try #require(scheduler.review(Card(question: "q", answer: "a"), grade: .good, at: noon(daysAgo: 8), using: &random).learningState)
        let easy = try #require(scheduler.review(Card(question: "q", answer: "a"), grade: .easy, at: noon(daysAgo: 8), using: &random).learningState)
        #expect(calendar.days(from: good.lastReview, to: good.due) == 20)
        #expect(calendar.days(from: easy.lastReview, to: easy.due) == 21)
    }

    // MARK: - Mode and kind

    @Test func modeAndKindSplitTheSameFigures() throws {
        let cards = [
            card([step(noon(daysAgo: 8), .good), step(noon(daysAgo: 4), .good, .typed)], kind: .recognition),
            card([step(noon(daysAgo: 8), .good), step(noon(daysAgo: 4), .again, .revealed)], kind: .production),
            card([step(noon(daysAgo: 8), .good, .revealed), step(noon(daysAgo: 4), .good, .revealed)]),
        ]
        let retention = try retention(of: cards)
        #expect(retention.all[.last7Days].total == TrueRetention.Tally(passed: 2, failed: 1))
        // The mode of a review is the one of the review itself, not of the card's first.
        #expect(retention.byMode[.typed]?[.last7Days].total == TrueRetention.Tally(passed: 1, failed: 0))
        #expect(retention.byMode[.revealed]?[.last7Days].total == TrueRetention.Tally(passed: 1, failed: 1))
        #expect(retention.byKind[.recognition]?[.last7Days].total == TrueRetention.Tally(passed: 1, failed: 0))
        #expect(retention.byKind[.production]?[.last7Days].total == TrueRetention.Tally(passed: 0, failed: 1))
        #expect(retention.byKind.count == 2)
        #expect(retention.byMode[.typed]?[.today].total.retention == nil)
    }

    @Test func desiredRetentionIsTheDecksTarget() throws {
        let retention = try retention(of: [], options: options(targetRecall: 0.85))
        #expect(retention.desiredRetention == 0.85)
    }
}
