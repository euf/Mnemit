import Foundation

/// The daily goal behind the rings and the streak, derived from review logs alone:
/// nothing is stored, so every device that reads the deck files shows the same.
///
/// The goal of a study day is its plan as FSRS sets it, what `StudySession.counts(for:at:calendar:)`
/// reports: the cards due that day, overdue ones included, and the new cards within the day's
/// limits. Only the backlog, the review cards that were already due before the day, asks a
/// share of itself (`backlogShare(of:onTime:)`), so an import or a long break doesn't pile a
/// thousand cards on one day. A day is met when its plan is done, an empty plan included:
/// nothing was due, so memory is where FSRS wants it. Reviews count in every mode: the
/// plan, catching up, review ahead and anything else a study stream reviews as a card.
/// Practice changes no card and writes no review, so it isn't in a log and doesn't count.
///
/// Everything that sets the size of a day is here: a cap on the goal, or another spread of
/// the backlog, is a change of this type.
public enum DailyGoal {
    /// The days over which a backlog is spread: each day asks one part of it.
    public static let backlogSpreadDays = 7

    /// What a day asks of a backlog of `backlog` overdue reviews, when `onTime` review cards
    /// are due on the day itself: its part of the spread, rounded up so that a backlog is
    /// always worked off, but at least what a normal day asks, `onTime`, so that a small
    /// backlog, one missed day's, is cleared in a day and leaves no week-long tail. Never more
    /// than the backlog.
    public static func backlogShare(of backlog: Int, onTime: Int) -> Int {
        let backlog = max(0, backlog)
        let spread = (backlog + backlogSpreadDays - 1) / backlogSpreadDays
        return min(backlog, max(spread, onTime))
    }

    /// The goal of a study day on which `reviews` were graded, `owed` answers of its plan still
    /// wait (`StudyCounts.answers`), and the plan asked `plan` answers when the day began.
    ///
    /// While the plan is open the goal is the work it asks: `reviews + owed`, at least `plan`.
    /// A Good that takes a card a step closer to leaving the plan takes one from `owed` and
    /// adds one to `reviews`, so the goal stays; an answer that sets a card back, an Again,
    /// raises it. Once the plan is done the goal is the plan: reviews beyond it, catching up
    /// and review ahead, don't move it, so the ring goes on in laps.
    public static func goal(reviews: Int, owed: Int, plan: Int) -> Int {
        owed > 0 ? max(plan, reviews + owed) : min(plan, reviews)
    }
}

/// The ring of a study day: reviews against the goal. The ring is full at the goal and goes
/// on filling in laps, as the Fitness rings do at 200 % and 300 %. A day whose plan is empty
/// has a goal of 0, which is met; the ring then counts a lap for each review.
public struct DailyRing: Hashable, Sendable {
    public var reviews: Int
    public var goal: Int

    public init(reviews: Int, goal: Int) {
        self.reviews = max(0, reviews)
        self.goal = max(0, goal)
    }

    /// 0.5 at half the goal, 2.25 in the third lap.
    public var fraction: Double { Double(reviews) / Double(max(1, goal)) }

    public var isGoalMet: Bool { reviews >= goal }

    /// How many times the goal has been reached: 2 from 200 %.
    public var laps: Int { reviews / max(1, goal) }
}

/// The days in a row on which the plan was done.
public struct Streak: Hashable, Sendable {
    /// Study days in the streak, today's included once its plan is done. Counts a single
    /// missed day that the plan of the day after it made up for.
    public var days: Int
    /// The cards of today's plan still to do that would make up for the single day missed
    /// yesterday and keep the streak; `nil` if no day is missed or the plan is done. The
    /// plan already holds what the missed day left over. The streak ends if today ends
    /// without them.
    public var repairCards: Int?

    public init(days: Int, repairCards: Int?) {
        self.days = days
        self.repairCards = repairCards
    }

    /// How the streak stands. A day is met when nothing of its plan was left at its end
    /// (`owed(day) == 0`), an empty plan included. One day missed between two met days is
    /// made up by the plan of the day after it: both days count. Two missed days in a row
    /// end the streak. Today is only judged by its own plan, so a day still going never breaks
    /// the streak. The streak starts with the first review.
    ///
    /// - Parameters:
    ///   - reviews: Graded reviews by study day: only the first day with one matters.
    ///   - today: The study day now.
    ///   - owed: The cards of the plan that were left at the end of a study day, for today
    ///     the plan now.
    public static func evaluate(reviews: [Int: Int], today: Int, owed: (Int) -> Int) -> Streak {
        guard let first = reviews.filter({ $0.value > 0 }).keys.min() else { return Streak(days: 0, repairCards: nil) }

        enum State {
            case idle
            case counting(days: Int)
            /// The day before was missed, after a streak of `daysBefore`.
            case missedOnce(daysBefore: Int)
        }
        var state = State.idle
        for day in first..<max(first, today) {
            if owed(day) == 0 {
                switch state {
                case let .counting(days): state = .counting(days: days + 1)
                case let .missedOnce(daysBefore): state = .counting(days: daysBefore + 2)
                case .idle: state = .counting(days: 1)
                }
            } else {
                switch state {
                case let .counting(days): state = .missedOnce(daysBefore: days)
                case .missedOnce, .idle: state = .idle
                }
            }
        }

        let owedToday = owed(today)
        switch state {
        case .idle:
            return Streak(days: owedToday == 0 ? 1 : 0, repairCards: nil)
        case let .counting(days):
            return Streak(days: days + (owedToday == 0 ? 1 : 0), repairCards: nil)
        case let .missedOnce(daysBefore):
            if owedToday == 0 {
                return Streak(days: daysBefore + 2, repairCards: nil)
            }
            return Streak(days: daysBefore, repairCards: owedToday)
        }
    }
}

