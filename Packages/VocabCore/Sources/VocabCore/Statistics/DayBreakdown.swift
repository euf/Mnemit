import Foundation

/// What the figures of a `DailyProgress` are made of, for the screen that shows how the day works: the
/// parts of the plan, how the day's new cards are shared among the decks, the capacity and the ring of
/// the last days, and what the pace is worked out from. Read-only, and derived from the same decks and
/// logs as the progress it is made for, so it shows what the progress holds and nothing else.
// ponytail: the per-day loop and the pace window below follow `DailyProgress.evaluate` and
// `DailyGoal.pace(days:newDone:otherDone:)` line by line, because those keep their steps to themselves;
// `DayBreakdownTests` holds the two together. Let `evaluate` build on this loop if the rules change again.
public struct DayBreakdown: Hashable, Sendable {
    /// The plan as it stood when the study day began, over all decks.
    public struct Plan: Hashable, Sendable {
        /// Review cards due on the day itself.
        public var reviewsDue = 0
        /// Overdue review cards the plan takes: the share of the backlog (`DailyGoal.backlogShare(of:onTime:)`).
        public var backlogTaken = 0
        /// The overdue review cards in all: the ones taken and those left for catch-up.
        public var backlog = 0
        /// Cards in learning or relearning.
        public var learning = 0
        /// New cards the day admits, the allowance within each deck's ceiling.
        public var newAdmitted = 0
    }

    /// What one deck takes of the day's new cards, in the order of the decks given.
    public struct DeckNewCards: Hashable, Sendable {
        /// The deck's share of the new cards the day's time admits (`DailyProgress.newCardAllowances`).
        public var allowance: Int
        /// The new cards the deck's own limits take: `newCardsPerSession` and `newProductionPerSession`.
        public var ceiling: Int
        /// The new cards the deck admits: its allowance, no more than its ceiling.
        public var admitted: Int
    }

    /// A study day of the history.
    public struct Day: Hashable, Sendable {
        /// When the study day began.
        public var start: Date
        /// How many rounds the day held.
        public var capacity: Int
        /// The step from the capacity of the day before: +1, 0 or -1; 0 on the first day.
        public var step: Int
        /// Whether the day's ring was closed (done at least the goal); today's only for now.
        public var isClosed: Bool
    }

    /// Where a kind of card gets its price in seconds (`DailyGoal.pace(days:newDone:otherDone:)`).
    public enum PaceSource: Hashable, Sendable {
        /// The mean of the logged durations of its reviews.
        case durations
        /// The median of the gaps between reviews, for logs without durations.
        case gaps
        /// `DailyGoal.fallbackNewCardSeconds` or `fallbackOtherCardSeconds`: too little to go on.
        case fallback
    }

    /// What the price of one kind of card, new or other, is worked out from: the reviews and the done cards of
    /// the pace window, the seven study days before today and today.
    public struct PaceBasis: Hashable, Sendable {
        /// Reviews of this kind with a logged duration.
        public var durations: Int
        /// Gaps between reviews that fall to cards of this kind.
        public var gaps: Int
        /// Reviews of the cards of this kind that were done on the day they were reviewed.
        public var reviews: Int
        /// The cards of this kind that were done.
        public var doneCards: Int

        /// The source of the price, by the rule of `DailyGoal.pace(days:newDone:otherDone:)`.
        public var source: PaceSource {
            guard doneCards >= DailyGoal.paceMinimumCards else { return .fallback }
            if durations >= DailyGoal.paceMinimumGaps { return .durations }
            return gaps >= DailyGoal.paceMinimumGaps ? .gaps : .fallback
        }

        /// How many reviews each done card took; `nil` without done cards.
        public var reviewsPerCard: Double? {
            doneCards > 0 ? Double(reviews) / Double(doneCards) : nil
        }
    }

    public var plan: Plan
    /// One entry for each deck, in the order of the decks given.
    public var decks: [DeckNewCards]
    /// The overdue review cards the plan leaves for after it, now (`StudyCounts.catchUp`), over all decks.
    public var catchUp: Int
    /// The last study days, today last, as many as the history has.
    public var days: [Day]
    public var newCards: PaceBasis
    public var otherCards: PaceBasis
}

