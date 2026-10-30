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
/// read the decks itself: the figures of the daily ring, the streak, and the cards left of the
/// plan at each of the next hours, so the timeline grows without the app running.
///
/// Stored as JSON in a keychain item both targets share (`SnapshotStore`). A snapshot is
/// small, a few kilobytes.
struct WidgetSnapshot: Codable, Equatable, Sendable {
    /// The cards of the plan across all known decks at `date`, as the day's plan counts
    /// them (`StudySession.counts(for:at:calendar:newCardAllowance:)`): every card due, overdue ones included.
    struct Due: Codable, Equatable, Sendable {
        var date: Date
        var count: Int
    }

    /// When the snapshot was made.
    var date: Date
    /// The cards done today (the study day), and the daily goal: the cards of the plan
    /// as FSRS set it when the day began (`DailyGoal`). The unit of both is the card.
    var done: Int
    var goal: Int
    /// Days in the streak, today's included once its goal is met.
    var streakDays: Int
    /// Whether today's goal is met, so today keeps the streak.
    var isGoalMet: Bool
    /// The cards left of the plan at `date`, then of the plan at each full hour after it, in order.
    var due: [Due]
    /// The next daily reminder, if one is scheduled.
    var nextReminder: Date?
    /// The one price of a card left when the snapshot is made (`DailyProgress.secondsPerCardLeft`): the
    /// time the cards left take at the pace of new cards and of others, over their number, and the pace of
    /// the others when none is left. The widget can't read the logs and knows only how many cards each hour
    /// of the forecast holds, so it prices them all with it.
    /// `nil` in a snapshot an older app wrote: no time then.
    var secondsPerCard: Double?
    /// The rounds today holds (`DailyProgress.rounds`) and how many are done, and the minutes to the end of the
    /// round the learner is in (`DailyProgress.minutesToNextRound`; `nil` once the rounds are done).
    /// `nil` in a snapshot an older app wrote: the widget then has no time for the streak step.
    var rounds: Int?
    var roundsDone: Int?
    var minutesToNextRound: Int?
    /// The words in memory now, rounded down, and what today added (`MemoryEstimate.shownWords`, `.shownGain`).
    /// `nil` in a snapshot an older app wrote.
    var wordsInMemory: Int?
    var wordsToday: Int?
    /// The cards by step of the ladder of memory (`DailyProgress.ladder`); `nil` in a snapshot an older app wrote.
    var ladder: [Int]?
    /// The day after a missed one, with the ring still open (`DailyProgress.isStreakAtRisk`): the flame's outline turns
    /// to the streak's colour. `nil` in a snapshot an older app wrote: not at risk.
    var isStreakAtRisk: Bool?
    /// The rings of the last seven study days, today last (`DailyProgress.week`); `nil` in a snapshot an older app
    /// wrote, and then the medium widget has no week.
    var week: [Bool?]?
    /// The same days as they are drawn, each ring in laps of its goal (`DailyProgress.weekRings`, up to 3, `nil` before
    /// the first study day); an optional key, so the app and the widget of different builds still read each other: without
    /// it a past day is full when it closed and empty otherwise.
    var weekRings: [Double?]?
    /// The words learned now and what today added (`WordsLearned.words`, `.shownGain`), the third figure of the medium widget;
    /// `nil` in a snapshot an older app wrote, and then the widget leaves the figure out.
    var wordsLearned: Int?
    var wordsLearnedToday: Int?
    /// The seconds of work the day asks (`DailyProgress.time`): what the goal of a day that begins after the snapshot is cut
    /// at, as the app cuts it when it runs (`state(at:)`). `nil` in a snapshot an older app wrote: that goal is the plan.
    var daySeconds: Double?

    /// How far ahead the forecast reaches.
    static let forecastHours = 48

    /// The JSON key of `done` is "reviews": a snapshot stored by an older app has that key.
    private enum CodingKeys: String, CodingKey {
        case date
        case done = "reviews"
        case goal, streakDays, isGoalMet, due, nextReminder, secondsPerCard
        case rounds, roundsDone, minutesToNextRound, wordsInMemory, wordsToday, ladder, isStreakAtRisk, week, weekRings, wordsLearned, wordsLearnedToday, daySeconds
    }

    init(
        date: Date, done: Int, goal: Int, streakDays: Int, isGoalMet: Bool, due: [Due], nextReminder: Date?, secondsPerCard: Double? = nil,
        rounds: Int? = nil, roundsDone: Int? = nil, minutesToNextRound: Int? = nil, wordsInMemory: Int? = nil, wordsToday: Int? = nil,
        ladder: [Int]? = nil, isStreakAtRisk: Bool? = nil, week: [Bool?]? = nil, weekRings: [Double?]? = nil, wordsLearned: Int? = nil,
        wordsLearnedToday: Int? = nil, daySeconds: Double? = nil
    ) {
        self.daySeconds = daySeconds
        self.wordsLearned = wordsLearned
        self.wordsLearnedToday = wordsLearnedToday
        self.isStreakAtRisk = isStreakAtRisk
        self.week = week
        self.weekRings = weekRings
        self.ladder = ladder
        self.rounds = rounds
        self.roundsDone = roundsDone
        self.minutesToNextRound = minutesToNextRound
        self.wordsInMemory = wordsInMemory
        self.wordsToday = wordsToday
        self.date = date
        self.done = done
        self.goal = goal
        self.streakDays = streakDays
        self.isGoalMet = isGoalMet
        self.due = due
        self.nextReminder = nextReminder
        self.secondsPerCard = secondsPerCard
    }