/// What one deck contributes to the daily goal: its review log by study day, and what its
/// plan owed at the end of any day.
///
/// Holds the deck, which is a value that shares its storage.
public struct DeckActivity: Sendable {
    private let deck: Deck
    /// The study days of the cards, asked once: the streak counts the plan of every day of the
    /// history, which would ask the calendar about every card for each of them.
    private let index: StudySession.DayIndex
    /// The first moment from which a card of the deck can be in a plan: the earliest due date of a
    /// card that was studied, or the earliest creation of one that wasn't. Before it, no day
    /// asks anything, whatever the deck's history was.
    private let firstPlanned: Date
    /// Graded reviews by study day.
    public let reviewsByDay: [Int: Int]

    public init(deck: Deck, calendar: StudyCalendar) {
        self.deck = deck
        index = StudySession.DayIndex(deck: deck, calendar: calendar)
        reviewsByDay = Self.reviewsByDay(of: deck, calendar: calendar)
        firstPlanned = deck.cards.lazy.filter { !$0.isSuspended }.map { $0.learningState?.due ?? $0.created }.min() ?? .distantFuture
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

    /// What the plan still waited for at the end of study day `day`, or now for the day of
    /// `now`: `StudySession.counts(for:at:calendar:)`, so burying, limits, the lock and the
    /// share of the backlog count as they did that day. It looks at the deck as it is now: a
    /// card that was due on `day` and has been reviewed since no longer shows as left over,
    /// and a day left unfinished counts as done once its cards are caught up. A card that
    /// did not exist yet on `day` was not in its plan.
    public func owed(onDayOf day: Int, now: Date, calendar: StudyCalendar) -> StudyCounts {
        let endOfDay = calendar.start(ofDay: day + 1).addingTimeInterval(-1)
        guard endOfDay < now else { return StudySession.counts(for: deck, at: now, calendar: calendar) }
        guard endOfDay >= firstPlanned else { return StudyCounts() }
        return StudySession.counts(for: deck, at: endOfDay, calendar: calendar, past: index)
    }

    /// The plan of the study day of `now` when the day began: what the deck had to do then,
    /// counted the way `owed(onDayOf:now:calendar:)` counts it, on the deck as it stood: the
    /// cards reviewed since go back to the state of their last review before the day, new if
    /// there was none. Reviews beyond the plan, catching up and review ahead, are in no plan.
    public func plan(onDayOf now: Date, calendar: StudyCalendar) -> StudyCounts {
        let start = calendar.start(ofDay: calendar.dayNumber(for: now))
        let scheduler = Scheduler(learningOptions: deck.learningOptions, calendar: calendar)
        var atStart = deck
        for index in atStart.cards.indices where atStart.cards[index].hasCompleteLog {
            let card = atStart.cards[index]
            let before = card.log.prefix { $0.date < start }
            if before.count < card.log.count, card.log[before.count].date <= now {
                atStart.cards[index] = scheduler.replaying(Array(before), of: card)
            }
        }
        return StudySession.counts(for: atStart, at: start, calendar: calendar)
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
        var owedByDay: [Int: (cards: Int, answers: Int)] = [:]
        func owed(_ day: Int) -> (cards: Int, answers: Int) {
            if let known = owedByDay[day] { return known }
            var total = (cards: 0, answers: 0)
            for deck in decks {
                let counts = deck.owed(onDayOf: day, now: now, calendar: calendar)
                total.cards += counts.total
                total.answers += counts.answers
            }
            owedByDay[day] = total
            return total
        }

        let streak = Streak.evaluate(reviews: reviews, today: today) { owed($0).cards }
        let count = reviews[today] ?? 0
        let plan = decks.reduce(0) { $0 + $1.plan(onDayOf: now, calendar: calendar).answers }
        return DailyProgress(ring: DailyRing(reviews: count, goal: DailyGoal.goal(reviews: count, owed: owed(today).answers, plan: plan)), streak: streak)
    }
}
