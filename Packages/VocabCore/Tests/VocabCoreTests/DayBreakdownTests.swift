import Foundation
import Testing

@testable import VocabCore

/// What the figures of the day are made of (`DayBreakdown`), against the progress the same decks give.
extension DailyProgressTests {
    func breakdown(_ decks: [Deck], at date: Date? = nil) -> (progress: DailyProgress, breakdown: DayBreakdown) {
        let activities = decks.map { DeckActivity(deck: $0, calendar: calendar) }
        let progress = DailyProgress.evaluate(activities, at: date ?? now, calendar: calendar, planRuleStart: .min)
        return (progress, DayBreakdown(activities, progress: progress, at: date ?? now, calendar: calendar))
    }

    @Test func thePlanIsToldInItsPartsAndTheBacklogByItsShare() throws {
        let start = calendar.start(ofDay: today)
        let learning = LearningState(phase: .learning, stability: 1, difficulty: 5, lastReview: start.addingTimeInterval(-7200), due: start.addingTimeInterval(-3600), reviews: 1)
        let cards =
            (0..<10).map { waiting("r\($0)") } + (0..<30).map { waiting("o\($0)", onDay: today - 3) } + [Card(question: "l", answer: "l", learningState: learning)]
            + (0..<40).map { fresh("n\($0)") }
        let (progress, breakdown) = breakdown([try Deck(learningOptions: options(), cards: cards)])
        // 30 are overdue, 10 are due on the day: it takes as many as a normal day asks, ten, and leaves 20.
        #expect(breakdown.plan.reviewsDue == 10)
        #expect(breakdown.plan.backlogTaken == 10)
        #expect(breakdown.plan.backlog == 30)
        #expect(breakdown.plan.learning == 1)
        #expect(breakdown.catchUp == 20)
        // Two rounds are 240 s; 21 cards at 10 s leave 30 s, which is one new card of 30 s.
        #expect(breakdown.plan.newAdmitted == 1)
        #expect(breakdown.decks == [DayBreakdown.DeckNewCards(allowance: 1, ceiling: 40, admitted: 1)])
        #expect(progress.newCardAllowances == [1])
        #expect(progress.ring.goal == breakdown.plan.reviewsDue + breakdown.plan.backlogTaken + breakdown.plan.learning + breakdown.plan.newAdmitted)
    }

    @Test func aDecksCeilingIsWhatItsLimitsTakeAndItAdmitsNoMoreThanThat() throws {
        var options = options()
        options.newCardsPerSession = 5
        let (_, breakdown) = breakdown([try Deck(learningOptions: options, cards: (0..<20).map { fresh("n\($0)") })])
        #expect(breakdown.decks == [DayBreakdown.DeckNewCards(allowance: 5, ceiling: 5, admitted: 5)])
    }

    @Test func theLastDaysTellWhatTheRingAskedWhatWasWorkedAndWhy() throws {
        var deck = try Deck(learningOptions: options(), cards: (0..<400).map { fresh("n\($0)") })
        for offset in 0..<9 where offset != 6 { study(&deck, onDay: today - 9 + offset) }
        let early = at(day: today, hour: 5)
        let (progress, breakdown) = breakdown([deck], at: early)
        let days = breakdown.days
        #expect(days.count == 10)
        #expect(days.first?.reason == .start && days.first?.time == DailyGoal.initialSeconds)
        // The seventh day was not studied: no work, an open ring; the day after it asks what it asked.
        #expect(days[6].worked == 0 && !days[6].isClosed)
        #expect(days[7].reason == .median && days[7].time == days[6].time)
        // Told from the days the progress stepped through: the same times and work, the last as today's.
        #expect(days.map(\.time) == progress.ringDays.map(\.time))
        #expect(days.map(\.worked) == progress.ringDays.map(\.worked))
        #expect(days.map(\.reason) == progress.ringDays.map(\.reason))
        #expect(days.last?.time == progress.time && days.last?.isClosed == progress.ring.isGoalMet)
        #expect(days.map(\.start) == (today - 9...today).map { calendar.start(ofDay: $0) })
        let shorter = DayBreakdown([DeckActivity(deck: deck, calendar: calendar)], progress: progress, at: early, calendar: calendar, lastDays: 3)
        #expect(shorter.days == Array(days.suffix(3)))
    }

    @Test func aLearnerWithNoHistoryHasTodayAloneAndNothingToPrice() throws {
        let (progress, breakdown) = breakdown([try Deck(learningOptions: options(), cards: (0..<5).map { fresh("n\($0)") })])
        #expect(breakdown.days.count == 1)
        #expect(breakdown.days[0].time == DailyGoal.initialSeconds && !breakdown.days[0].isClosed)
        #expect(breakdown.newCards.source == .fallback && breakdown.otherCards.source == .fallback)
        #expect(breakdown.newCards.reviewsPerCard == nil)
        #expect(progress.pace == Pace())
    }

    /// `count` cards new on the day before today, each learned with two Goods that took `duration` each.
    func learnedYesterday(_ count: Int, duration: Duration?) throws -> Deck {
        let cards = (0..<count).map { index in
            answered("w\(index)", [.good, .good], at: [at(1, 10, Double(index) * 2), at(1, 10, Double(index) * 2 + 1)], duration: duration)
        }
        return try Deck(learningOptions: options(), cards: cards)
    }

    @Test func thePriceOfANewCardNamesItsSourceAndTheReviewsEachDoneCardTook() throws {
        // 12 done cards with 24 reviews, all timed: the price is the logged 4 s, twice for each card.
        let timed = breakdown([try learnedYesterday(12, duration: .seconds(4))])
        #expect(timed.breakdown.newCards == DayBreakdown.PaceBasis(durations: 24, gaps: 23, reviews: 24, doneCards: 12))
        #expect(timed.breakdown.newCards.source == .durations)
        #expect(timed.breakdown.newCards.reviewsPerCard == 2)
        #expect(abs(timed.progress.pace.newCard - 8) < 1e-9)
        // The same log without durations is priced by the gaps between its reviews.
        let gapped = breakdown([try learnedYesterday(12, duration: nil)])
        #expect(gapped.breakdown.newCards == DayBreakdown.PaceBasis(durations: 0, gaps: 23, reviews: 24, doneCards: 12))
        #expect(gapped.breakdown.newCards.source == .gaps)
        #expect(gapped.progress.pace.newCard != DailyGoal.fallbackNewCardSeconds)
        // Nine done cards are too few: the price is the default, whatever the log holds.
        let few = breakdown([try learnedYesterday(9, duration: .seconds(4))])
        #expect(few.breakdown.newCards.source == .fallback)
        #expect(few.progress.pace.newCard == DailyGoal.fallbackNewCardSeconds)
        // No other card was done: its price is the default and it has no reviews per card.
        #expect(timed.breakdown.otherCards == DayBreakdown.PaceBasis(durations: 0, gaps: 0, reviews: 0, doneCards: 0))
        #expect(timed.progress.pace.otherCard == DailyGoal.fallbackOtherCardSeconds)
    }
}
