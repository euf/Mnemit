import Foundation

/// The daily goal behind the rings, the rounds and the streak, derived from review logs alone:
/// nothing is stored, so every device that reads the deck files shows the same.
///
/// The unit is the card, and the time of a day is in seconds of work at the learner's own pace (`Pace`).
/// The time of the day, which the logs teach, follows whether the rings closed (`nextTime(after:)`);
/// new cards are admitted only up to the time it leaves after the day's reviews
/// (`newCardsAllowed(seconds:otherCards:pace:)`). The first `streakSeconds` of the plan are the streak step.
/// The plan of a study day is what FSRS sets when the day begins, `StudySession.counts(for:at:calendar:)`
/// with those allowances: the cards due that day, overdue ones included, and the new cards within the day's
/// limits and allowance. The goal of the day is the cards of that plan that fit its time (`DayRounds`), most
/// forgotten first, so an import or a long break doesn't pile a thousand cards on one day: reviews beyond it
/// stay in the plan and what is done beyond the goal fills laps. The goal stays for the day: cards added
/// later are no part of it. A card is done once its last review of the day left it due on a later day,
/// which is that FSRS let it go (`DeckActivity.done`): it counts once, however many reviews it took.
/// Reviews, the grades in the logs, count for the streak's first day and for the pace
/// (`pace(days:newDone:otherDone:)`), never for the goal or the ring. A day keeps the streak when its streak
/// step is done, an empty plan included: nothing was due, so memory is where FSRS wants it; a day closes
/// its ring when its goal is done. Cards done count in every mode: the plan, catch-up, review ahead and
/// anything else the study stream asks. Practice changes no card and writes no review, so it doesn't count.
///
/// Everything that sets the size of a day is here: a cap on the goal or the length of the streak step is a change
/// of this type.
public enum DailyGoal {
    /// The goal of a study day on which `done` cards are done, `owed` cards of its plan still
    /// wait (`StudyCounts.total`), and the cards of its plan that fit its time were `plan` when the
    /// day began (`DayRounds.goal`).
    ///
    /// The goal is those cards, whatever happens to the plan after: an Again keeps its card in the plan,
    /// cards that are added, and cards done beyond it in catch-up and review ahead, don't move
    /// it, so the ring goes on in laps. The one exception is a plan that has nothing left though
    /// fewer cards than planned are done (cards that were suspended or deleted during the
    /// day): it is met at those, so the ring never stands open next to "0 cards left". A day
    /// that began with an empty plan (a first deck, filled in the afternoon) takes the plan as
    /// it stands, `done + owed`, so the first day has a goal and its ring doesn't count laps.
    public static func goal(done: Int, owed: Int, plan: Int) -> Int {
        guard plan > 0 else { return done + owed }
        return owed > 0 ? plan : min(plan, done)
    }

    /// The first study day (2026-10-23) on which a day counts for the streak only when its first
    /// round was done. A day before it counts with a single review, which is the rule streaks were
    /// started under (a fixed number of reviews a day), so a streak that reaches back past the
    /// change is not cut by it.
    // ponytail: a cutover date and a clause in `Streak.evaluate`, no per-learner migration;
    // delete both once no streak can reach back past the day.
    public static let planRuleStart = CivilDate(year: 2026, month: 10, day: 23).dayNumber

    /// The study days before today whose reviews set the pace (`pace(days:newDone:otherDone:)`).
    public static let paceDays = 7
    /// The reviews with a duration, or else the gaps between reviews, a category needs in the window for
    /// the learner's own time per review to count.
    public static let paceMinimumGaps = 20
    /// The cards of a category that must be done in the window for the learner's own pace with them to count.
    public static let paceMinimumCards = 10
    /// What a card that was new when its study day began takes until there is a pace: seconds.
    public static let fallbackNewCardSeconds: Double = 30
    /// What any other card takes until there is a pace: seconds.
    public static let fallbackOtherCardSeconds: Double = 10
    /// The interquartile range of a standard normal distribution: the spread of the logged times is
    /// their IQR over it.
    private static let normalIQR = 1.349
    /// A time per review is at least this long before its logarithm is taken: seconds.
    private static let shortestTime: TimeInterval = 1

    /// One review of a study day, for the pace: when, whether its card was new when the day began
    /// (`Card.wasNew(before:)`), how long the card was on screen if that was logged, and whether the
    /// card was done that day (its last review of the day left it due on a later one).
    public typealias PacedReview = (date: Date, isNew: Bool, duration: Duration?, isDone: Bool)

    /// The pace, how long a done card takes this learner, for the cards that were new when their
    /// study day began and for all others. `days` holds the reviews of each study day of the window,
    /// today and the `paceDays` before it, across all decks. A review's time is how long its card
    /// was on screen (`ReviewLogEntry.duration`). Where a category has too few of them, as in a log
    /// from before they were kept, the gaps between consecutive reviews of a study day, none left
    /// out, stand for them: each goes to the card of the later review, the one the swipe was spent
    /// on. A card's category holds for all its reviews of the day, so the learning steps of a new
    /// card are in the price of new cards, and an Again on a review card and its relearning in the
    /// price of the others.
    ///
    /// A category's price is the typical seconds a review takes times the reviews each of its done
    /// cards needed (`newDone`, `otherDone`). The typical seconds are the mean of the lognormal
    /// that the logged durations follow if the category has `paceMinimumGaps` of them, worked out
    /// from the median and the interquartile range of their logarithms: exp(m + s² / 2), with m the
    /// median and s the IQR over 1.349; else the median of the gaps. The reviews are those of the
    /// category's cards that were done on the day they were reviewed: the reviews of a card still
    /// open at the end of its day are in no price, as the card is in none, so a day's Agains on
    /// cards left for the next day don't raise it. The first review of each study day, which has no
    /// gap, is included. A category with fewer than `paceMinimumGaps` times or `paceMinimumCards`
    /// done cards gets `fallbackNewCardSeconds` or `fallbackOtherCardSeconds`.
    // ponytail: the durations are the primary source and the gaps the fallback for old logs. Breaks
    // (4 minutes to hours) fall in the gaps, over a quarter of them on some days, and spread their
    // logarithms so far that exp(m + s² / 2) runs away from the typical time; the median ignores
    // them while they are under half, and with a share p of breaks it is the 0.5 / (1 - p) quantile
    // of the work gaps, so it runs a little high. A duration has no breaks, as the time in the
    // background is not recorded, so the lognormal mean stands: it prices the long right tail that
    // real times have, which a median leaves out. A gap also holds the time between cards (a menu,
    // the rest screen), so a price from gaps runs high. A duration is not capped (the learner may be
    // away from the phone with the app open); cap it like Anki's maximum answer seconds (60 s by
    // default) if the mean misleads.
    public static func pace(days: [[PacedReview]], newDone: Int, otherDone: Int) -> Pace {
        var newGaps: [Double] = []
        var otherGaps: [Double] = []
        var newDurations: [Double] = []
        var otherDurations: [Double] = []
        var newReviews = 0
        var otherReviews = 0
        for day in days {
            let reviews = day.sorted { $0.date < $1.date }
            newReviews += reviews.filter { $0.isNew && $0.isDone }.count
            otherReviews += reviews.filter { !$0.isNew && $0.isDone }.count
            for (earlier, later) in zip(reviews, reviews.dropFirst()) {
                let gap = max(shortestTime, later.date.timeIntervalSince(earlier.date))
                if later.isNew { newGaps.append(gap) } else { otherGaps.append(gap) }
            }
            for review in reviews {
                guard let duration = review.duration else { continue }
                let time = max(shortestTime, duration / .seconds(1))
                if review.isNew { newDurations.append(time) } else { otherDurations.append(time) }
            }
        }
        func price(_ gaps: [Double], _ durations: [Double], reviews: Int, done: Int, fallback: Double) -> Double {
            guard done >= paceMinimumCards else { return fallback }
            let seconds: Double
            if durations.count >= paceMinimumGaps {
                seconds = lognormalMean(of: durations)
            } else if gaps.count >= paceMinimumGaps {
                seconds = quantile(0.5, of: gaps.sorted())
            } else {
                return fallback
            }
            return seconds * Double(reviews) / Double(done)
        }
        return Pace(
            newCard: price(newGaps, newDurations, reviews: newReviews, done: newDone, fallback: fallbackNewCardSeconds),
            otherCard: price(otherGaps, otherDurations, reviews: otherReviews, done: otherDone, fallback: fallbackOtherCardSeconds))
    }

