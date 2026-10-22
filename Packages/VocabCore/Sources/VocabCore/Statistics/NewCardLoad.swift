import Foundation

/// What new cards add to the cards of each day, for the line under "+10 new": a guess, not a
/// forecast. Every review is a Good, so each review in the simulation is one card due on that day.
public enum NewCardLoad {
    /// Days after the one a card is introduced on that the estimate looks at.
    public static let horizonDays = 7

    /// Reviews per day, averaged over the next `horizonDays` study days, that `count` cards
    /// introduced today add. Each card is simulated with the deck's scheduler, without
    /// fuzz: it takes its steps today, and then every review is a Good on the day it is
    /// due, so the intervals are the ones FSRS gives on the first reviews at the deck's
    /// target recall. Lapses are left out, which makes the estimate a little low: with a
    /// target recall of 90 % about one review in ten would add a relearning and a shorter
    /// interval.
    public static func reviewsPerDay(addingNewCards count: Int, options: LearningOptions, at now: Date, calendar: StudyCalendar) -> Double {
        guard count > 0 else { return 0 }
        return Double(count * reviewsOfOneCard(options: options, at: now, calendar: calendar)) / Double(horizonDays)
    }

    /// Reviews on the days 1 to `horizonDays` after today of a card introduced at `now`.
    static func reviewsOfOneCard(options: LearningOptions, at now: Date, calendar: StudyCalendar) -> Int {
        var options = options
        options.fuzzing = false
        let scheduler = Scheduler(learningOptions: options, calendar: calendar)
        // Never drawn from without fuzz.
        var random = SeededRandom(seed: 0)
        let today = calendar.dayNumber(for: now)

        var card = Card(question: "", answer: "", created: now)
        // Today: Good until the card leaves learning; `steps` is 5 at most.
        for _ in 0..<LearningOptions.stepsRange.upperBound where card.learningState?.phase != .review {
            card = scheduler.review(card, grade: .good, at: now, using: &random)
        }

        var reviews = 0
        while let due = card.learningState?.due, calendar.dayNumber(for: due) - today <= horizonDays {
            reviews += 1
            card = scheduler.review(card, grade: .good, at: due, using: &random)
        }
        return reviews
    }
}
