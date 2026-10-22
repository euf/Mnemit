import Foundation

/// The daily goal behind the rings and the streak, derived from review logs alone:
/// nothing is stored, so every device that reads the deck files shows the same.
///
/// The unit is the card. The goal of a study day is the number of cards in its plan as FSRS
/// set it when the day began, what `StudySession.counts(for:at:calendar:)` reports: the cards
/// due that day, overdue ones included, and the new cards within the day's limits. Only the
/// backlog, the review cards that were already due before the day, asks a share of itself
/// (`backlogShare(of:onTime:)`), so an import or a long break doesn't pile a thousand cards
/// on one day. The goal stays for the day: cards added later are no part of it. A card is
/// done once it was graded on the day and FSRS let it go to another day (`DeckActivity.done`):
/// it counts once, however many answers it took. A day is met when its ring is closed, an
/// empty plan included: nothing was due, so memory is where FSRS wants it. Cards done count
/// in every mode: the plan, catching up, review ahead and anything else a study stream
/// reviews as a card. Practice changes no card and writes no review, so it doesn't count.
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

    /// The goal of a study day on which `done` cards are done, `owed` cards of its plan still
    /// wait (`StudyCounts.total`), and the plan held `plan` cards when the day began.
    ///
    /// The goal is the plan, whatever happens to it after: an Again keeps its card in the plan,
    /// cards that are added or reviewed beyond it, catching up and review ahead, don't move it,
    /// so the ring goes on in laps. The one exception is a plan that has nothing left though
    /// fewer cards than planned are done (cards that were suspended or deleted during the
    /// day): it is met at those, so the ring never stands open next to "0 cards left". A day
    /// that began with an empty plan (a first deck, filled in the afternoon) takes the plan as
    /// it stands, `done + owed`, so the first day has a goal and its ring doesn't count laps.
    public static func goal(done: Int, owed: Int, plan: Int) -> Int {
        guard plan > 0 else { return done + owed }
        return owed > 0 ? plan : min(plan, done)
    }

    /// The first study day (2026-10-23) on which a day counts for the streak only when its plan
    /// was done. A day before it counts with a single answer, which is the rule streaks were
    /// started under (a fixed number of answers a day), so a streak that reaches back past the
    /// change is not cut by it.
    // ponytail: a cutover date and a clause in `Streak.evaluate`, no per-learner migration;
    // delete both once no streak can reach back past the day.
    public static let planRuleStart = CivilDate(year: 2026, month: 10, day: 23).dayNumber

    /// The study days before today whose answers set the pace (`secondsPerCard(days:done:)`).
    public static let paceDays = 7
    /// A pause between two answers longer than this is a break, not study time.
    public static let paceBreak: TimeInterval = 120
    /// The cards that must be done in the window for the learner's own pace to count.
    public static let paceMinimumCards = 20
    /// The pace until there is a pace: what a card takes when the learner has not done enough of them lately.
    public static let fallbackSecondsPerCard: Double = 20

    /// How long one done card takes this learner: the seconds between consecutive answers of a
    /// study day, pauses over `paceBreak` left out, divided by the cards done on those days.
    /// A card's learning steps and Agains are in the price, because all of a new card's answers
    /// land on one done card. `days` holds the answer times of each study day of the window,
    /// today and the `paceDays` before it, across all decks; `done` the cards done on them.
    /// `fallbackSecondsPerCard` for fewer than `paceMinimumCards`, or answers with no time between them.
    // ponytail: the gap between answers stands for the time spent, the log holds no durations: a
    // pause shorter than `paceBreak` counts as work, a card read for longer is cut short. Store
    // the time each answer took (a `reviews.jsonl` field) and sum it, if the estimate misleads.
    public static func secondsPerCard(days: [[Date]], done: Int) -> Double {
        guard done >= paceMinimumCards else { return fallbackSecondsPerCard }
        var seconds: TimeInterval = 0
        for day in days {
            let answers = day.sorted()
            for (earlier, later) in zip(answers, answers.dropFirst()) {
                let gap = later.timeIntervalSince(earlier)
                if gap <= paceBreak { seconds += gap }
            }
        }
        return seconds > 0 ? seconds / Double(done) : fallbackSecondsPerCard
    }

    /// The minutes `cards` still to do take at `secondsPerCard` each, rounded up; 0 for less than
    /// a minute ("< 1 min"), and `nil` for no cards, which need no estimate.
    public static func minutesLeft(cards: Int, secondsPerCard: Double) -> Int? {
        guard cards > 0 else { return nil }
        let seconds = Double(cards) * secondsPerCard
        return seconds < 60 ? 0 : Int((seconds / 60).rounded(.up))
    }
}