    /// The streak step: the cards of the plan that fit the first `streakSeconds` of work at the learner's own
    /// pace. A day keeps the streak when they are done, and Study rests there once.
    public static let streakSeconds: Double = 120
    /// The time of the first study day, in seconds: two and a half minutes, which 77 % of the first week's study days of
    /// Anki newcomers reach, the share of closed rings that `grows` and `shrinks` settle at (`references/ring-design.md`).
    public static let initialSeconds: Double = 150
    /// The time of a day, in seconds, whatever the learner did: two minutes to an hour, which holds the usual day
    /// of nine in ten Anki users (`references/ring-design.md`).
    public static let timeRange: ClosedRange<Double> = 120...3600

    /// What a closed ring multiplies the next time by. With `shrinks` the share of closed rings settles where
    /// p ln(grows) = (1 - p) ln(1 / shrinks), 0.78, whatever the work (`references/ring-design.md`).
    public static let grows = 1.075
    /// What an open ring multiplies the next time by: a quarter less.
    public static let shrinks = 0.775

    /// Why a day has the size it has.
    public enum SizeReason: Hashable, Sendable {
        /// No study day before it to go by: `initialSeconds`.
        case start
        /// The last study day closed its ring: its time times `grows`.
        case ringClosed
        /// The last study day left its ring open: its time times `shrinks`.
        case ringOpen
        /// The last study day closed its ring on a plan smaller than its time (`RingDay.filled` false): its time again.
        case smallPlan
    }

    /// One day of the ring as the size rule reads it, plain values: the size it had and what came of it.
    public struct RingDay: Hashable, Sendable {
        public var day: Int
        /// The seconds of work the day asked.
        public var time: Double
        /// Why.
        public var reason: SizeReason
        /// The cards done on the day at the day's own prices, in seconds (`pace.seconds(newCards:otherCards:)`).
        public var worked: Double
        /// The ring was closed.
        public var closed: Bool
        /// Something was done: `done > 0`.
        public var studied: Bool
        /// The goal took the day's time (`DayRounds.filled`): the plan held more than the time. A ring closed on a
        /// smaller plan says nothing of more time.
        public var filled: Bool

        public init(
            day: Int, time: Double = DailyGoal.initialSeconds, reason: SizeReason = .start, worked: Double, closed: Bool, studied: Bool,
            filled: Bool = true
        ) {
            self.day = day
            self.time = time
            self.reason = reason
            self.worked = worked
            self.closed = closed
            self.studied = studied
            self.filled = filled
        }
    }

    /// The time of the next day, in seconds, from the days before it (`days`, oldest first, every day from the first
    /// study day): a closure tracker. The last study day asked `T` (its `time`, which carries the steps of the days
    /// before it, so a cached run equals a recount); the next time is `T × grows` when its ring closed and
    /// `T × shrinks` when it stayed open, within `timeRange`; `initialSeconds` before any study day. A ring closed on a
    /// plan smaller than its time (`RingDay.filled` false: a deck's new-card limit or an exhausted deck set the goal)
    /// keeps `T`: the learner was not asked for it. A day without work, missed or not, changes nothing.
    public static func nextTime(after days: [RingDay]) -> (time: Double, reason: SizeReason) {
        guard let last = days.last(where: \.studied) else { return (initialSeconds, .start) }
        if last.closed && !last.filled { return (last.time, .smallPlan) }
        let next = last.time * (last.closed ? grows : shrinks)
        return (min(max(next, timeRange.lowerBound), timeRange.upperBound), last.closed ? .ringClosed : .ringOpen)
    }

    /// How many new cards a day admits: what is left of its `seconds` once the `otherCards` of the
    /// plan, the learning cards and the reviews, are taken at their price, in new cards at theirs. Never
    /// negative: a day with more reviews than time admits none.
    public static func newCardsAllowed(seconds: Double, otherCards: Int, pace: Pace) -> Int {
        let left = seconds - Double(max(0, otherCards)) * pace.otherCard
        // A sliver is added so that exact multiples of the price don't fall short in the last digit.
        return max(0, Int((left / pace.newCard + 1e-9).rounded(.down)))
    }

    /// `total` new cards shared among decks in proportion to their `ceilings`, the new cards each deck's own
    /// limits let it introduce: each part is its share rounded down, and the cards that are left go to the
    /// largest remainders, the earlier deck first among equals. No deck gets more than its ceiling; with
    /// `total` at the sum of the ceilings or more, each gets its ceiling.
    public static func split(_ total: Int, overCeilings ceilings: [Int]) -> [Int] {
        let ceilings = ceilings.map { max(0, $0) }
        let sum = ceilings.reduce(0, +)
        guard total < sum else { return ceilings }
        let total = max(0, total)
        var parts = ceilings.map { total * $0 / sum }
        let remainders = ceilings.map { total * $0 % sum }
        let order = ceilings.indices.sorted { remainders[$0] != remainders[$1] ? remainders[$0] > remainders[$1] : $0 < $1 }
        var left = total - parts.reduce(0, +)
        for index in order where left > 0 {
            parts[index] += 1
            left -= 1
        }
        return parts
    }

    /// The mean of the lognormal whose logarithms are those of `times`, from their median and IQR: exp(m + s² / 2).
    private static func lognormalMean(of times: [Double]) -> Double {
        let sorted = times.map { log($0) }.sorted()
        let spread = (quantile(0.75, of: sorted) - quantile(0.25, of: sorted)) / normalIQR
        return exp(quantile(0.5, of: sorted) + spread * spread / 2)
    }

    /// The `p` quantile of `sorted`, between the two values it falls between.
    private static func quantile(_ p: Double, of sorted: [Double]) -> Double {
        let position = p * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, sorted.count - 1)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - Double(lower))
    }

    /// The minutes the cards still to do take at `pace`, rounded up; 0 for less than a minute
    /// ("< 1 min"), and `nil` for no cards, which need no estimate. `newCards` are the cards
    /// left that were new when the day began (`StudyCounts.newAtDayStart`), `otherCards` the rest.
    public static func minutesLeft(newCards: Int, otherCards: Int, pace: Pace) -> Int? {
        guard newCards + otherCards > 0 else { return nil }
        return minutes(seconds: pace.seconds(newCards: newCards, otherCards: otherCards))
    }

    /// The minutes `cards` still to do take at `secondsPerCard` each, as
    /// `minutesLeft(newCards:otherCards:pace:)`: the widget, which knows only how many cards
    /// are left, prices them all with one price (`Pace.secondsPerCard(newCards:otherCards:)`).
    public static func minutesLeft(cards: Int, secondsPerCard: Double) -> Int? {
        guard cards > 0 else { return nil }
        return minutes(seconds: Double(cards) * secondsPerCard)
    }

    /// Whole minutes, up; the seconds are taken to the millisecond first, so that cards priced
    /// by one price that was worked out from the sum (`Pace.secondsPerCard(newCards:otherCards:)`)
    /// give the minutes of the sum, whatever the floating point leaves in the last digit.
    fileprivate static func minutes(seconds: Double) -> Int {
        let seconds = (seconds * 1000).rounded() / 1000
        return seconds < 60 ? 0 : Int((seconds / 60).rounded(.up))
    }
}

/// The cards of a study day cut at the streak step and the goal, as the plan stood when the day began.
///
/// The plan is `otherCards`, learning cards and reviews, then `newCards`, in the order the stream takes
/// them; a card costs the pace of its kind. The goal is the cards of the plan that fit the day's time in
/// seconds, at least one card if the plan has any: what is more stays in the plan, and what is done beyond
/// the goal fills laps. The streak step ends at the first card where the cost reaches
/// `DailyGoal.streakSeconds`, and the goal ends the day; the two coincide when the plan is that short.
public struct DayRounds: Hashable, Sendable {
    /// The card counts at which the streak step and the day end, increasing; the last is the goal, and there
    /// is one end when they coincide. Empty without a goal.
    public let ends: [Int]
    private let otherCards: Int
    private let pace: Pace

