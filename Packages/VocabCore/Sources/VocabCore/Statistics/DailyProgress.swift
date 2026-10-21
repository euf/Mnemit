import Foundation

/// The daily goal behind the rings and the streak, derived from review logs alone:
/// nothing is stored, so every device that reads the deck files shows the same.
///
/// A study day asks for `reviewsPerDay` graded reviews, or for the whole plan if that is
/// smaller (`goal(reviews:owed:)`). Reviews count in every mode: the plan, review ahead
/// and anything else a study stream reviews as a card. Practice changes no card and
/// writes no review, so it isn't in a log and doesn't count.
public enum DailyGoal {
    /// Graded reviews a study day asks.
    public static let reviewsPerDay = 20
    /// Graded reviews on the day after a single missed day that make up for it.
    public static let repairReviews = 40

    /// The goal of a study day on which `reviews` were graded and `owed` cards of its plan
    /// still wait: the plan as the day had it, `reviews + owed`, but at least 1 and at
    /// most `reviewsPerDay`. A review that takes a card out of the plan takes one from
    /// `owed` and adds one to `reviews`, so the goal stays; a review that leaves the card
    /// in the plan, an Again, raises it by one.
    public static func goal(reviews: Int, owed: Int) -> Int {
        min(reviewsPerDay, max(1, reviews + owed))
    }
}

/// The ring of a study day: reviews against the goal. The ring is full at the goal and goes
/// on filling in laps, as the Fitness rings do at 200 % and 300 %.
public struct DailyRing: Hashable, Sendable {
    public var reviews: Int
    public var goal: Int

    public init(reviews: Int, goal: Int) {
        self.reviews = max(0, reviews)
        self.goal = max(1, goal)
    }

    /// 0.5 at half the goal, 2.25 in the third lap.
    public var fraction: Double { Double(reviews) / Double(goal) }

    public var isGoalMet: Bool { reviews >= goal }

    /// How many times the goal has been reached: 2 from 200 %.
    public var laps: Int { reviews / goal }
}

/// The days in a row on which the goal was met.
public struct Streak: Hashable, Sendable {
    /// Study days in the streak, today's included once its goal is met. Counts a single
    /// missed day that the reviews of the day after it made up for.
    public var days: Int
    /// Reviews today that would make up for the single day missed yesterday and keep the
    /// streak; `nil` if no day is missed or the reviews are done. The streak ends if today
    /// ends without them.
    public var repairReviews: Int?

    public init(days: Int, repairReviews: Int?) {
        self.days = days
        self.repairReviews = repairReviews
    }

    /// How the streak stands. A day is met with `DailyGoal.reviewsPerDay` reviews, or with
    /// fewer if nothing was left of its plan (`owed(day) == 0`). One day missed between
    /// two met days is made up by `DailyGoal.repairReviews` reviews on the day after
    /// it: both days count. Two missed days in a row end the streak. Today is only
    /// judged by its own goal, so a day still going never breaks the streak.
    ///
    /// - Parameters:
    ///   - reviews: Graded reviews by study day; days without any are missed.
    ///   - today: The study day now.
    ///   - owed: The cards of the plan that were left at the end of a study day, for
    ///     today the plan now. Only asked for a day with fewer reviews than the goal at
    ///     most, and at least one.
    public static func evaluate(reviews: [Int: Int], today: Int, owed: (Int) -> Int) -> Streak {
        func isMet(_ day: Int) -> Bool {
            let count = reviews[day] ?? 0
            return count >= DailyGoal.reviewsPerDay || (count > 0 && owed(day) == 0)
        }

        enum State {
            case idle
            case counting(days: Int)
            /// The day before was missed, after a streak of `daysBefore`.
            case missedOnce(daysBefore: Int)
        }
        var state = State.idle
        if let first = reviews.keys.filter({ $0 < today }).min() {
            for day in first..<today {
                if isMet(day) {
                    switch state {
                    case let .counting(days):
                        state = .counting(days: days + 1)
                    case let .missedOnce(daysBefore):
                        state = .counting(days: (reviews[day] ?? 0) >= DailyGoal.repairReviews ? daysBefore + 2 : 1)
                    case .idle:
                        state = .counting(days: 1)
                    }
                } else {
                    switch state {
                    case let .counting(days): state = .missedOnce(daysBefore: days)
                    case .missedOnce, .idle: state = .idle
                    }
                }
            }
        }

        let isTodayMet = isMet(today)
        switch state {
        case .idle:
            return Streak(days: isTodayMet ? 1 : 0, repairReviews: nil)
        case let .counting(days):
            return Streak(days: days + (isTodayMet ? 1 : 0), repairReviews: nil)
        case let .missedOnce(daysBefore):
            if (reviews[today] ?? 0) >= DailyGoal.repairReviews {
                return Streak(days: daysBefore + 2, repairReviews: nil)
            }
            return Streak(days: daysBefore, repairReviews: DailyGoal.repairReviews)
        }
    }
}