    /// A snapshot of `progress`, with the due counts of each deck at `dates` (one array per
    /// deck, as long as `dates`) added up.
    init(now: Date, progress: DailyProgress, dates: [Date], dueByDeck: [[Int]], nextReminder: Date?) {
        let totals = dates.indices.map { index in dueByDeck.reduce(0) { $0 + ($1.indices.contains(index) ? $1[index] : 0) } }
        self.init(
            date: now, done: progress.ring.done, goal: progress.ring.goal, streakDays: progress.streak.days,
            isGoalMet: progress.ring.isGoalMet, due: zip(dates, totals).map { Due(date: $0, count: $1) }, nextReminder: nextReminder,
            secondsPerCard: progress.secondsPerCardLeft, rounds: progress.rounds, roundsDone: progress.roundsDone,
            minutesToNextRound: progress.minutesToNextRound, wordsInMemory: progress.memory.shownWords, wordsToday: progress.memory.shownGain,
            ladder: progress.ladder, isStreakAtRisk: progress.isStreakAtRisk, week: progress.week.count == 7 ? progress.week : nil,
            weekRings: progress.week.count == 7 ? progress.weekRings : nil, wordsLearned: progress.learned.words,
            wordsLearnedToday: progress.learned.shownGain, daySeconds: progress.time)
    }

    /// The moments the forecast looks at: `now`, then each full hour after it.
    static func forecastDates(from now: Date, hours: Int = forecastHours, calendar: Calendar = .current) -> [Date] {
        guard let first = calendar.nextDate(after: now, matching: DateComponents(minute: 0, second: 0), matchingPolicy: .nextTime) else {
            return [now]
        }
        return [now] + (0..<hours).map { first.addingTimeInterval(Double($0) * 3600) }
    }