    public init(otherCards: Int, newCards: Int, pace: Pace, seconds budget: Double) {
        let otherCards = max(0, otherCards)
        let newCards = max(0, newCards)
        self.otherCards = otherCards
        self.pace = pace
        let fitting: Int
        if Double(otherCards) * pace.otherCard > budget {
            fitting = Int((budget / pace.otherCard + 1e-9).rounded(.down))
        } else {
            fitting = otherCards + min(newCards, Int(((budget - Double(otherCards) * pace.otherCard) / pace.newCard + 1e-9).rounded(.down)))
        }
        let goal = otherCards + newCards > 0 ? max(1, fitting) : 0
        var ends: [Int] = []
        var seconds = 0.0
        for card in stride(from: 1, through: goal, by: 1) {
            seconds += card <= otherCards ? pace.otherCard : pace.newCard
            if seconds + 1e-9 >= DailyGoal.streakSeconds {
                ends.append(card)
                break
            }
        }
        if goal > 0, ends.last != goal { ends.append(goal) }
        self.ends = ends
        let next = goal < otherCards ? pace.otherCard : pace.newCard
        filled = goal > 0 && Double(min(goal, otherCards)) * pace.otherCard + Double(max(0, goal - otherCards)) * pace.newCard + next > budget + 1e-9
    }

    /// The time, not the plan, set the goal: what the goal costs leaves less of the day's seconds than the plan's next
    /// card would take, a review while the goal ends inside the reviews, else a new card. False when the plan was smaller
    /// (a deck's new-card limit, no new cards left) or empty.
    public let filled: Bool

    /// The cards of the goal; 0 for a plan without cards.
    public var goal: Int { ends.last ?? 0 }

    public var rounds: Int { ends.count }

    /// How many rounds `done` cards have ended.
    public func roundsDone(cardsDone done: Int) -> Int { ends.filter { $0 <= done }.count }

    /// The cards from `done` to the end of the round it is in; `nil` once the rounds are done.
    public func cardsToNextRound(cardsDone done: Int) -> Int? {
        ends.first { $0 > done }.map { $0 - done }
    }

    /// The minutes from `done` cards to the end of the round it is in, in whole minutes up and 0 for under
    /// one, as `DailyGoal.minutesLeft(newCards:otherCards:pace:)`; `nil` once the rounds are done.
    public func minutesToNextRound(cardsDone done: Int) -> Int? {
        guard let end = ends.first(where: { $0 > done }) else { return nil }
        return DailyGoal.minutes(seconds: seconds(ofFirst: end) - seconds(ofFirst: done))
    }

    /// The minutes round `number` (counting from 1) takes at the day's pace, whole minutes up and 0 for under
    /// one, as `minutesToNextRound(cardsDone:)`; `nil` for a round the day doesn't have.
    public func minutes(ofRound number: Int) -> Int? {
        guard ends.indices.contains(number - 1) else { return nil }
        let first = number > 1 ? ends[number - 2] : 0
        return DailyGoal.minutes(seconds: seconds(ofFirst: ends[number - 1]) - seconds(ofFirst: first))
    }

    /// What the first `cards` cards of the plan cost, in seconds.
    private func seconds(ofFirst cards: Int) -> Double {
        Double(min(cards, otherCards)) * pace.otherCard + Double(max(0, cards - otherCards)) * pace.newCard
    }
}

/// How long a done card takes the learner, in seconds, for the two kinds the time left prices
/// (`DailyGoal.pace(days:newDone:otherDone:)`).
public struct Pace: Hashable, Sendable {
    /// A card that was new when its study day began: its learning steps are in the price.
    public var newCard: Double
    /// Any other card: review, relearning, learning carried over from an earlier day.
    public var otherCard: Double

    /// A card takes at least a second, as a logged time does (`DailyGoal.pace(days:newDone:otherDone:)`).
    public init(newCard: Double = DailyGoal.fallbackNewCardSeconds, otherCard: Double = DailyGoal.fallbackOtherCardSeconds) {
        self.newCard = max(1, newCard)
        self.otherCard = max(1, otherCard)
    }

    /// What `newCards` and `otherCards` take, in seconds.
    public func seconds(newCards: Int, otherCards: Int) -> Double {
        Double(max(0, newCards)) * newCard + Double(max(0, otherCards)) * otherCard
    }

    /// One price for a card of those that are left: their time over their number, and the price
    /// of the other cards when none are left.
    public func secondsPerCard(newCards: Int, otherCards: Int) -> Double {
        let cards = max(0, newCards) + max(0, otherCards)
        return cards > 0 ? seconds(newCards: newCards, otherCards: otherCards) / Double(cards) : otherCard
    }
}

/// The ring of a study day: cards done against the goal, both in cards. The ring is full at
/// the goal and goes on filling in laps, as the Fitness rings do at 200 % and 300 %. A day
/// whose plan is empty has a goal of 0, which is met; the ring then counts a lap for each
/// card done.
public struct DailyRing: Hashable, Sendable {
    public var done: Int
    public var goal: Int
    /// The cards on their way to done, as parts of a card (`Deck.cardsUnderway(onDayOf:calendar:)`): the
    /// ring shows them, the counts don't.
    public var underway: Double

    public init(done: Int, goal: Int, underway: Double = 0) {
        self.done = max(0, done)
        self.goal = max(0, goal)
        self.underway = max(0, underway)
    }

    /// 0.5 at half the goal, 2.25 in the third lap; the cards on their way count with their parts.
    public var fraction: Double { (Double(done) + underway) / Double(max(1, goal)) }

    public var isGoalMet: Bool { done >= goal }

    /// How many times the goal has been reached: 2 from 200 %.
    public var laps: Int { done / max(1, goal) }
}

/// The days in a row on which the learner kept their streak: a day counts once its first round is done.
public struct Streak: Hashable, Sendable {
    /// Study days in the streak, today's included once its first round is done. Counts a single
    /// missed day that the next day made up for.
    public var days: Int
    /// The cards of today's plan still to do that would close the ring and so make up for the single
    /// day missed yesterday and keep the streak; `nil` if no day is missed or today is closed. The
    /// streak ends if today ends without them.
    public var repairCards: Int?

    public init(days: Int, repairCards: Int?) {
        self.days = days
        self.repairCards = repairCards
    }

    /// How the streak stands. A day is kept when its first round is done, or when its plan was empty
    /// (`isKept`). One day missed between two kept days is made up when the day after it closes its
    /// ring (`isClosed`): both days count. A day that is only kept leaves the missed day before it
    /// missed, and starts the streak anew. Two missed days in a row end the streak. Today is only
    /// judged by what it did, so a day still going never breaks the streak. The streak starts with
    /// the first review. A day before `DailyGoal.planRuleStart` is kept and closed with a single review.
    ///
    /// - Parameters:
    ///   - reviews: The reviews by study day: they tell the first day and the days before
    ///     `planRuleStart` that count with one, nothing else.
    ///   - today: The study day now.
    ///   - planRuleStart: The first study day judged by its rounds alone; the tests move it.
    ///   - isKept: Whether a study day's first round was done, or its plan empty. Not asked for a
    ///     day before `planRuleStart` that has a review.
    ///   - isClosed: Whether a study day's ring was closed, done ≥ its goal. Not asked for a day
    ///     before `planRuleStart` that has a review.
    ///   - repairCards: The cards that close today's ring, what today still owes.
    public static func evaluate(
        reviews: [Int: Int], today: Int, planRuleStart: Int = DailyGoal.planRuleStart, isKept: (Int) -> Bool, isClosed: (Int) -> Bool, repairCards: Int
    ) -> Streak {
        walk(reviews: reviews, today: today, planRuleStart: planRuleStart, isKept: isKept, isClosed: isClosed, repairCards: repairCards).streak
    }

    /// How one study day ended in `walk`.
    struct Step: Hashable, Sendable {
        /// The streak at the end of the day: for today, `Streak.days`.
        var days: Int
        /// The day closed its ring after a single missed day, and so kept the streak alive.
        var saved: Bool
        /// The day before was missed and this day has not closed its ring: only today can still save the streak.
        var atRisk: Bool
    }

