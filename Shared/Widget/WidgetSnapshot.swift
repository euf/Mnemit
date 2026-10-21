import Foundation
import VocabCore

/// Where a tap on the widget goes: `mnemit://study` starts the study stream.
enum WidgetLink {
    static let scheme = "mnemit"
    static let study = URL(string: "mnemit://study")!

    static func isStudy(_ url: URL) -> Bool {
        url.scheme == scheme && url.host() == "study"
    }
}

/// What the widget shows, written by the app and read by the widget extension, which can't
/// read the decks itself: the figures of the daily ring, the streak, and how many cards fall
/// due in each of the next hours, so the timeline grows without the app running.
///
/// Stored as JSON in a keychain item both targets share (`SnapshotStore`). A snapshot is
/// small, a few kilobytes.
struct WidgetSnapshot: Codable, Equatable, Sendable {
    /// The cards due across all known decks at `date`, as the plan of a study session counts
    /// them (`StudySession.counts(for:at:calendar:)`).
    struct Due: Codable, Equatable, Sendable {
        var date: Date
        var count: Int
    }

    /// When the snapshot was made.
    var date: Date
    /// Graded reviews today (the study day), and the goal of the day: 20, or the plan if it
    /// is smaller (`DailyGoal`).
    var reviews: Int
    var goal: Int
    /// Days in the streak, today's included once its goal is met.
    var streakDays: Int
    /// Whether today's goal is met, so today keeps the streak.
    var isGoalMet: Bool
    /// Cards due at `date`, then at each full hour after it, in order.
    var due: [Due]
    /// The next daily reminder, if one is scheduled.
    var nextReminder: Date?

    /// How many times the goal was reached: 2 from 200 %.
    var laps: Int { reviews / max(1, goal) }

    /// How far ahead the forecast reaches.
    static let forecastHours = 48

    init(date: Date, reviews: Int, goal: Int, streakDays: Int, isGoalMet: Bool, due: [Due], nextReminder: Date?) {
        self.date = date
        self.reviews = reviews
        self.goal = goal
        self.streakDays = streakDays
        self.isGoalMet = isGoalMet
        self.due = due
        self.nextReminder = nextReminder
    }

    /// A snapshot of `progress`, with the due counts of each deck at `dates` (one array per
    /// deck, as long as `dates`) added up.
    init(now: Date, progress: DailyProgress, dates: [Date], dueByDeck: [[Int]], nextReminder: Date?) {
        let totals = dates.indices.map { index in dueByDeck.reduce(0) { $0 + ($1.indices.contains(index) ? $1[index] : 0) } }
        self.init(
            date: now, reviews: progress.ring.reviews, goal: progress.ring.goal, streakDays: progress.streak.days,
            isGoalMet: progress.ring.isGoalMet, due: zip(dates, totals).map { Due(date: $0, count: $1) }, nextReminder: nextReminder)
    }

    /// The moments the forecast looks at: `now`, then each full hour after it.
    static func forecastDates(from now: Date, hours: Int = forecastHours, calendar: Calendar = .current) -> [Date] {
        guard let first = calendar.nextDate(after: now, matching: DateComponents(minute: 0, second: 0), matchingPolicy: .nextTime) else {
            return [now]
        }
        return [now] + (0..<hours).map { first.addingTimeInterval(Double($0) * 3600) }
    }

    /// The cards due across `decks` at each of `dates`.
    static func dueCounts(of decks: [Deck], at dates: [Date], calendar: StudyCalendar) -> [Int] {
        dates.map { date in decks.reduce(0) { $0 + StudySession.counts(for: $1, at: date, calendar: calendar).total } }
    }
}

// MARK: Coding

extension WidgetSnapshot {
    func encoded() throws -> Data {
        try Self.encoder.encode(self)
    }

    static func decoded(from data: Data) -> WidgetSnapshot? {
        try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}

// MARK: What the widget shows at a moment

/// The figures of one timeline entry.
struct WidgetState: Equatable, Sendable {
    var date: Date
    var reviews: Int
    var goal: Int
    var streakDays: Int
    var isGoalMet: Bool
    var due: Int
    /// The next reminder, `nil` once it is past.
    var nextReminder: Date?

    /// The ring and the streak as `DailyRingView` takes them.
    var progress: DailyProgress {
        DailyProgress(ring: DailyRing(reviews: reviews, goal: goal), streak: Streak(days: streakDays, repairReviews: nil))
    }

    /// The same figures at another moment of the timeline.
    func isSame(as other: WidgetState) -> Bool {
        var moved = self
        moved.date = other.date
        return moved == other
    }
}

extension WidgetSnapshot {
    /// How the figures stand at `moment`, `date` or later.
    ///
    /// On the study day of the snapshot they are the snapshot's, with the due count that was
    /// forecast for the hour. Once a study day has begun, today's reviews are 0 and its goal
    /// is the plan, as forecast for the moment, up to 20. The streak holds through one missed
    /// day, which the reviews of the next make up for, and ends with a second one, as in
    /// `Streak.evaluate`; a day on which the goal was not met counts as missed.
    func state(at moment: Date, calendar: StudyCalendar = StudyCalendar()) -> WidgetState {
        let count = dueCount(at: moment)
        let reminder = nextReminder.flatMap { $0 > moment ? $0 : nil }
        let days = calendar.dayNumber(for: moment) - calendar.dayNumber(for: date)
        guard days > 0 else {
            return WidgetState(
                date: moment, reviews: reviews, goal: goal, streakDays: streakDays, isGoalMet: isGoalMet, due: count, nextReminder: reminder)
        }
        let missed = days - (isGoalMet ? 1 : 0)
        return WidgetState(
            date: moment, reviews: 0, goal: min(DailyGoal.reviewsPerDay, max(1, count)), streakDays: missed >= 2 ? 0 : streakDays,
            isGoalMet: false, due: count, nextReminder: reminder)
    }

    /// The cards due at `moment`: the last forecast at or before it, the first one if none is.
    func dueCount(at moment: Date) -> Int {
        (due.last { $0.date <= moment } ?? due.first)?.count ?? 0
    }

    /// The entries of a widget timeline from `now`: one now, and one at each moment the
    /// picture changes within two days: the hours of the forecast, the start of each study
    /// day, and the reminder. Entries that look like the one before are left out.
    func timeline(from now: Date, calendar: StudyCalendar = StudyCalendar()) -> [WidgetState] {
        var moments: Set<Date> = [now]
        moments.formUnion(due.map(\.date).filter { $0 > now })
        if let nextReminder, nextReminder > now { moments.insert(nextReminder) }
        let end = now.addingTimeInterval(Double(Self.forecastHours) * 3600)
        var day = calendar.dayNumber(for: now) + 1
        var start = calendar.start(ofDay: day)
        while start <= end {
            moments.insert(start)
            day += 1
            start = calendar.start(ofDay: day)
        }

        var entries: [WidgetState] = []
        for moment in moments.sorted() {
            let state = state(at: moment, calendar: calendar)
            if let last = entries.last, last.isSame(as: state) { continue }
            entries.append(state)
        }
        return entries
    }
}
