import SwiftUI
import Testing

@testable import VocTrain
@testable import VocabCore

/// The names, faces and symbols of the achievements, the next tier of each line, the month's screen, and the
/// Progress screen as a picture (in the directory of `HomeSnapshotTests`).
@MainActor
struct AchievementPresentationTests {
    static let allKinds: [AchievementKind] =
        Achievements.streakMilestones.map { .streak(days: $0) } + [.firstRing, .perfectWeek] + Achievements.lapTiers.map { .laps($0) }
        + Achievements.bigDayTiers.map { .bigDay(cards: $0) } + [.comeback]

    /// A day of study: its ring closed with `done` of `goal`, or not.
    static func day(_ day: Int, done: Int, goal: Int = 10, streak: Int = 0, saved: Bool = false) -> DayRecord {
        DayRecord(day: day, done: done, goal: goal, kept: done > 0, closed: done >= goal, streak: streak, savedStreak: saved)
    }

    /// `count` days, the oldest `first`, each with a ring closed.
    static func closedDays(from first: Int, count: Int) -> [DayRecord] {
        (0..<count).map { day(first + $0, done: 10, streak: $0 + 1) }
    }

    // MARK: Names

    @Test func everyAchievementHasANameAFaceAndASymbol() {
        for kind in Self.allKinds {
            #expect(!kind.title.isEmpty)
            #expect(!kind.face.isEmpty)
            #expect(!kind.symbol.isEmpty)
        }
        #expect(Set(Self.allKinds.map(\.title)).count == Self.allKinds.count)
        #expect(Set(Self.allKinds.map(\.face)).count == Self.allKinds.count)
    }