    /// The one rule of the streak, as `evaluate(reviews:today:planRuleStart:isKept:isClosed:repairCards:)` states
    /// it: the streak and, for every study day from the first review to today, how that day ended. A day
    /// before today ends with the streak it left (a single missed day leaves the streak it interrupted, at risk).
    /// No review, no days.
    static func walk(
        reviews: [Int: Int], today: Int, planRuleStart: Int, isKept: (Int) -> Bool, isClosed: (Int) -> Bool, repairCards: Int
    ) -> (streak: Streak, steps: [Int: Step]) {
        guard let first = reviews.filter({ $0.value > 0 }).keys.min() else { return (Streak(days: 0, repairCards: nil), [:]) }
        func isLegacy(_ day: Int) -> Bool { day < planRuleStart && (reviews[day] ?? 0) > 0 }
        func kept(_ day: Int) -> Bool { isLegacy(day) || isKept(day) }
        func closed(_ day: Int) -> Bool { isLegacy(day) || isClosed(day) }

        enum State {
            case idle
            case counting(days: Int)
            /// The day before was missed, after a streak of `daysBefore`.
            case missedOnce(daysBefore: Int)

            var days: Int {
                switch self {
                case .idle: 0
                case let .counting(days): days
                case let .missedOnce(daysBefore): daysBefore
                }
            }
        }
        var state = State.idle
        var steps: [Int: Step] = [:]
        for day in first..<max(first, today) {
            var saved = false
            switch state {
            case let .counting(days):
                state = kept(day) ? .counting(days: days + 1) : .missedOnce(daysBefore: days)
            case let .missedOnce(daysBefore):
                saved = closed(day)
                state = saved ? .counting(days: daysBefore + 2) : kept(day) ? .counting(days: 1) : .idle
            case .idle:
                state = kept(day) ? .counting(days: 1) : .idle
            }
            steps[day] = Step(days: state.days, saved: saved, atRisk: false)
        }

        let step: Step
        switch state {
        case .idle:
            step = Step(days: kept(today) ? 1 : 0, saved: false, atRisk: false)
        case let .counting(days):
            step = Step(days: days + (kept(today) ? 1 : 0), saved: false, atRisk: false)
        case let .missedOnce(daysBefore):
            let saved = closed(today)
            step = Step(days: saved ? daysBefore + 2 : daysBefore, saved: saved, atRisk: !saved)
        }
        steps[today] = step
        return (Streak(days: step.days, repairCards: step.atRisk ? repairCards : nil), steps)
    }
}

/// What one deck contributes to the daily goal: its review log by study day, and what its
/// plan owed at the end of any day.
///
/// Holds the deck, which is a value that shares its storage.
public struct DeckActivity: Sendable {
    private let deck: Deck
    /// The last `history(from:at:calendar:)` this activity worked out: the deck of an activity doesn't change, so
    /// a deck read from its file once is replayed once a study day, however often the progress is evaluated.
    private let cachedHistory = HistoryCache()
    /// The days before today, which outlive the activity: the open document makes a new activity at every
    /// change, and with the cache of its last one the days that the change left alone are not replayed again.
    private let pastCache: DeckHistoryCache
    /// The reviews by study day, one for each entry of a card's log. They tell on which
    /// days the learner studied and nothing more: the ring counts cards
    /// (`done(onDayOf:calendar:)`).
    public let reviewsByDay: [Int: Int]

    /// - Parameter historyCache: What the activities of one deck share while it changes, an open document's:
    ///   each keeps the days before today that its change left alone for the next (`DeckHistoryCache`).
    public init(deck: Deck, calendar: StudyCalendar, historyCache: DeckHistoryCache = DeckHistoryCache()) {
        self.deck = deck
        pastCache = historyCache
        reviewsByDay = Self.reviewsByDay(of: deck, calendar: calendar)
    }

    /// Whether the learner paused the deck (`LearningOptions.isPaused`): `DailyProgress.evaluate` and
    /// `DayBreakdown` leave it out of the day.
    public var isPaused: Bool { deck.learningOptions.isPaused }

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

    /// What the plan still waits for now, on the study day of `now`: `StudySession.counts(for:at:calendar:)`,
    /// so burying, limits and the lock count as the stream takes them, and
    /// `newCardAllowance` is the deck's share of the day's new cards (`DailyProgress.newCardAllowances`).
    public func owed(now: Date, calendar: StudyCalendar, newCardAllowance: Int? = nil) -> StudyCounts {
        StudySession.counts(for: deck, at: now, calendar: calendar, newCardAllowance: newCardAllowance)
    }

    /// The plan of the study day of `now` when the day began: what the deck had to do then,
    /// counted the way `owed(onDayOf:now:calendar:)` counts it, on the deck as it stood: the
    /// cards reviewed since go back to the state of their last review before the day, new if
    /// there was none, and the cards created since are left out. Cards done beyond the plan,
    /// in catch-up and review ahead, are in no plan.
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

    /// How many cards are done on the study day of `now`: cards whose last review of the day left
    /// them due after its end, which is that FSRS let them go to another day. A review card
    /// graded Hard, Good or Easy is done at once, a new card once its learning steps are
    /// through; a card graded Again is not until it is through its relearning. A card counts
    /// once, however many reviews it took, and whether the plan or a review ahead asked it.
    /// Counted on the deck as it is.
    public func done(onDayOf now: Date, calendar: StudyCalendar) -> Int {
        deck.doneCards(onDayOf: now, calendar: calendar)
    }

    /// The cards that are not suspended, by step of `MaturityCategory`, in the order of `allCases`.
    public func ladder() -> [Int] {
        var steps = [Int](repeating: 0, count: MaturityCategory.allCases.count)
        for card in deck.cards where !card.isSuspended {
            steps[MaturityCategory(card: card).rawValue] += 1
        }
        return steps
    }

    /// How many cards the reviews of the study day of `now` lifted to a higher step of `MaturityCategory`
    /// than they stood on when the day began: a new card learned, a card whose stability passed 4, 16, 64 or
    /// 256 days. A card whose log doesn't reach back to its first review is left out.
    public func climbs(onDayOf now: Date, calendar: StudyCalendar) -> Int {
        let start = calendar.start(ofDay: calendar.dayNumber(for: now))
        let scheduler = Scheduler(learningOptions: deck.learningOptions, calendar: calendar)
        return deck.cards.reduce(0) { count, card in
            guard !card.isSuspended, let state = card.learningState, state.lastReview >= start, card.hasCompleteLog else { return count }
            let before = card.log.prefix { $0.date < start }
            let then = before.isEmpty ? MaturityCategory.new : MaturityCategory(card: scheduler.replaying(Array(before), of: card))
            return MaturityCategory(card: card) > then ? count + 1 : count
        }
    }

    /// The cards on their way to done on the study day of `now`, as parts of a card,
    /// `Deck.cardsUnderway(onDayOf:calendar:)`.
    public func underway(onDayOf now: Date, calendar: StudyCalendar) -> Double {
        deck.cardsUnderway(onDayOf: now, calendar: calendar)
    }

    /// The words this deck has in memory at `now`, `MemoryEstimate`.
    public func memory(at now: Date, calendar: StudyCalendar) -> MemoryEstimate {
        MemoryEstimate(deck: deck, at: now, calendar: calendar)
    }

    /// The reviews of the study days that set the learner's pace, and the cards done on them
    /// (`DailyGoal.pace(days:newDone:otherDone:)`): the study day of `now` and the `DailyGoal.paceDays`
    /// before it, see `replayLog(from:through:calendar:keepsStates:)`.
    func paceLog(at now: Date, calendar: StudyCalendar) -> PaceLog {
        let today = calendar.dayNumber(for: now)
        return replayLog(from: today - DailyGoal.paceDays, through: today, calendar: calendar)
    }

