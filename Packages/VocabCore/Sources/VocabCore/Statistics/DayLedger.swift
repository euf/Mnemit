import Foundation

/// One study day of the progress ledger: what the day stood at when it was over, so that pausing or deleting a deck or
/// a card cannot rewrite it (`DayLedger`). Plain values: the size the day had, how it ended, and the words learned
/// by its end.
///
/// A record only rises (`raised(reviews:done:worked:wordsLearned:)`): real reviews of the day that arrive late, another
/// device's log or an import, lift it; a log that says less leaves it as it was. A record of an older `rule` than
/// `currentRule` was written by code that is known to have counted wrongly: `DailyProgress.evaluate` works the day out
/// from the logs again instead of raising it.
public struct LedgerDay: Hashable, Sendable {
    /// The rule that writes records now. 1: a deck counts once per day (rule 0 counted a deck that a document held
    /// twice, and its past days stayed inflated for good), and a day nothing could be asked of is idle.
    public static let currentRule = 1

    /// The study day number (`StudyCalendar.dayNumber`).
    public var day: Int
    /// The entries of the logs on the day.
    public var reviews: Int
    /// The cards done.
    public var done: Int
    /// The day's goal, `DayRounds.goal`.
    public var goal: Int
    /// The cards done that keep the streak, the end of the first round (`DayRounds.ends.first`); 0 when the plan was empty.
    public var keepAt: Int
    /// The first round was done, or the plan was empty.
    public var kept: Bool
    /// The ring was closed, `done >= goal`.
    public var closed: Bool
    /// The seconds of work the day asked (`DailyGoal.RingDay.time`).
    public var time: Double
    /// Why the day had that size.
    public var reason: DailyGoal.SizeReason
    /// The cards done at the day's own prices, in seconds (`DailyGoal.RingDay.worked`).
    public var worked: Double
    /// The goal took the day's time (`DayRounds.filled`).
    public var filled: Bool
    /// The words that had left learning by the end of the day (`WordsLearned.cumulative`).
    public var wordsLearned: Int
    /// The rule that wrote the record (`currentRule`); 0 for a record of a file without the key.
    public var rule: Int

    /// `kept` and `closed` are what `done` says unless given.
    public init(
        day: Int, reviews: Int, done: Int, goal: Int, keepAt: Int, kept: Bool? = nil, closed: Bool? = nil, time: Double,
        reason: DailyGoal.SizeReason, worked: Double, filled: Bool, wordsLearned: Int, rule: Int = LedgerDay.currentRule
    ) {
        self.day = day
        self.reviews = reviews
        self.done = done
        self.goal = goal
        self.keepAt = keepAt
        self.kept = kept ?? (done >= keepAt)
        self.closed = closed ?? (done >= goal)
        self.time = time
        self.reason = reason
        self.worked = worked
        self.filled = filled
        self.wordsLearned = wordsLearned
        self.rule = rule
    }

    /// An empty plan that nobody could have worked, nothing done: every deck paused or every card suspended
    /// (`DayRecord.isIdle`). It is the one record with `goal` 0 that is not `kept`: the day neither keeps the streak nor
    /// breaks it, and counts for no medal. An exhausted deck, with nothing due, is not idle: it keeps the streak.
    public var isIdle: Bool { goal == 0 && !kept && done == 0 }

    /// The day as the size rule reads it (`DailyGoal.nextTime(after:)`).
    public var ringDay: DailyGoal.RingDay {
        DailyGoal.RingDay(day: day, time: time, reason: reason, worked: worked, closed: closed, studied: done > 0, filled: filled)
    }

    /// The day with what the logs say of it now: the larger of each count, `kept` and `closed` once the cards done
    /// reach their marks. The size (`goal`, `keepAt`, `time`, `reason`, `filled`) never changes. `worked` is the work of
    /// the cards done at the prices of the logs now, so it moves with `done` alone: a price that changed since (a deck
    /// paused or deleted) says nothing of the day.
    public func raised(reviews: Int, done: Int, worked: Double, wordsLearned: Int) -> LedgerDay {
        var raised = self
        raised.reviews = max(self.reviews, reviews)
        raised.done = max(self.done, done)
        if done > self.done { raised.worked = max(self.worked, worked) }
        raised.wordsLearned = max(self.wordsLearned, wordsLearned)
        // An idle day stays idle until something is done in it.
        if !(isIdle && raised.done == 0) {
            raised.kept = kept || raised.done >= keepAt
            raised.closed = closed || raised.done >= goal
        }
        return raised
    }

    fileprivate static func tenths(_ seconds: Double) -> Double { (seconds * 10).rounded() }
}