/// What one deck contributes to the daily goal: its review log by study day, and what its
/// plan still owed at the end of any day.
///
/// Holds the deck, which is a value that shares its storage.
public struct DeckActivity: Sendable {
    private let deck: Deck
    /// Graded reviews by study day.
    public let reviewsByDay: [Int: Int]

    public init(deck: Deck, calendar: StudyCalendar) {
        self.deck = deck
        reviewsByDay = Self.reviewsByDay(of: deck, calendar: calendar)
    }

    /// Counts the entries of every card's log. A day is looked up once per quarter of an
    /// hour: every time zone's offset, daylight saving time's included, is a multiple of
    /// 15 minutes, so a quarter never straddles the start of a study day, and a log of
    /// tens of thousands of reviews needs only a few thousand calendar calls.
    private static func reviewsByDay(of deck: Deck, calendar: StudyCalendar) -> [Int: Int] {
        var counts: [Int: Int] = [:]
        var dayOfQuarter: [Int: Int] = [:]
        for card in deck.cards {
            for entry in card.log {
                let quarter = Int((entry.date.timeIntervalSince1970 / 900).rounded(.down))
                let day: Int
                if let known = dayOfQuarter[quarter] {
                    day = known
                } else {
                    day = calendar.dayNumber(for: entry.date)
                    dayOfQuarter[quarter] = day
                }
                counts[day, default: 0] += 1
            }
        }
        return counts
    }

    /// The cards of the plan still waiting at the end of study day `day`, or now for the
    /// day of `now`: `StudySession.counts(for:at:calendar:)`, so burying, limits and
    /// the lock count as they did that day. It looks at the deck as it is now: a card
    /// that was due on `day` and has been reviewed since no longer shows as left over,
    /// and a day left unfinished counts as done once its cards are caught up.
    public func owed(onDayOf day: Int, now: Date, calendar: StudyCalendar) -> Int {
        let endOfDay = calendar.start(ofDay: day + 1).addingTimeInterval(-1)
        return StudySession.counts(for: deck, at: min(now, endOfDay), calendar: calendar).total
    }
}

/// The ring and the streak of a learner over some decks, see `evaluate(_:at:calendar:)`.
public struct DailyProgress: Hashable, Sendable {
    public var ring: DailyRing
    public var streak: Streak

    public init(ring: DailyRing, streak: Streak) {
        self.ring = ring
        self.streak = streak
    }

    /// Adds up the reviews and the plans of all `decks`: one ring and one streak for the
    /// learner, however many decks they study.
    public static func evaluate(_ decks: [DeckActivity], at now: Date, calendar: StudyCalendar) -> DailyProgress {
        let today = calendar.dayNumber(for: now)
        var reviews: [Int: Int] = [:]
        for deck in decks {
            reviews.merge(deck.reviewsByDay, uniquingKeysWith: +)
        }
        var owedByDay: [Int: Int] = [:]
        func owed(_ day: Int) -> Int {
            if let known = owedByDay[day] { return known }
            let total = decks.reduce(0) { $0 + $1.owed(onDayOf: day, now: now, calendar: calendar) }
            owedByDay[day] = total
            return total
        }

        let streak = Streak.evaluate(reviews: reviews, today: today, owed: owed)
        let count = reviews[today] ?? 0
        return DailyProgress(ring: DailyRing(reviews: count, goal: DailyGoal.goal(reviews: count, owed: owed(today))), streak: streak)
    }
}