    /// The reviews of the study days `firstDay` to `today` and the cards done on them. A card is done
    /// on a day when its last review of that day left it due on a later one, which the scheduler
    /// replays from its log: a card that was done on an earlier day and reviewed again since is still
    /// done on that day. A card whose log doesn't reach back to its first review
    /// (`Card.hasCompleteLog`) can't be replayed and counts as done on each day it was reviewed. On a
    /// day a card is new if it had no review before the day began (`Card.wasNew(before:)`), and all its
    /// reviews and its done card of that day are new. Each review says whether its card was done that
    /// day: the reviews of a card left open at the day's end are in the log, for the time between
    /// reviews, but in no price of a done card.
    ///
    /// With `keepsStates` the log also holds the state of each replayed card at the end of each day it
    /// was reviewed on (`PaceLog.statesAfter`), which is how a deck is seen as it stood on a past day.
    ///
    /// With `resumed`, a copy of the deck as it stood when `firstDay` began (`Past.stood`), the reviews before
    /// that day are not replayed again: each card goes on from the state it has there.
    func replayLog(from firstDay: Int, through today: Int, calendar: StudyCalendar, keepsStates: Bool = false, resumed: Deck? = nil) -> PaceLog {
        let start = calendar.start(ofDay: firstDay)
        let end = calendar.start(ofDay: today + 1)
        let scheduler = Scheduler(learningOptions: deck.learningOptions, calendar: calendar)
        var log = PaceLog()
        // The starts of the days, asked of the calendar once each.
        var starts: [Int: Date] = [:]
        func startOfDay(_ day: Int) -> Date {
            if let known = starts[day] { return known }
            let date = calendar.start(ofDay: day)
            starts[day] = date
            return date
        }
        for (cardIndex, card) in deck.cards.enumerated() {
            guard let latest = card.log.last, latest.date >= start else { continue }
            var replayed = card
            replayed.resetLearningState()
            var firstEntry = 0
            if let resumed {
                firstEntry = card.log.count
                while firstEntry > 0, card.log[firstEntry - 1].date >= start { firstEntry -= 1 }
                replayed.learningState = resumed.cards[cardIndex].learningState
            }
            // The card's reviews of the day so far: whether it was done is known at the last of them.
            var ofDay: [(date: Date, duration: Duration?)] = []
            for index in firstEntry..<card.log.count {
                let entry = card.log[index]
                guard entry.date < end else { break }
                if card.hasCompleteLog {
                    var random = Scheduler.random(forReviewOf: card.id, at: entry.date)
                    replayed = scheduler.review(replayed, grade: entry.grade, at: entry.date, mode: entry.mode, using: &random)
                }
                guard entry.date >= start else { continue }
                ofDay.append((entry.date, entry.duration))
                let day = calendar.dayNumber(for: entry.date)
                let endOfDay = startOfDay(day + 1)
                guard !(card.log.indices.contains(index + 1) && card.log[index + 1].date < endOfDay) else { continue }
                let isNew = card.wasNew(before: startOfDay(day))
                let isDone = !card.hasCompleteLog || (replayed.learningState?.due ?? .distantPast) >= endOfDay
                log.days[day, default: []] += ofDay.map { ($0.date, isNew, $0.duration, isDone) }
                ofDay.removeAll()
                if keepsStates, card.hasCompleteLog { log.statesAfter[day, default: []].append((cardIndex, replayed.learningState)) }
                if isDone {
                    if isNew {
                        log.newDone += 1
                        log.newDoneByDay[day, default: 0] += 1
                    } else {
                        log.otherDone += 1
                        log.otherDoneByDay[day, default: 0] += 1
                    }
                }
            }
        }
        return log
    }

    /// What a deck gives `DailyGoal.pace(days:newDone:otherDone:)`: reviews by study day, and
    /// the cards done, new and other, in all and by study day.
    struct PaceLog {
        var days: [Int: [DailyGoal.PacedReview]] = [:]
        var newDone = 0
        var otherDone = 0
        var newDoneByDay: [Int: Int] = [:]
        var otherDoneByDay: [Int: Int] = [:]
        /// The state of each card replayed from its log at the end of each study day it was reviewed
        /// on: the index of the card in the deck, and its state. Only with `keepsStates`.
        var statesAfter: [Int: [(card: Int, state: LearningState?)]] = [:]
        var done: Int { newDone + otherDone }

        /// The log of the days other than `day`.
        func without(day: Int) -> PaceLog {
            var rest = self
            rest.days[day] = nil
            rest.newDone -= newDoneByDay[day] ?? 0
            rest.otherDone -= otherDoneByDay[day] ?? 0
            rest.newDoneByDay[day] = nil
            rest.otherDoneByDay[day] = nil
            rest.statesAfter[day] = nil
            return rest
        }

        /// This log and `other`, which holds days this one doesn't.
        func adding(_ other: PaceLog) -> PaceLog {
            var all = self
            all.days.merge(other.days) { $1 }
            all.newDone += other.newDone
            all.otherDone += other.otherDone
            all.newDoneByDay.merge(other.newDoneByDay) { $1 }
            all.otherDoneByDay.merge(other.otherDoneByDay) { $1 }
            all.statesAfter.merge(other.statesAfter) { $1 }
            return all
        }
    }

    /// The one history an activity keeps.
    private final class HistoryCache: @unchecked Sendable {
        struct Key: Hashable {
            var first: Int
            var today: Int
            var calendar: StudyCalendar
        }

        private let lock = NSLock()
        private var kept: (key: Key, history: History)?

        func history(for key: Key) -> History? {
            lock.withLock { kept.flatMap { $0.key == key ? $0.history : nil } }
        }

        func keep(_ history: History, for key: Key) {
            lock.withLock { kept = (key, history) }
        }
    }

    /// The plan of a study day when it began, in cards that are not new and in new cards.
    struct DayStart: Hashable {
        var other = 0
        var new = 0
    }

    /// The deck on each study day from `first` to the day of `now`, as the log tells it, for the time and
    /// the goal of every day (`DailyProgress.evaluate`): the reviews of each day and the cards done
    /// (`paced`), and the plan at its start (`starts`).
    struct History {
        var paced: PaceLog
        var starts: [Int: DayStart]
        /// The new cards the deck's own limits take on the study day of `now` if it began now: the
        /// cards created since it began are in this plan, which `starts` leaves them out of.
        var newCeilingToday: Int
        /// Which `Past` the days before today are from, if they are kept for the next change; two histories that
        /// name the same hold the same days before today.
        var pastID: UUID?
    }

    /// What the days before today left of a deck, to go on from: `History` without today, and the deck as it
    /// stood when today began. It holds for as long as `key` does.
    struct Past {
        let id = UUID()
        var key: PastKey
        var paced: PaceLog
        var starts: [Int: DayStart]
        var stood: Deck
        var locks: ProductionLocks
    }

    /// Everything that the days before today read of a deck, which is what must not change for `Past` to
    /// hold: the options, and of each card its place, what the plan looks at (kind, note, creation,
    /// suspension), its log before today, and, where the log doesn't reach back to the first review
    /// and the card can't be replayed, the state it is in, which every past day sees. The texts, the state of a
    /// card that can be replayed, and what was reviewed today are not in it: a grade or an edit of a text
    /// leaves it as it was.
    struct PastKey: Equatable {
        struct PastCard: Equatable {
            var id: Card.ID
            var created: Date
            var kind: CardKind?
            var note: String?
            var isSuspended: Bool
            var isReplayable: Bool
            var log: ArraySlice<ReviewLogEntry>
            var state: LearningState?
        }

        var first: Int
        var today: Int
        var calendar: StudyCalendar
        var options: LearningOptions
        var cards: [PastCard]

        init(of deck: Deck, first: Int, today: Int, calendar: StudyCalendar) {
            self.first = first
            self.today = today
            self.calendar = calendar
            options = deck.learningOptions
            let start = calendar.start(ofDay: today)
            cards = deck.cards.map { card in
                var before = card.log.count
                while before > 0, card.log[before - 1].date >= start { before -= 1 }
                // A card never reviewed before today is the same to the days before it, new or graded today: its
                // first grade doesn't make it a card that can't be replayed.
                let isReplayable = card.hasCompleteLog || (before == 0 && card.learningState == nil)
                return PastCard(
                    id: card.id, created: card.created, kind: card.kind, note: card.note, isSuspended: card.isSuspended, isReplayable: isReplayable,
                    log: card.log.prefix(before), state: isReplayable ? nil : card.learningState)
            }
        }
    }

    /// Replays the log forward, once, instead of looking back from today at every day: the cards go
    /// through their reviews in `replayLog(from:through:calendar:keepsStates:)`, and a copy of the deck
    /// takes the state each card had at the end of the day before, so the plan of each day is
    /// `StudySession.counts(for:at:calendar:)` of the deck as it stood when that day began. For the day
    /// of `now` this is the plan of `plan(onDayOf:calendar:)`. A card whose log doesn't reach back to
    /// its first review can't be replayed and stays as it is on every day, as in that plan.
    ///
    /// The days before today are kept with the activity's `DeckHistoryCache` while nothing they read of the deck
    /// changes (`PastKey`), so a change of the open deck, a grade above all, replays only today: its reviews, from
    /// the state each card was left in, and its plan. The result is the one a replay of all days gives.
    func history(from first: Int, at now: Date, calendar: StudyCalendar) -> History {
        let today = calendar.dayNumber(for: now)
        let first = min(first, today)
        let key = HistoryCache.Key(first: first, today: today, calendar: calendar)
        if let known = cachedHistory.history(for: key) { return known }
        // A log that begins before `first` is replayed from its start, and its days before `first` leave no state.
        let isKeepable = first <= (reviewsByDay.keys.min() ?? first)
        let pastKey = PastKey(of: deck, first: first, today: today, calendar: calendar)
        var history: History
        if isKeepable, let past = pastCache.past(for: pastKey) {
            history = continued(from: past, calendar: calendar)
        } else {
            let replayed = replayHistory(key: pastKey, calendar: calendar)
            history = replayed.history
            if isKeepable {
                pastCache.keep(replayed.past)
            } else {
                history.pastID = nil
            }
        }
        cachedHistory.keep(history, for: key)
        return history
    }