extension DayBreakdown {
    /// Takes apart the `progress` of `decks` at `now`, which `DailyProgress.evaluate(_:at:calendar:)` gave for
    /// the same decks: `lastDays` study days of capacity and rings are kept.
    public init(_ decks: [DeckActivity], progress: DailyProgress, at now: Date, calendar: StudyCalendar, lastDays: Int = 14) {
        let today = calendar.dayNumber(for: now)
        var reviews: [Int: Int] = [:]
        for deck in decks { reviews.merge(deck.reviewsByDay, uniquingKeysWith: +) }
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
        /// The pace over the study days `window`, as `DailyProgress.evaluate` takes it.
        func pace(over window: ClosedRange<Int>) -> Pace {
            DailyGoal.pace(
                days: window.compactMap { paced[$0] }, newDone: window.reduce(0) { $0 + (newDoneByDay[$1] ?? 0) },
                otherDone: window.reduce(0) { $0 + (otherDoneByDay[$1] ?? 0) })
        }

        // The capacity and the ring of every day, from the first study day on, as `evaluate` steps through them.
        var capacity = DailyGoal.initialCapacity
        var closed: [Int: Bool] = [:]
        var history: [Day] = []
        for day in first...today {
            let before = capacity
            if day > first {
                capacity = DailyGoal.nextCapacity(after: capacity, yesterdayClosed: closed[day - 1] ?? false, dayBeforeClosed: closed[day - 2] ?? false)
            }
            if day < today {
                let other = histories.reduce(0) { $0 + ($1.starts[day]?.other ?? 0) }
                let new = histories.reduce(0) { $0 + ($1.starts[day]?.new ?? 0) }
                let pace = pace(over: (day - DailyGoal.paceDays)...(day - 1))
                let allowed = DailyGoal.newCardsAllowed(capacity: capacity, otherCards: other, pace: pace)
                let rounds = DayRounds(otherCards: other, newCards: min(allowed, new), pace: pace, capacity: capacity)
                closed[day] = (newDoneByDay[day] ?? 0) + (otherDoneByDay[day] ?? 0) >= rounds.goal
            } else {
                closed[day] = progress.ring.isGoalMet
            }
            history.append(Day(start: calendar.start(ofDay: day), capacity: capacity, step: day > first ? capacity - before : 0, isClosed: closed[day] ?? false))
        }
        days = Array(history.suffix(lastDays))

        // The plan at the day's start, by kind, and each deck's part of the new cards.
        var plan = Plan()
        var shares: [DeckNewCards] = []
        var catchUp = 0
        for (index, deck) in decks.enumerated() {
            let atStart = deck.plan(onDayOf: now, calendar: calendar)
            plan.reviewsDue += atStart.review - atStart.backlogTaken
            plan.backlogTaken += atStart.backlogTaken
            plan.backlog += atStart.backlogTaken + atStart.catchUp
            plan.learning += atStart.learning
            let allowance = progress.newCardAllowances.indices.contains(index) ? progress.newCardAllowances[index] : 0
            let admitted = min(allowance, histories[index].starts[today]?.new ?? 0)
            plan.newAdmitted += admitted
            shares.append(DeckNewCards(allowance: allowance, ceiling: histories[index].newCeilingToday, admitted: admitted))
            catchUp += deck.owed(now: now, calendar: calendar, newCardAllowance: allowance).catchUp
        }
        self.plan = plan
        self.decks = shares
        self.catchUp = catchUp

        // What today's pace is worked out from: the same window as `progress.pace`.
        let window = (today - DailyGoal.paceDays)...today
        let windowDays = window.compactMap { paced[$0] }
        func basis(isNew: Bool, doneByDay: [Int: Int]) -> PaceBasis {
            let ofKind = windowDays.flatMap { $0 }.filter { $0.isNew == isNew }
            let gaps = windowDays.reduce(0) { total, day in
                let sorted = day.sorted { $0.date < $1.date }
                return total + zip(sorted, sorted.dropFirst()).filter { $0.1.isNew == isNew }.count
            }
            return PaceBasis(
                durations: ofKind.filter { $0.duration != nil }.count, gaps: gaps, reviews: ofKind.filter(\.isDone).count,
                doneCards: window.reduce(0) { $0 + (doneByDay[$1] ?? 0) })
        }
        newCards = basis(isNew: true, doneByDay: newDoneByDay)
        otherCards = basis(isNew: false, doneByDay: otherDoneByDay)
    }
}