/// The ring of a study day: cards done against the goal, both in cards. The ring is full at
/// the goal and goes on filling in laps, as the Fitness rings do at 200 % and 300 %. A day
/// whose plan is empty has a goal of 0, which is met; the ring then counts a lap for each
/// card done.
public struct DailyRing: Hashable, Sendable {
    public var done: Int
    public var goal: Int

    public init(done: Int, goal: Int) {
        self.done = max(0, done)
        self.goal = max(0, goal)
    }

    /// 0.5 at half the goal, 2.25 in the third lap.
    public var fraction: Double { Double(done) / Double(max(1, goal)) }

    public var isGoalMet: Bool { done >= goal }

    /// How many times the goal has been reached: 2 from 200 %.
    public var laps: Int { done / max(1, goal) }
}

/// The days in a row on which the day's cards were done.
public struct Streak: Hashable, Sendable {
    /// Study days in the streak, today's included once its plan is done. Counts a single
    /// missed day that the plan of the day after it made up for.
    public var days: Int
    /// The cards of today's plan still to do that would make up for the single day missed
    /// yesterday and keep the streak; `nil` if no day is missed or today is met. The plan
    /// already holds what the missed day left over. The streak ends if today ends without
    /// them.
    public var repairCards: Int?

    public init(days: Int, repairCards: Int?) {
        self.days = days
        self.repairCards = repairCards
    }