    /// The history of all days from `key.first` to `key.today`, and what the days before today leave.
    private func replayHistory(key: PastKey, calendar: StudyCalendar) -> (history: History, past: Past) {
        let first = key.first
        let today = key.today
        let paced = replayLog(from: first, through: today, calendar: calendar, keepsStates: true)
        var stood = deck
        for index in stood.cards.indices {
            if stood.cards[index].hasCompleteLog { stood.cards[index].learningState = nil }
            // Without the log, the day's start has no first review to take back.
            stood.cards[index].log = []
        }
        var locks = ProductionLocks(of: stood, calendar: calendar)
        var starts: [Int: DayStart] = [:]
        /// Takes in the state each card was left in on `day`.
        func stand(after day: Int) {
            for change in paced.statesAfter[day] ?? [] {
                stood.cards[change.card].learningState = change.state
                locks.update(stood.cards[change.card], at: change.card)
            }
        }
        for day in first..<today {
            stand(after: day - 1)
            starts[day] = Self.dayStart(on: day, of: stood, locks: locks, calendar: calendar)
        }
        stand(after: today - 1)
        let past = Past(key: key, paced: paced.without(day: today), starts: starts, stood: stood, locks: locks)
        starts[today] = Self.dayStart(on: today, of: stood, locks: locks, calendar: calendar)
        let history = History(
            paced: paced, starts: starts, newCeilingToday: Self.newCeiling(on: today, of: stood, locks: locks, calendar: calendar), pastID: past.id)
        return (history, past)
    }

    /// The history from the days before today in `past`, and today replayed.
    private func continued(from past: Past, calendar: StudyCalendar) -> History {
        let today = past.key.today
        let reviews = replayLog(from: today, through: today, calendar: calendar, keepsStates: true, resumed: past.stood)
        var starts = past.starts
        starts[today] = Self.dayStart(on: today, of: past.stood, locks: past.locks, calendar: calendar)
        return History(
            paced: past.paced.adding(reviews), starts: starts, newCeilingToday: Self.newCeiling(on: today, of: past.stood, locks: past.locks, calendar: calendar),
            pastID: past.id)
    }

    /// The plan of study day `day` when it began, over `stood`, the deck as it was then.
    private static func dayStart(on day: Int, of stood: Deck, locks: ProductionLocks, calendar: StudyCalendar) -> DayStart {
        let counts = StudySession.counts(
            for: stood, at: calendar.start(ofDay: day), calendar: calendar, past: StudySession.DayIndex(lockedNotes: locks.notes))
        return DayStart(other: counts.learning + counts.review, new: counts.new)
    }

    /// The new cards the deck's limits take on `day` if it began now: the cards created since it began count.
    private static func newCeiling(on day: Int, of stood: Deck, locks: ProductionLocks, calendar: StudyCalendar) -> Int {
        let later = StudySession.DayIndex(lockedNotes: locks.notes, countsCardsCreatedLater: true)
        return StudySession.counts(for: stood, at: calendar.start(ofDay: day), calendar: calendar, past: later).new
    }
}

/// What `DailyProgress.evaluate` keeps between calls over the same decks: how the study days before today
/// stood (`Before`), while the decks' own days before today (`DeckHistoryCache`) are the same ones. A
/// grade changes today alone, and today is all a call then steps through.
public final class DailyProgressCache: @unchecked Sendable {
    struct Key: Equatable {
        /// The `DeckActivity.Past` each deck's days before today are from, in the order of the decks.
        var pasts: [UUID]
        var first: Int
        var today: Int
        var calendar: StudyCalendar
    }

    /// The study days before today, stepped through from the first.
    struct Before {
        /// Every day before today, from the first: its size, why, the work done on it and how its ring stood, which
        /// is what the size of the next day is worked out from (`DailyGoal.nextTime(after:)`).
        var days: [DailyGoal.RingDay]
        var kept: [Int: Bool]
        var closed: [Int: Bool]
        /// The day's goal and the cards done on it, for the `DayRecord`s.
        var goals: [Int: Int]
        var done: [Int: Int]
    }

    private let lock = NSLock()
    private var held: (key: Key, before: Before)?

    public init() {}

    func before(for key: Key) -> Before? {
        lock.withLock { held.flatMap { $0.key == key ? $0.before : nil } }
    }

    func keep(_ before: Before, for key: Key) {
        lock.withLock { held = (key, before) }
    }
}

/// What the activities of one deck share while the deck changes: the days before today, which a change of the
/// deck usually leaves as they were (`DeckActivity.history(from:at:calendar:)`). The open document of a window
/// makes a new activity at every change; handing each the cache of the last replays the days that did not
/// change once, not at every grade. One cache serves one deck.
public final class DeckHistoryCache: @unchecked Sendable {
    private let lock = NSLock()
    private var kept: DeckActivity.Past?
    private var replayCount = 0

    public init() {}

    /// How often all days were replayed, not only today.
    var replays: Int { lock.withLock { replayCount } }

    func past(for key: DeckActivity.PastKey) -> DeckActivity.Past? {
        let known = lock.withLock { kept }
        return known?.key == key ? known : nil
    }

    func keep(_ past: DeckActivity.Past) {
        lock.withLock {
            kept = past
            replayCount += 1
        }
    }
}

/// The notes whose production cards are held back, as `StudySession` finds them
/// (`LearningOptions.productionUnlockDays`), kept up to date card by card: a note is locked while one of its
/// recognition cards isn't learned, which a history of hundreds of days would otherwise look up for every card on
/// every day.
struct ProductionLocks {
    private let unlockDays: Int
    private let calendar: StudyCalendar
    private var isLearned: [Bool]
    private var unlearned: [String: Int] = [:]
    /// The notes with a recognition card that isn't learned.
    private(set) var notes: Set<String> = []

    init(of deck: Deck, calendar: StudyCalendar) {
        unlockDays = deck.learningOptions.productionUnlockDays
        self.calendar = calendar
        isLearned = Array(repeating: true, count: deck.cards.count)
        for (index, card) in deck.cards.enumerated() where Self.isLockable(card, unlockDays: unlockDays) {
            // Counted as learned until `update` finds it isn't, which is what a card that is learned doesn't need.
            isLearned[index] = true
            update(card, at: index)
        }
    }

    private static func isLockable(_ card: Card, unlockDays: Int) -> Bool {
        unlockDays > 0 && card.kind == .recognition && card.note != nil
    }

    /// Takes in the state of `card`, the one at `index` of the deck, as it stands now.
    mutating func update(_ card: Card, at index: Int) {
        guard Self.isLockable(card, unlockDays: unlockDays), let note = card.note else { return }
        let learned = Self.isLearned(card.learningState, unlockDays: unlockDays, calendar: calendar)
        guard learned != isLearned[index] else { return }
        isLearned[index] = learned
        let count = (unlearned[note] ?? 0) + (learned ? -1 : 1)
        unlearned[note] = count > 0 ? count : nil
        if count > 0 { notes.insert(note) } else { notes.remove(note) }
    }

    /// Whether a card in this state is learned: in the review phase with an interval of `unlockDays` or more.
    private static func isLearned(_ state: LearningState?, unlockDays: Int, calendar: StudyCalendar) -> Bool {
        guard let state, state.phase == .review else { return false }
        // An interval of that many study days is more than one day less of time, an hour of daylight saving time aside.
        guard state.due.timeIntervalSince(state.lastReview) > Double(unlockDays - 1) * 86400 - 7200 else { return false }
        return calendar.days(from: state.lastReview, to: state.due) >= unlockDays
    }
}

extension Deck {
    /// How many cards are done on the study day of `now`: those whose last review of the day left them
    /// due after its end (`DeckActivity.done(onDayOf:calendar:)`). It reads the cards only, not the
    /// logs, so the study stream can ask it after every grade to find where it stands in the day's rounds.
    public func doneCards(onDayOf now: Date, calendar: StudyCalendar) -> Int {
        let day = calendar.dayNumber(for: now)
        let start = calendar.start(ofDay: day)
        let end = calendar.start(ofDay: day + 1)
        return cards.reduce(0) { count, card in
            guard let state = card.learningState, state.due >= end, state.lastReview >= start, state.lastReview < end else { return count }
            return count + 1
        }
    }