    /// The cards of the plan across `decks` at each of `dates`, the new ones within `newCardAllowance`.
    static func dueCounts(of decks: [Deck], at dates: [Date], calendar: StudyCalendar, newCardAllowance: Int? = nil) -> [Int] {
        dates.map { date in decks.reduce(0) { $0 + StudySession.counts(for: $1, at: date, calendar: calendar, newCardAllowance: newCardAllowance).total } }
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
    var done: Int
    var goal: Int
    var streakDays: Int
    var isGoalMet: Bool
    /// The cards left of the plan.
    var due: Int
    /// The next reminder, `nil` once it is past.
    var nextReminder: Date?
    /// `WidgetSnapshot.secondsPerCard`.
    var secondsPerCard: Double?
    /// The rounds of the study day the snapshot was made on, as `WidgetSnapshot` has them; `nil` for a day
    /// after it, whose plan is only forecast, and for a snapshot of an older app.
    var rounds: Int?
    var roundsDone: Int?
    var minutesToNextRound: Int?
    /// The words in memory and the day's gain; `nil` after the day of the snapshot, as the number falls
    /// while the learner is away.
    var wordsInMemory: Int?
    var wordsToday: Int?
    /// The ladder of memory, which a day away barely moves, so it stays.
    var ladder: [Int]? = nil
    /// The day after a missed one, until the ring closes: the streak survives only if it does.
    var isStreakAtRisk = false
    /// The rings of the last seven study days, today last, as `DailyProgress.week` has them; `nil` for a snapshot of
    /// an older app.
    var week: [Bool?]? = nil
    /// The same days in laps of their goals (`WidgetSnapshot.weekRings`); `nil` for a snapshot of an older app.
    var weekRings: [Double?]? = nil
    /// The words learned and the day's gain; the gain is `nil` after the day of the snapshot, the words are not.
    var wordsLearned: Int? = nil
    var wordsLearnedToday: Int? = nil

    /// Where the learner stands in the rounds; `nil` when the snapshot has none.
    var roundStatus: RoundStatus? {
        guard let rounds, let roundsDone else { return nil }
        return RoundStatus(rounds: rounds, roundsDone: roundsDone, minutesToNext: minutesToNextRound)
    }

    /// Whether today keeps the streak: its first round is done, or the plan was empty; the goal being
    /// met when the snapshot has no rounds.
    var isStreakKept: Bool { roundStatus?.isStreakKept ?? isGoalMet }

    /// The minutes the cards left take (`DailyGoal.minutesLeft`): `nil` for none, or without a pace.
    var minutesLeft: Int? {
        secondsPerCard.flatMap { DailyGoal.minutesLeft(cards: toRing > 0 ? toRing : due, secondsPerCard: $0) }
    }

    /// The cards left to close the ring: what "N cards left" counts while it is open. The plan may hold more, after a
    /// break, and those come after the ring.
    var toRing: Int { goal > 0 && done < goal ? min(due, goal - done) : 0 }

    /// The ring and the streak as `DailyRingView` takes them, with the cards left that its middle counts; at risk, the
    /// streak owes the cards that close the ring.
    var progress: DailyProgress {
        DailyProgress(
            ring: DailyRing(done: done, goal: goal), streak: Streak(days: streakDays, repairCards: isStreakAtRisk ? max(1, toRing) : nil),
            cardsLeft: due, streakKeptToday: isStreakKept)
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
    /// On the study day of the snapshot they are the snapshot's, with the cards left that were
    /// forecast for the hour. Once a study day has begun, today's cards done are 0 and its goal
    /// is the cards of the plan that fit the day's time, as forecast for the moment (`forecastGoal(plan:)`), with the minutes of the
    /// streak step; a day whose plan is empty is met, and counts
    /// for the streak. The streak holds through one missed day, which the plan of the next
    /// makes up for, and ends with a second one, as in `Streak.evaluate`; a day on which the
    /// goal was not met counts as missed.
    func state(at moment: Date, calendar: StudyCalendar = StudyCalendar()) -> WidgetState {
        let count = dueCount(at: moment)
        let reminder = nextReminder.flatMap { $0 > moment ? $0 : nil }
        let days = calendar.dayNumber(for: moment) - calendar.dayNumber(for: date)
        let same = WidgetState(
            date: moment, done: done, goal: goal, streakDays: streakDays, isGoalMet: isGoalMet, due: count, nextReminder: reminder,
            secondsPerCard: secondsPerCard, rounds: rounds, roundsDone: roundsDone, minutesToNextRound: minutesToNextRound,
            wordsInMemory: wordsInMemory, wordsToday: wordsToday, ladder: ladder, isStreakAtRisk: isStreakAtRisk ?? false, week: week, weekRings: weekRings,
            wordsLearned: wordsLearned, wordsLearnedToday: wordsLearnedToday)
        guard days > 0 else { return same }
        // A day that kept the streak (its first round done) is no missed day, whatever became of its ring.
        let missed = days - (same.isStreakKept ? 1 : 0)
        let isEmptyPlanMet = count == 0 && missed == 0
        let kept = missed >= 2 ? 0 : streakDays + (isEmptyPlanMet ? 1 : 0)
        let newGoal = forecastGoal(plan: count)
        let step = streakStep(ofGoal: newGoal)
        return WidgetState(
            date: moment, done: 0, goal: newGoal, streakDays: kept, isGoalMet: count == 0, due: count, nextReminder: reminder,
            secondsPerCard: secondsPerCard, rounds: step?.rounds, roundsDone: step.map { _ in 0 }, minutesToNextRound: step?.minutes,
            ladder: ladder, isStreakAtRisk: missed == 1 && count > 0 && kept > 0,
            week: week.map { Self.moved($0, ending: isGoalMet, between: false, today: count == 0, daysLater: days) },
            weekRings: weekRings.map { Self.moved($0, ending: $0.last.flatMap { $0 } ?? (isGoalMet ? 1 : 0), between: 0, today: count == 0 ? 1 : 0, daysLater: days) },
            wordsLearned: wordsLearned)
    }

    /// The goal of a study day that began after the snapshot, whose plan holds `plan` cards: the cards that fit the day's
    /// time at the one price the snapshot has, at least one, as the app cuts it (`DayRounds`); the plan itself when the
    /// snapshot has no time or no price.
    private func forecastGoal(plan: Int) -> Int {
        guard plan > 0, let daySeconds, daySeconds > 0, let secondsPerCard, secondsPerCard > 0 else { return plan }
        return min(plan, max(1, Int((daySeconds / secondsPerCard + 1e-9).rounded(.down))))
    }

    /// The rounds of such a day and the minutes of the first, the streak step: the cards of the goal that fill
    /// `DailyGoal.streakSeconds` at the snapshot's one price, a second round for the rest. `nil` without a price.
    private func streakStep(ofGoal goal: Int) -> (rounds: Int, minutes: Int?)? {
        guard let secondsPerCard, secondsPerCard > 0 else { return nil }
        guard goal > 0 else { return (0, nil) }
        let cards = DailyGoal.streakStepCards(in: goal, secondsPerCard: secondsPerCard)
        return (cards < goal ? 2 : 1, DailyGoal.minutesLeft(cards: cards, secondsPerCard: secondsPerCard))
    }

    /// The week of a snapshot `daysLater` study days on, whether as closed or as laps: the snapshot's day as it ended (`last`),
    /// the days between `missed`, and `today` for the one now.
    private static func moved<Ring>(_ week: [Ring?], ending last: Ring, between missed: Ring, today: Ring, daysLater: Int) -> [Ring?] {
        var moved = Array(week.dropLast()) + [last]
        moved += Array(repeating: missed, count: daysLater - 1) + [today]
        return Array(moved.suffix(week.count))
    }

    /// The cards left of the plan at `moment`: the last forecast at or before it, the first one if none is.
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
