/// One study day as the review log tells it.
public struct DayRecord: Hashable, Sendable {
    /// The study day number (`StudyCalendar.dayNumber`).
    public var day: Int
    /// The cards done that day.
    public var done: Int
    /// The day's goal.
    public var goal: Int
    /// The first round was done, or the plan was empty: the rule of the streak, as the ring judges it (a day
    /// before `DailyGoal.planRuleStart` that the streak counts for one review is not `kept` for that).
    public var kept: Bool
    /// `done >= goal`.
    public var closed: Bool
    /// The streak at the end of that day, by the rule of `Streak.evaluate`; today's is `Streak.days`.
    public var streak: Int
    /// This day closed its ring after a single missed day, and so kept the streak alive.
    public var savedStreak: Bool

    /// How the day's ring is drawn, in laps of its goal: a closed day on which cards were done is full at least, and
    /// goes on over itself as far as it was worked past the goal (at most `maxLaps`, 3); any other day has the share of
    /// its goal that was done, so a partial day is partial, and a missed day, or an idle one that had nothing due, is an
    /// empty track.
    public var ringShare: Double {
        if closed {
            guard done > 0 else { return 0 }
            return goal > 0 ? max(1, min(Self.maxLaps, Double(done) / Double(goal))) : 1
        }
        return min(1, Double(done) / Double(max(1, goal)))
    }

    /// The most laps of its goal a ring is drawn with.
    public static let maxLaps = 3.0

    public init(day: Int, done: Int, goal: Int, kept: Bool, closed: Bool, streak: Int, savedStreak: Bool = false) {
        self.day = day
        self.done = done
        self.goal = goal
        self.kept = kept
        self.closed = closed
        self.streak = streak
        self.savedStreak = savedStreak
    }
}

/// A line of achievements and its tier.
public enum AchievementKind: Hashable, Sendable {
    /// One per milestone in `Achievements.streakMilestones`.
    case streak(days: Int)
    case firstRing
    /// Seven closed rings in a row; earned again at every further run of seven.
    case perfectWeek
    /// A day whose ring went twice round its goal (`DayRecord.ringShare` of 2 or more); earned once.
    case doubleRing
    /// A day whose ring went three times round its goal, the most a ring is drawn (`DayRecord.maxLaps`); earned once.
    case tripleRing
    /// A day with `DayRecord.savedStreak`; earned every time.
    case comeback
}

public struct Achievement: Hashable, Sendable {
    public var kind: AchievementKind
    /// The study day it was earned.
    public var day: Int

    public init(kind: AchievementKind, day: Int) {
        self.kind = kind
        self.day = day
    }
}

/// The calendar month of study, for the screen shown on the first open of the next one.
public struct MonthRecap: Hashable, Sendable {
    public var year: Int
    public var month: Int
    /// Days with `done > 0`.
    public var daysStudied: Int
    public var ringsClosed: Int
    public var cardsDone: Int
    /// The highest end-of-day streak within the month.
    public var bestStreak: Int
    /// What was earned within the month, oldest first.
    public var achievements: [Achievement]
}

/// Milestones and achievements, worked out from the days of `DailyProgress.records` alone.
public enum Achievements {
    public static let streakMilestones = [3, 7, 14, 30, 61, 91, 183, 365, 548, 730]

    /// Everything earned over `records` (oldest first, one per study day from the first study day to today,
    /// days without study included), oldest first. A tier of a line is earned once, on the first day it is
    /// reached (a day that reaches several tiers earns all of them); perfectWeek and comeback are earned each
    /// time. Within a day: streak, first ring, perfect week, double ring, triple ring, comeback.
    public static func earned(over records: [DayRecord]) -> [Achievement] {
        var earned: [Achievement] = []
        var tiers = Set<AchievementKind>()
        var run = 0
        var previous: Int?
        for record in records {
            func earn(_ kind: AchievementKind) { earned.append(Achievement(kind: kind, day: record.day)) }
            func earnOnce(_ kind: AchievementKind) { if tiers.insert(kind).inserted { earn(kind) } }
            for days in streakMilestones where record.streak >= days { earnOnce(.streak(days: days)) }
            // A ring closed with work in it: a day whose plan was empty closes its ring, but earns nothing.
            let worked = record.closed && record.done > 0
            if worked { earnOnce(.firstRing) }
            if let last = previous, record.day != last + 1 { run = 0 }
            previous = record.day
            run = worked ? run + 1 : 0
            if run > 0, run % 7 == 0 { earn(.perfectWeek) }
            if record.ringShare >= 2 { earnOnce(.doubleRing) }
            if record.ringShare >= DayRecord.maxLaps { earnOnce(.tripleRing) }
            if record.savedStreak { earn(.comeback) }
        }
        return earned
    }

    /// The recap of the calendar month that contains study day `day`; `nil` if no day of it is in `records`.
    public static func recap(ofMonthContaining day: Int, records: [DayRecord], calendar: StudyCalendar) -> MonthRecap? {
        let target = CivilDate(dayNumber: day)
        func inMonth(_ day: Int) -> Bool {
            let date = CivilDate(dayNumber: day)
            return date.year == target.year && date.month == target.month
        }
        let days = records.filter { inMonth($0.day) }
        guard !days.isEmpty else { return nil }
        return MonthRecap(
            year: target.year, month: target.month, daysStudied: days.filter { $0.done > 0 }.count, ringsClosed: days.filter(\.closed).count,
            cardsDone: days.reduce(0) { $0 + $1.done }, bestStreak: days.map(\.streak).max() ?? 0,
            achievements: earned(over: records).filter { inMonth($0.day) })
    }
}