    /// The cards on their way to done on the study day of `now`, each as the part of a card its reviews
    /// of the day made (`Card.credit(onDayOf:calendar:steps:)`), added up: the cards reviewed that day
    /// that FSRS asks again that day. With the done cards it is what the ring shows, so every answer
    /// recalled moves the ring, not only the one that lets a card go.
    public func cardsUnderway(onDayOf now: Date, calendar: StudyCalendar) -> Double {
        let day = calendar.dayNumber(for: now)
        let start = calendar.start(ofDay: day)
        let end = calendar.start(ofDay: day + 1)
        return cards.reduce(0) { sum, card in
            guard let state = card.learningState, state.due < end, state.lastReview >= start, state.lastReview < end else { return sum }
            return sum + card.credit(onDayOf: now, calendar: calendar, steps: learningOptions.steps)
        }
    }
}

extension Card {
    /// How far the reviews of the study day of `now` brought the card toward done, 0 to 1: 1 once FSRS let
    /// it go to another day; before that the answers recalled that day (Hard, Good, Easy) over those
    /// answers and the learning steps the card still needs, at its best moment of the day. So each answer
    /// recalled moves it, Forgot doesn't, and a Forgot after a recalled answer takes nothing back. A new
    /// card with two steps is half done after a Good; a review card graded Forgot is at 0, and half done
    /// after the Good that follows. The phase and step come from the grades alone, replayed from the
    /// first review; a log that doesn't reach back to it (`hasCompleteLog`) starts as a review card.
    public func credit(onDayOf now: Date, calendar: StudyCalendar, steps required: Int) -> Double {
        let day = calendar.dayNumber(for: now)
        let start = calendar.start(ofDay: day)
        let end = calendar.start(ofDay: day + 1)
        var phase: LearningPhase = hasCompleteLog || log.isEmpty ? .learning : .review
        var step = 0
        var recalled = 0
        var best = 0.0
        for entry in log where entry.date < end {
            switch phase {
            case .review:
                if entry.grade == .again {
                    phase = .relearning
                    step = 0
                }
            case .learning, .relearning:
                var steps = Steps(count: step, required: required)
                steps.apply(entry.grade)
                (phase, step) = steps.areEnough ? (.review, 0) : (phase, steps.count)
            }
            guard entry.date >= start else { continue }
            if entry.grade != .again { recalled += 1 }
            let left = max(1, required) - step
            best = max(best, phase == .review ? 1 : Double(recalled) / Double(recalled + left))
        }
        return best
    }
}

/// The ring, the rounds and the streak of a learner over some decks, see `evaluate(_:at:calendar:)`.
public struct DailyProgress: Hashable, Sendable {
    public var ring: DailyRing
    public var streak: Streak
    /// The cards of today's plan not done yet across the decks: `StudySession.counts(for:at:calendar:).total`,
    /// the "N cards left".
    public var cardsLeft: Int
    /// Of `cardsLeft`, the cards that were new when the day began (`StudyCounts.newAtDayStart`).
    public var newCardsLeft: Int
    /// What one done card takes this learner, new cards and others, `DailyGoal.pace(days:newDone:otherDone:)`.
    public var pace: Pace
    /// The time of today, worked out from the learner's logs: what the day admits new cards up to
    /// (`DailyGoal.nextTime(after:)`).
    public var time: Double
    /// The days that were sized: every study day from the first through today, today last and with its live
    /// figures, which "How Today Works" tells the time from.
    public var ringDays: [DailyGoal.RingDay]
    /// Today's cards cut into rounds, as the plan stood when the day began.
    public var roundPlan: DayRounds
    /// Whether today keeps the streak: its first round is done, or its plan was empty.
    public var streakKeptToday: Bool
    /// How many new cards each deck may introduce today, in the order of the decks given to
    /// `evaluate(_:at:calendar:)`: the plan takes them as `newCardAllowance`. A paused deck has 0
    /// here and no share of the day's new cards; whoever builds its plan leaves the allowance out.
    public var newCardAllowances: [Int]
    /// The words in memory across the decks now, and when the day began (`MemoryEstimate`).
    public var memory: MemoryEstimate
    /// The rings of the last seven study days, today last: closed or not, `nil` before the first study day.
    /// Today's is closed once its ring is.
    public var week: [Bool?]
    /// The cards of the decks by step of `MaturityCategory`, in the order of `allCases`: the ladder of memory.
    public var ladder: [Int]
    /// The cards today's reviews lifted a step up the ladder (`DeckActivity.climbs(onDayOf:calendar:)`).
    public var climbedToday: Int
    /// Every study day from the first through today, today included with its live figures: what the
    /// milestones and achievements are worked out from (`Achievements`).
    public var records: [DayRecord]
    /// Everything earned over `records`, oldest first (`Achievements.earned(over:)`).
    public var achievements: [Achievement]

    public init(
        ring: DailyRing, streak: Streak, cardsLeft: Int = 0, newCardsLeft: Int = 0, pace: Pace = Pace(), time: Double = DailyGoal.initialSeconds,
        roundPlan: DayRounds = DayRounds(otherCards: 0, newCards: 0, pace: Pace(), seconds: DailyGoal.initialSeconds), streakKeptToday: Bool = false,
        newCardAllowances: [Int] = [], memory: MemoryEstimate = MemoryEstimate(words: 0, wordsAtDayStart: 0), week: [Bool?] = [],
        ladder: [Int] = [], climbedToday: Int = 0, records: [DayRecord] = [], achievements: [Achievement] = [],
        ringDays: [DailyGoal.RingDay] = []
    ) {
        self.ringDays = ringDays
        self.records = records
        self.achievements = achievements
        self.week = week
        self.ladder = ladder
        self.climbedToday = climbedToday
        self.ring = ring
        self.streak = streak
        self.cardsLeft = cardsLeft
        self.newCardsLeft = min(max(0, newCardsLeft), max(0, cardsLeft))
        self.pace = pace
        self.time = time
        self.roundPlan = roundPlan
        self.streakKeptToday = streakKeptToday
        self.newCardAllowances = newCardAllowances
        self.memory = memory
    }

    /// The cards left that were not new when the day began.
    public var otherCardsLeft: Int { max(0, cardsLeft) - newCardsLeft }

    /// How long the cards left take, `DailyGoal.minutesLeft(newCards:otherCards:pace:)`.
    public var minutesLeft: Int? { DailyGoal.minutesLeft(newCards: newCardsLeft, otherCards: otherCardsLeft, pace: pace) }

    /// The one price of a card left, for the widget, whose forecast counts cards and not their kinds.
    public var secondsPerCardLeft: Double { pace.secondsPerCard(newCards: newCardsLeft, otherCards: otherCardsLeft) }

    /// How many rounds today holds.
    public var rounds: Int { roundPlan.rounds }

    /// How many of them are done.
    public var roundsDone: Int { roundPlan.roundsDone(cardsDone: ring.done) }

    /// The card counts at which the rounds end; the last is the goal.
    public var roundEnds: [Int] { roundPlan.ends }

    /// The cards to the end of the round the learner is in; `nil` once the rounds are done.
    public var cardsToNextRound: Int? { roundPlan.cardsToNextRound(cardsDone: ring.done) }

    /// The minutes to the end of the round the learner is in, at the pace the day began with, as
    /// `DailyGoal.minutesLeft(newCards:otherCards:pace:)`; `nil` once the rounds are done.
    public var minutesToNextRound: Int? { roundPlan.minutesToNextRound(cardsDone: ring.done) }

    /// The minutes round `number` (from 1) takes at the pace the day began with, `DayRounds.minutes(ofRound:)`:
    /// what the stream tells at the end of a round about the next one, whatever the ring has caught up with.
    public func minutes(ofRound number: Int) -> Int? { roundPlan.minutes(ofRound: number) }