    /// How the streak stands. A day is met when no card of its plan was left at its end
    /// (`owed(day) == 0`), an empty plan included. One day missed between two met days is
    /// made up by the plan of the day after it: both days count. Two missed days in a row
    /// end the streak. Today is only judged by its own plan, so a day still going never breaks
    /// the streak. The streak starts with the first review. A day before
    /// `DailyGoal.planRuleStart` is met with a single answer, too.
    ///
    /// - Parameters:
    ///   - reviews: Graded answers by study day: they tell the first day and the days before
    ///     `planRuleStart` that count with one, nothing else.
    ///   - today: The study day now.
    ///   - planRuleStart: The first study day judged by its plan alone; the tests move it.
    ///   - owed: The cards of the plan that were left at the end of a study day, for today
    ///     the cards still to do, 0 once today's ring is closed (`DailyProgress.evaluate`).
    ///     Not asked for a day before `planRuleStart` that has an answer.
    public static func evaluate(reviews: [Int: Int], today: Int, planRuleStart: Int = DailyGoal.planRuleStart, owed: (Int) -> Int) -> Streak {
        guard let first = reviews.filter({ $0.value > 0 }).keys.min() else { return Streak(days: 0, repairCards: nil) }
        func isMet(_ day: Int) -> Bool {
            (day < planRuleStart && (reviews[day] ?? 0) > 0) || owed(day) == 0
        }

        enum State {
            case idle
            case counting(days: Int)
            /// The day before was missed, after a streak of `daysBefore`.
            case missedOnce(daysBefore: Int)
        }
        var state = State.idle
        for day in first..<max(first, today) {
            if isMet(day) {
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

        let isTodayMet = isMet(today)
        switch state {
        case .idle:
            return Streak(days: isTodayMet ? 1 : 0, repairCards: nil)
        case let .counting(days):
            return Streak(days: days + (isTodayMet ? 1 : 0), repairCards: nil)
        case let .missedOnce(daysBefore):
            if isTodayMet {
                return Streak(days: daysBefore + 2, repairCards: nil)
            }
            return Streak(days: daysBefore, repairCards: owed(today))
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
    /// Graded answers by study day, one for each entry of a card's log. They tell on which
    /// days the learner studied; the ring counts cards (`done(onDayOf:calendar:)`).
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
    /// there was none, and the cards created since are left out. Reviews beyond the plan,
    /// catching up and review ahead, are in no plan.
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
        return StudySession.counts(for: atStart, at: start, calendar: calendar, past: StudySession.DayIndex(deck: atStart, calendar: calendar))
    }

    /// How many cards are done on the study day of `now`: graded on it, and due after its end,
    /// which is that FSRS let them go to another day. A review card answered Hard, Good or Easy
    /// is done at once, a new card once its learning steps are through; a card answered Again
    /// is not until it is through its relearning. A card counts once, however many answers it
    /// took, and whether the plan or a review ahead asked it. Counted on the deck as it is.
    public func done(onDayOf now: Date, calendar: StudyCalendar) -> Int {
        let day = calendar.dayNumber(for: now)
        let start = calendar.start(ofDay: day)
        let end = calendar.start(ofDay: day + 1)
        return deck.cards.reduce(0) { count, card in
            guard let state = card.learningState, state.due >= end, state.lastReview >= start, state.lastReview < end else { return count }
            return count + 1
        }
    }

    /// The answers of the study days that set the learner's pace, and the cards done on them
    /// (`DailyGoal.secondsPerCard(days:done:)`): the study day of `now` and the `DailyGoal.paceDays`
    /// before it. A card is done on a day when its last answer of that day left it due on a later
    /// one, which the scheduler replays from its log: a card that was done on an earlier day
    /// and answered again since is still done on that day. A card whose log doesn't reach back to
    /// its first review (`Card.hasCompleteLog`) can't be replayed and counts as done on each day it
    /// was answered.
    func pace(at now: Date, calendar: StudyCalendar) -> Pace {
        let today = calendar.dayNumber(for: now)
        let start = calendar.start(ofDay: today - DailyGoal.paceDays)
        let end = calendar.start(ofDay: today + 1)
        let scheduler = Scheduler(learningOptions: deck.learningOptions, calendar: calendar)
        var pace = Pace()
        for card in deck.cards {
            guard let latest = card.log.last, latest.date >= start else { continue }
            var replayed = card
            replayed.resetLearningState()
            for (index, entry) in card.log.enumerated() {
                guard entry.date < end else { break }
                if card.hasCompleteLog {
                    var random = Scheduler.random(forReviewOf: card.id, at: entry.date)
                    replayed = scheduler.review(replayed, grade: entry.grade, at: entry.date, mode: entry.mode, using: &random)
                }
                guard entry.date >= start else { continue }
                let day = calendar.dayNumber(for: entry.date)
                pace.days[day, default: []].append(entry.date)
                let endOfDay = calendar.start(ofDay: day + 1)
                let isLastOfDay = !(card.log.indices.contains(index + 1) && card.log[index + 1].date < endOfDay)
                if isLastOfDay, !card.hasCompleteLog || (replayed.learningState?.due ?? .distantPast) >= endOfDay {
                    pace.done += 1
                }
            }
        }
        return pace
    }

    /// What a deck gives `DailyGoal.secondsPerCard(days:done:)`: answer times by study day, and cards done.
    struct Pace {
        var days: [Int: [Date]] = [:]
        var done = 0
    }
}

/// The ring and the streak of a learner over some decks, see `evaluate(_:at:calendar:)`.
public struct DailyProgress: Hashable, Sendable {
    public var ring: DailyRing
    public var streak: Streak
    /// The cards of today's plan still to do across the decks: `StudySession.counts(for:at:calendar:).total`,
    /// the "N cards left".
    public var cardsLeft: Int
    /// What one done card takes this learner, `DailyGoal.secondsPerCard(days:done:)`.
    public var secondsPerCard: Double

    public init(ring: DailyRing, streak: Streak, cardsLeft: Int = 0, secondsPerCard: Double = DailyGoal.fallbackSecondsPerCard) {
        self.ring = ring
        self.streak = streak
        self.cardsLeft = cardsLeft
        self.secondsPerCard = secondsPerCard
    }

    /// How long the cards left take, `DailyGoal.minutesLeft(cards:secondsPerCard:)`.
    public var minutesLeft: Int? { DailyGoal.minutesLeft(cards: cardsLeft, secondsPerCard: secondsPerCard) }

    /// Adds up the cards done and the plans of all `decks`: one ring and one streak for the
    /// learner, however many decks they study.
    public static func evaluate(
        _ decks: [DeckActivity], at now: Date, calendar: StudyCalendar, planRuleStart: Int = DailyGoal.planRuleStart
    ) -> DailyProgress {
        let today = calendar.dayNumber(for: now)
        var reviews: [Int: Int] = [:]
        for deck in decks {
            reviews.merge(deck.reviewsByDay, uniquingKeysWith: +)
        }
        var owedByDay: [Int: Int] = [:]
        func owed(_ day: Int) -> Int {
            if let known = owedByDay[day] { return known }
            let total = decks.reduce(0) { $0 + $1.owed(onDayOf: day, now: now, calendar: calendar).total }
            owedByDay[day] = total
            return total
        }

        let plan = decks.reduce(0) { $0 + $1.plan(onDayOf: now, calendar: calendar).total }
        let done = decks.reduce(0) { $0 + $1.done(onDayOf: now, calendar: calendar) }
        let ring = DailyRing(done: done, goal: DailyGoal.goal(done: done, owed: owed(today), plan: plan))
        var answerDays: [Int: [Date]] = [:]
        var doneInWindow = 0
        for deck in decks {
            let pace = deck.pace(at: now, calendar: calendar)
            answerDays.merge(pace.days, uniquingKeysWith: +)
            doneInWindow += pace.done
        }
        // Today is met by its ring: cards added after the day began are laps, not debt.
        let streak = Streak.evaluate(reviews: reviews, today: today, planRuleStart: planRuleStart) { $0 == today && ring.isGoalMet ? 0 : owed($0) }
        return DailyProgress(
            ring: ring, streak: streak, cardsLeft: owed(today),
            secondsPerCard: DailyGoal.secondsPerCard(days: Array(answerDays.values), done: doneInWindow))
    }
}