/// The progress ledger: one `LedgerDay` per study day, frozen once the day is over, filled from the logs on first
/// run and merged by day across devices. The past reads from it and today from the logs
/// (`DailyProgress.evaluate(_:at:calendar:planRuleStart:ledger:cache:)`), so progress never goes back.
///
/// The file is JSON Lines, one record per day, oldest first (`encoded()`, `decode(_:)`).
public struct DayLedger: Hashable, Sendable {
    public var days: [Int: LedgerDay]

    public init(days: [Int: LedgerDay] = [:]) {
        self.days = days
    }

    /// Both ledgers' days; of a day in both, the record that is more: the newer `rule`, then the larger `done`,
    /// `reviews`, `wordsLearned` and `goal`, then the smaller encoded line. A device that has not learned the new rule
    /// yet cannot lift a day back to its old figures. Commutative and idempotent.
    public func merging(_ other: DayLedger) -> DayLedger {
        DayLedger(days: days.merging(other.days, uniquingKeysWith: Self.winner))
    }

    /// The ledger with `updates` merged in (`DailyProgress.ledgerUpdates`).
    public func updating(_ updates: [LedgerDay]) -> DayLedger {
        merging(DayLedger(days: Dictionary(updates.map { ($0.day, $0) }, uniquingKeysWith: Self.winner)))
    }

    private static func winner(_ a: LedgerDay, _ b: LedgerDay) -> LedgerDay {
        let keys = [(a.rule, b.rule), (a.done, b.done), (a.reviews, b.reviews), (a.wordsLearned, b.wordsLearned), (a.goal, b.goal)]
        for (x, y) in keys where x != y { return x > y ? a : b }
        return line(a) <= line(b) ? a : b
    }

    // MARK: - File

    /// One record of the file: dates as ISO strings, seconds to a tenth.
    private struct Record: Codable {
        var day: String
        var reviews: Int
        var done: Int
        var goal: Int
        var keep: Int
        var kept: Bool
        var closed: Bool
        var time: Double
        var reason: String
        var worked: Double
        var filled: Bool
        var words: Int
        /// Missing in the files of rule 0.
        var rule: Int?

        init(_ day: LedgerDay) {
            self.day = CivilDate(dayNumber: day.day).isoString
            reviews = day.reviews
            done = day.done
            goal = day.goal
            keep = day.keepAt
            kept = day.kept
            closed = day.closed
            time = LedgerDay.tenths(day.time) / 10
            reason = day.reason.name
            worked = LedgerDay.tenths(day.worked) / 10
            filled = day.filled
            words = day.wordsLearned
            rule = day.rule
        }

        var ledgerDay: LedgerDay? {
            guard let date = CivilDate(isoString: day) else { return nil }
            return LedgerDay(
                day: date.dayNumber, reviews: max(0, reviews), done: max(0, done), goal: max(0, goal), keepAt: max(0, keep), kept: kept,
                closed: closed, time: time, reason: DailyGoal.SizeReason(name: reason), worked: worked, filled: filled,
                wordsLearned: max(0, words), rule: max(0, rule ?? 0))
        }
    }

    private static func line(_ day: LedgerDay) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(Record(day))).map { String(decoding: $0, as: UTF8.self) } ?? ""
    }

    /// The file: a line of JSON for each day, oldest first.
    public func encoded() -> Data {
        Data(days.values.sorted { $0.day < $1.day }.map { Self.line($0) + "\n" }.joined().utf8)
    }

    /// Reads a file. A line that can't be read is skipped, so a damaged line costs its day only; never throws.
    public static func decode(_ data: Data) -> DayLedger {
        let decoder = JSONDecoder()
        var ledger = DayLedger()
        for line in data.split(separator: 0x0A) {
            guard let day = (try? decoder.decode(Record.self, from: line))?.ledgerDay else { continue }
            ledger.days[day.day] = ledger.days[day.day].map { winner($0, day) } ?? day
        }
        return ledger
    }
}

extension DailyGoal.SizeReason {
    fileprivate var name: String {
        switch self {
        case .start: "start"
        case .ringClosed: "ringClosed"
        case .closedInARow: "closedInARow"
        case .ringOpen: "ringOpen"
        case .smallPlan: "smallPlan"
        case .sustainedOvershoot: "sustainedOvershoot"
        }
    }

    /// An unknown name reads as `ringOpen`.
    fileprivate init(name: String) {
        switch name {
        case "start": self = .start
        case "ringClosed": self = .ringClosed
        case "closedInARow": self = .closedInARow
        case "smallPlan": self = .smallPlan
        case "sustainedOvershoot": self = .sustainedOvershoot
        default: self = .ringOpen
        }
    }
}