    /// A streak is named in words: past the first milestone no title is the fallback with a count of days.
    @Test func streakMilestonesAreNamedInWords() {
        let titles = Achievements.streakMilestones.map { AchievementKind.streak(days: $0).title }
        #expect(
            titles == [
                "3 days in a row", "A week in a row", "2 weeks in a row", "A month in a row", "2 months in a row", "3 months in a row",
                "Half a year in a row", "A year in a row", "A year and a half in a row", "2 years in a row",
            ])
    }

    @Test func lapsAndBigDaysNameTheirTier() {
        #expect(AchievementKind.laps(3).title == "Ring ×3")
        #expect(AchievementKind.laps(2).detail == "Twice the day's goal")
        #expect(AchievementKind.laps(5).detail == "5 times the day's goal")
        #expect(AchievementKind.bigDay(cards: 50).title == "50 cards in a day")
        #expect(AchievementKind.perfectWeek.detail == "Seven rings in a row")
        #expect(AchievementKind.comeback.detail == "Saved your streak after a missed day")
    }

    /// The comeback's face is the phoenix, a joined sequence that a copy of the file could break.
    @Test func theFacesAreWhatTheTableSays() {
        #expect(AchievementKind.comeback.face.unicodeScalars.map(\.value) == [0x1F426, 0x200D, 0x1F525])
        #expect(AchievementKind.streak(days: 7).face.unicodeScalars.map(\.value) == [0x2B50, 0xFE0F])
        #expect(AchievementKind.laps(10).face.unicodeScalars.map(\.value) == [0x1FA90])
    }

    @Test func aMedalEarnedAgainIsOneWithACount() {
        let earned = [
            Achievement(kind: .perfectWeek, day: 10), Achievement(kind: .comeback, day: 12), Achievement(kind: .perfectWeek, day: 17),
            Achievement(kind: .perfectWeek, day: 24),
        ]
        #expect(earned.medals == [EarnedMedal(kind: .perfectWeek, day: 24, count: 3), EarnedMedal(kind: .comeback, day: 12, count: 1)])
    }

    // MARK: The next tier

    @Test func theStreakOffersTheFirstMilestoneNotEarned() throws {
        let none = try #require(NextTier.of(.streak, earned: [], records: [], streak: 2))
        #expect(none == NextTier(kind: .streak(days: 3), value: 2, goal: 3))

        let earned = [Achievement(kind: .streak(days: 3), day: 1), Achievement(kind: .streak(days: 7), day: 5)]
        let next = try #require(NextTier.of(.streak, earned: earned, records: [], streak: 12))
        #expect(next == NextTier(kind: .streak(days: 14), value: 12, goal: 14))
        #expect(next.hint == "12 of 14 days")

        let all = Achievements.streakMilestones.map { Achievement(kind: .streak(days: $0), day: 1) }
        #expect(NextTier.of(.streak, earned: all, records: [], streak: 800) == nil)
    }

    @Test func theFirstRingIsOfferedUntilItIsEarned() throws {
        let next = try #require(NextTier.of(.firstRing, earned: [], records: [], streak: 0))
        #expect(next == NextTier(kind: .firstRing))
        #expect(next.hint == nil)
        #expect(NextTier.of(.firstRing, earned: [Achievement(kind: .firstRing, day: 3)], records: [], streak: 1) == nil)
    }

    @Test func thePerfectWeekCountsTheRunOfRings() throws {
        let ten = Self.closedDays(from: 100, count: 10)
        let next = try #require(NextTier.of(.perfectWeek, earned: [], records: ten, streak: 10))
        #expect(next == NextTier(kind: .perfectWeek, value: 3, goal: 7))
        #expect(next.hint == "3 of 7 rings")

        // Today's ring, still open, doesn't end the run.
        let open = Self.closedDays(from: 100, count: 3) + [Self.day(103, done: 4)]
        #expect(NextTier.of(.perfectWeek, earned: [], records: open, streak: 4)?.value == 3)

        // A missed day does.
        let broken = Self.closedDays(from: 100, count: 3) + [Self.day(103, done: 0)] + Self.closedDays(from: 104, count: 2)
        #expect(NextTier.of(.perfectWeek, earned: [], records: broken, streak: 2)?.value == 2)

        // A day with an empty plan closes its ring but is no work.
        let empty = Self.closedDays(from: 100, count: 3) + [DayRecord(day: 103, done: 0, goal: 0, kept: true, closed: true, streak: 4)]
        #expect(NextTier.of(.perfectWeek, earned: [], records: empty, streak: 4)?.value == 3)
    }

    @Test func lapsCountTheBestDay() throws {
        let records = [Self.day(1, done: 25), Self.day(2, done: 12)]
        let next = try #require(NextTier.of(.laps, earned: [Achievement(kind: .laps(2), day: 1)], records: records, streak: 2))
        #expect(next == NextTier(kind: .laps(3), value: 2, goal: 3))
        #expect(next.hint == "×2 of ×3")

        let all = Achievements.lapTiers.map { Achievement(kind: .laps($0), day: 1) }
        #expect(NextTier.of(.laps, earned: all, records: records, streak: 2) == nil)
    }

    @Test func theBigDayCountsTheCardsOfTheBestDay() throws {
        let records = [Self.day(1, done: 40), Self.day(2, done: 76, goal: 30)]
        let next = try #require(NextTier.of(.bigDay, earned: [Achievement(kind: .bigDay(cards: 50), day: 2)], records: records, streak: 2))
        #expect(next == NextTier(kind: .bigDay(cards: 100), value: 76, goal: 100))
        #expect(next.hint == "76 of 100 cards")

        let all = Achievements.bigDayTiers.map { Achievement(kind: .bigDay(cards: $0), day: 2) }
        #expect(NextTier.of(.bigDay, earned: all, records: records, streak: 2) == nil)
    }

    @Test func theComebackIsAlwaysAheadAndNeverCounted() throws {
        let earned = [Achievement(kind: .comeback, day: 4)]
        for earned in [[], earned] {
            let next = try #require(NextTier.of(.comeback, earned: earned, records: [], streak: 5))
            #expect(next == NextTier(kind: .comeback))
            #expect(next.hint == nil)
        }
    }

    // MARK: The month's screen

    /// October 2026 with study on 20 days, today the second of November.
    static func octoberRecords() -> [DayRecord] {
        let october = CivilDate(year: 2026, month: 10, day: 1).dayNumber
        let november = CivilDate(year: 2026, month: 11, day: 2).dayNumber
        return (october...november).map { day in day < october + 20 ? Self.day(day, done: 10, streak: day - october + 1) : Self.day(day, done: 0) }
    }

    @Test func theMonthAfterAMonthWithStudyShowsOnce() throws {
        let records = Self.octoberRecords()
        let recap = try #require(MonthRecapPlan.pending(records: records, calendar: StudyCalendar(), shown: nil))
        #expect(recap.year == 2026 && recap.month == 10)
        #expect(recap.daysStudied == 20 && recap.ringsClosed == 20 && recap.cardsDone == 200 && recap.bestStreak == 20)
        #expect(MonthRecapPlan.key(year: recap.year, month: recap.month) == "2026-10")
        #expect(MonthRecapPlan.pending(records: records, calendar: StudyCalendar(), shown: "2026-10") == nil)
        #expect(MonthRecapPlan.pending(records: records, calendar: StudyCalendar(), shown: "2026-09") != nil)
    }

    @Test func aMonthWithoutStudyHasNoScreen() {
        let september = CivilDate(year: 2026, month: 9, day: 20).dayNumber
        let november = CivilDate(year: 2026, month: 11, day: 2).dayNumber
        let records = (september...november).map { Self.day($0, done: $0 < september + 5 ? 10 : 0) }
        #expect(MonthRecapPlan.pending(records: records, calendar: StudyCalendar(), shown: nil) == nil)
        #expect(MonthRecapPlan.pending(records: [], calendar: StudyCalendar(), shown: nil) == nil)
    }

    @Test func januaryLooksBackToDecember() throws {
        let december = CivilDate(year: 2026, month: 12, day: 28).dayNumber
        let january = CivilDate(year: 2027, month: 1, day: 3).dayNumber
        let records = (december...january).map { Self.day($0, done: 10, streak: $0 - december + 1) }
        let recap = try #require(MonthRecapPlan.pending(records: records, calendar: StudyCalendar(), shown: nil))
        #expect(recap.year == 2026 && recap.month == 12 && recap.daysStudied == 4)
    }

    // MARK: Pictures

    /// A hundred days: closed rings, a few partial days and misses, one saved streak, and today's ring half done.
    static func sampleProgress() -> DailyProgress {
        let today = StudyCalendar().dayNumber(for: Date())
        var streak = 0
        var records: [DayRecord] = []
        for index in 0..<110 {
            let day = today - 109 + index
            let isToday = index == 109
            let goal = 24
            let missed = !isToday && index % 31 == 5
            let partial = !isToday && !missed && index % 11 == 3
            let done = isToday ? 14 : missed ? 0 : partial ? 9 : index % 17 == 0 ? 75 : index % 13 == 0 ? 52 : 24 + index % 3
            let saved = index == 6
            streak = missed ? 0 : streak + 1
            records.append(
                DayRecord(
                    day: day, done: done, goal: goal, kept: !missed && done > 0, closed: done >= goal, streak: streak, savedStreak: saved))
        }
        return DailyProgress(
            ring: DailyRing(done: 14, goal: 24), streak: Streak(days: streak, repairCards: nil), streakKeptToday: true, ladder: [180, 36, 64, 85, 42, 9],
            records: records, achievements: Achievements.earned(over: records))
    }

    /// The Progress screen in light and dark, a window tall enough for all of it.
    @Test func progressScreen() async throws {
        let progress = Self.sampleProgress()
        try await HomeSnapshotTests().shoot("progress", NavigationStack { ProgressScreen(progress: progress) }, height: 1900)
    }

    /// The month's screen and the Ring closed rest with its medals.
    @Test func celebrations() async throws {
        let shots = HomeSnapshotTests()
        let recap = try #require(MonthRecapPlan.pending(records: Self.octoberRecords(), calendar: StudyCalendar(), shown: nil))
        try await shots.shoot("month", MonthRecapSheet(recap: recap, seeAll: {}, done: {}))

        var recap2 = StudyStream.Recap()
        recap2.cards = 30
        recap2.reviews = 48
        recap2.recalled = 42
        var progress = Self.sampleProgress()
        let today = try #require(progress.records.last?.day)
        progress.records[progress.records.count - 1].closed = true
        progress.records[progress.records.count - 1].savedStreak = true
        progress.ring = DailyRing(done: 24, goal: 24)
        progress.achievements += [Achievement(kind: .laps(2), day: today), Achievement(kind: .bigDay(cards: 50), day: today), Achievement(kind: .comeback, day: today)]
        let rest = StreamRest(isPracticeOnly: false, recap: recap2, nextDue: nil, now: Date(), canKeepGoing: false)
        try await shots.shoot("rest-medals", StreamRestView(rest: rest, progress: progress, onKeepGoing: {}, onAddNewCards: {}, onDone: {}))
    }
}