    /// Adds up the cards done and the plans of all `decks`: one ring, one set of rounds and one streak
    /// for the learner, however many decks they study.
    ///
    /// The logs are replayed forward from the first study day (`DeckActivity.history(from:at:calendar:)`).
    /// Each day has a time (`DailyGoal.nextTime(after:)`), which
    /// sets the time of the day: the cards of its plan that were not new, at the pace the day began with
    /// (the seven study days before it), leave the rest to new cards (`DailyGoal.newCardsAllowed`). The
    /// goal of the day is the plan that fits (`DayRounds`); the ring is closed at the goal, and the first
    /// round keeps the streak. Today's new cards are shared among the decks, by their own limits, as
    /// `newCardAllowances`.
    ///
    /// A paused deck (`DeckActivity.isPaused`) takes no part in any of it: not in the plan, the goal, the
    /// rounds, the time, the admission of new cards, the streak, the words in memory or the cards done.
    /// What is reviewed in it counts for the day through the cards of the other decks only.
    ///
    /// With a `cache` that an earlier call over the same decks filled, the days before today that the decks'
    /// own caches kept (`DeckHistoryCache`) are not stepped through again: only today is.
    public static func evaluate(
        _ given: [DeckActivity], at now: Date, calendar: StudyCalendar, planRuleStart: Int = DailyGoal.planRuleStart,
        cache: DailyProgressCache? = nil
    ) -> DailyProgress {
        let decks = given.filter { !$0.isPaused }
        let today = calendar.dayNumber(for: now)
        var reviews: [Int: Int] = [:]
        for deck in decks {
            reviews.merge(deck.reviewsByDay, uniquingKeysWith: +)
        }
        let first = min(reviews.filter { $0.value > 0 }.keys.min() ?? today, today)
        let histories = decks.map { $0.history(from: first, at: now, calendar: calendar) }
        var paced: [Int: [DailyGoal.PacedReview]] = [:]
        var newDoneByDay: [Int: Int] = [:]
        var otherDoneByDay: [Int: Int] = [:]
        for history in histories {
            paced.merge(history.paced.days, uniquingKeysWith: +)
            newDoneByDay.merge(history.paced.newDoneByDay, uniquingKeysWith: +)
            otherDoneByDay.merge(history.paced.otherDoneByDay, uniquingKeysWith: +)
        }
        /// The pace over the study days `days`, as `DailyGoal.pace(days:newDone:otherDone:)` takes them.
        func pace(over days: ClosedRange<Int>) -> Pace {
            DailyGoal.pace(
                days: days.compactMap { paced[$0] }, newDone: days.reduce(0) { $0 + (newDoneByDay[$1] ?? 0) },
                otherDone: days.reduce(0) { $0 + (otherDoneByDay[$1] ?? 0) })
        }

        /// How each day before today was sized and stood, and which of them kept the streak and closed their rings.
        func daysBeforeToday() -> DailyProgressCache.Before {
            var days: [DailyGoal.RingDay] = []
            var kept: [Int: Bool] = [:]
            var closed: [Int: Bool] = [:]
            var goals: [Int: Int] = [:]
            var dones: [Int: Int] = [:]
            for day in first..<today {
                let size = DailyGoal.nextTime(after: days)
                let pace = pace(over: (day - DailyGoal.paceDays)...(day - 1))
                let other = histories.reduce(0) { $0 + ($1.starts[day]?.other ?? 0) }
                let allowed = DailyGoal.newCardsAllowed(seconds: size.time, otherCards: other, pace: pace)
                let rounds = DayRounds(otherCards: other, newCards: min(allowed, histories.reduce(0) { $0 + ($1.starts[day]?.new ?? 0) }), pace: pace, seconds: size.time)
                let newDone = newDoneByDay[day] ?? 0
                let otherDone = otherDoneByDay[day] ?? 0
                let done = newDone + otherDone
                closed[day] = done >= rounds.goal
                kept[day] = rounds.ends.first.map { done >= $0 } ?? true
                goals[day] = rounds.goal
                dones[day] = done
                days.append(
                    DailyGoal.RingDay(
                        day: day, time: size.time, reason: size.reason, worked: pace.seconds(newCards: newDone, otherCards: otherDone),
                        closed: done >= rounds.goal, studied: done > 0, filled: rounds.filled))
            }
            return DailyProgressCache.Before(days: days, kept: kept, closed: closed, goals: goals, done: dones)
        }
        // The days before today are the same while the decks' own days before today are: each history says
        // which it comes from.
        let pasts = histories.compactMap(\.pastID)
        let key = pasts.count == histories.count ? DailyProgressCache.Key(pasts: pasts, first: first, today: today, calendar: calendar) : nil
        let before: DailyProgressCache.Before
        if let key, let known = cache?.before(for: key) {
            before = known
        } else {
            before = daysBeforeToday()
            if let key { cache?.keep(before, for: key) }
        }
        var kept = before.kept
        var closed = before.closed

        let size = DailyGoal.nextTime(after: before.days)
        let time = size.time
        let startPace = pace(over: (today - DailyGoal.paceDays)...(today - 1))
        let other = histories.reduce(0) { $0 + ($1.starts[today]?.other ?? 0) }
        let allowed = DailyGoal.newCardsAllowed(seconds: time, otherCards: other, pace: startPace)
        let allowances = DailyGoal.split(allowed, overCeilings: histories.map(\.newCeilingToday))
        let startNew = zip(allowances, histories).reduce(0) { $0 + min($1.0, $1.1.starts[today]?.new ?? 0) }
        let startRounds = DayRounds(otherCards: other, newCards: startNew, pace: startPace, seconds: time)

        let counts = decks.indices.map { decks[$0].owed(now: now, calendar: calendar, newCardAllowance: allowances[$0]) }
        let owed = counts.reduce(0) { $0 + $1.total }
        let owedNew = counts.reduce(0) { $0 + $1.newAtDayStart }
        let done = decks.reduce(0) { $0 + $1.done(onDayOf: now, calendar: calendar) }
        let underway = decks.reduce(0) { $0 + $1.underway(onDayOf: now, calendar: calendar) }
        let ring = DailyRing(done: done, goal: DailyGoal.goal(done: done, owed: owed, plan: startRounds.goal), underway: underway)
        // A day that began with an empty plan has the plan as it stands, which is new cards the learner
        // is doing: they are its rounds.
        let roundPlan =
            startRounds.goal > 0
            ? startRounds : DayRounds(otherCards: owed - owedNew, newCards: done + owedNew, pace: startPace, seconds: time)
        let isKeptToday = startRounds.ends.first.map { done >= $0 } ?? true
        // Today is closed by its ring: cards added after the day began are laps, not debt.
        kept[today] = isKeptToday
        closed[today] = ring.isGoalMet
        let (streak, steps) = Streak.walk(
            reviews: reviews, today: today, planRuleStart: planRuleStart, isKept: { kept[$0] ?? false }, isClosed: { closed[$0] ?? false },
            repairCards: max(0, ring.goal - ring.done))
        let ringToday = DailyGoal.RingDay(
            day: today, time: time, reason: size.reason,
            worked: startPace.seconds(newCards: newDoneByDay[today] ?? 0, otherCards: otherDoneByDay[today] ?? 0), closed: ring.isGoalMet, studied: ring.done > 0,
            filled: startRounds.filled)
        let records = (first...today).map { day in
            DayRecord(
                day: day, done: day == today ? ring.done : before.done[day] ?? 0, goal: day == today ? ring.goal : before.goals[day] ?? 0,
                kept: kept[day] ?? false, closed: closed[day] ?? false, streak: day == today ? streak.days : steps[day]?.days ?? 0,
                savedStreak: steps[day]?.saved ?? false)
        }
        // In the order of the decks given: the shares of the decks that take part, 0 for a paused one.
        var shares = allowances.makeIterator()
        let givenAllowances = given.map { $0.isPaused ? 0 : shares.next() ?? 0 }
        return DailyProgress(
            ring: ring, streak: streak, cardsLeft: owed, newCardsLeft: owedNew, pace: pace(over: (today - DailyGoal.paceDays)...today), time: time,
            roundPlan: roundPlan, streakKeptToday: isKeptToday, newCardAllowances: givenAllowances,
            memory: MemoryEstimate.total(decks.map { $0.memory(at: now, calendar: calendar) }),
            week: (today - 6...today).map { $0 < first ? nil : closed[$0] ?? false },
            ladder: decks.map { $0.ladder() }.reduce(into: [Int](repeating: 0, count: MaturityCategory.allCases.count)) { sum, steps in
                for index in sum.indices { sum[index] += steps[index] }
            },
            climbedToday: decks.reduce(0) { $0 + $1.climbs(onDayOf: now, calendar: calendar) }, records: records,
            achievements: Achievements.earned(over: records), ringDays: before.days + [ringToday])
    }
}
