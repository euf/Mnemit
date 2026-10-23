import Foundation

/// What the figures of a `DailyProgress` are made of, for the screen that shows how the day works: the
/// parts of the plan, how the day's new cards are shared among the decks, the time and the ring of
/// the last days, and what the pace is worked out from. Read-only, and derived from the same decks and
/// logs as the progress it is made for, so it shows what the progress holds and nothing else.
// ponytail: the pace window below follows `DailyGoal.pace(days:newDone:otherDone:)` line by line, because
// that keeps its steps to itself; `DayBreakdownTests` holds the two together. The days of the time are
// the ones `DailyProgress.evaluate` stepped through (`DailyProgress.ringDays`), not a second loop.
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
        /// The seconds of work the day's ring asked.
        public var time: Double
        /// Whether the day's ring was closed (done at least the goal); today's only for now.
        public var isClosed: Bool
        /// The seconds of work the day's cards took at the day's own prices; today's so far.
        public var worked: Double = 0
        /// Why the day had its size; `nil` under `DailyGoal.RingRule.rounds`.
        public var reason: DailyGoal.SizeReason?
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

    /// The rule that sized the days.
    public var rule: DailyGoal.RingRule = DailyGoal.ringRule
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
    /// the same decks: `lastDays` study days of time and rings are kept.
    ///
    /// A paused deck (`DeckActivity.isPaused`) is left out, as `evaluate` leaves it: its entry in `decks` is
    /// all zeros.
    public init(_ given: [DeckActivity], progress: DailyProgress, at now: Date, calendar: StudyCalendar, lastDays: Int = 14) {
        let decks = given.filter { !$0.isPaused }
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
        // The size and the ring of every day, from the first study day on, as `evaluate` stepped through them.
        let sized = progress.ringDays
        rule = progress.ringRule
        days = sized.suffix(lastDays).map { day in
            Day(
                start: calendar.start(ofDay: day.day), time: day.time, isClosed: day.closed, worked: day.worked, reason: day.reason)
        }

        // The plan at the day's start, by kind, and each deck's part of the new cards.
        var plan = Plan()
        var shares: [DeckNewCards] = []
        var catchUp = 0
        var taking = 0
        for (index, deck) in given.enumerated() {
            guard !deck.isPaused else {
                shares.append(DeckNewCards(allowance: 0, ceiling: 0, admitted: 0))
                continue
            }
            let history = histories[taking]
            taking += 1
            let atStart = deck.plan(onDayOf: now, calendar: calendar)
            plan.reviewsDue += atStart.review - atStart.backlogTaken
            plan.backlogTaken += atStart.backlogTaken
            plan.backlog += atStart.backlogTaken + atStart.catchUp
            plan.learning += atStart.learning
            let allowance = progress.newCardAllowances.indices.contains(index) ? progress.newCardAllowances[index] : 0
            let admitted = min(allowance, history.starts[today]?.new ?? 0)
            plan.newAdmitted += admitted
            shares.append(DeckNewCards(allowance: allowance, ceiling: history.newCeilingToday, admitted: admitted))
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
