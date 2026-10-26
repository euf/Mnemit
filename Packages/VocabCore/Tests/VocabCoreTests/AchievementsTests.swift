import Foundation
import Testing

@testable import VocabCore

struct AchievementsTests {
    /// A study day with a ring closed, unless `closed` says otherwise.
    func day(_ number: Int, done: Int = 20, goal: Int = 20, closed: Bool? = nil, streak: Int = 1, saved: Bool = false) -> DayRecord {
        DayRecord(day: number, done: done, goal: goal, kept: done > 0, closed: closed ?? (done >= goal), streak: streak, savedStreak: saved)
    }

    /// `count` days from `first`, each with a closed ring and the streak growing from 1.
    func closedDays(_ count: Int, from first: Int = 100) -> [DayRecord] {
        (0..<count).map { day(first + $0, streak: $0 + 1) }
    }

    func days(of kind: AchievementKind, in earned: [Achievement]) -> [Int] {
        earned.filter { $0.kind == kind }.map(\.day)
    }

    @Test func daysWithAnEmptyPlanEarnNoRing() {
        let records = (0..<7).map { DayRecord(day: 100 + $0, done: 0, goal: 0, kept: true, closed: true, streak: $0 + 1) }
        let kinds = Achievements.earned(over: records).map(\.kind)
        #expect(!kinds.contains(.firstRing))
        #expect(!kinds.contains(.perfectWeek))
    }

    @Test func theFirstRingIsEarnedOnceOnTheFirstDayItCloses() {
        let records = [day(100, done: 5, goal: 20), day(101, done: 20), day(102, done: 20)]
        #expect(days(of: .firstRing, in: Achievements.earned(over: records)) == [101])
        #expect(Achievements.earned(over: []).isEmpty)
    }

    @Test func eachStreakMilestoneIsEarnedOnceOnTheDayTheStreakReachesIt() {
        let earned = Achievements.earned(over: closedDays(15))
        #expect(days(of: .streak(days: 3), in: earned) == [102])
        #expect(days(of: .streak(days: 7), in: earned) == [106])
        #expect(days(of: .streak(days: 14), in: earned) == [113])
        #expect(days(of: .streak(days: 30), in: earned) == [])
        // A streak that restarts and reaches the milestones again earns nothing the second time.
        let again = closedDays(15) + (0..<8).map { day(115 + $0, streak: $0 + 1) }
        #expect(Achievements.earned(over: again).filter { $0.kind == .streak(days: 3) }.count == 1)
    }

    @Test func aStreakThatJumpsOverAMilestoneEarnsItOnTheDayItPassesIt() {
        let records = [day(100, streak: 12), day(101, done: 0, closed: false, streak: 12), day(102, streak: 14, saved: true)]
        #expect(days(of: .streak(days: 14), in: Achievements.earned(over: records)) == [102])
        let over = [day(100, streak: 13), day(101, done: 0, closed: false, streak: 13), day(102, streak: 15, saved: true)]
        #expect(days(of: .streak(days: 14), in: Achievements.earned(over: over)) == [102])
    }

    @Test func aPerfectWeekIsSevenClosedRingsInARowAndIsEarnedAgainAtEveryFurtherSeven() {
        #expect(days(of: .perfectWeek, in: Achievements.earned(over: closedDays(6))) == [])
        #expect(days(of: .perfectWeek, in: Achievements.earned(over: closedDays(7))) == [106])
        #expect(days(of: .perfectWeek, in: Achievements.earned(over: closedDays(14))) == [106, 113])
        #expect(days(of: .perfectWeek, in: Achievements.earned(over: closedDays(13))) == [106])
    }

    @Test func aDayWithAnOpenRingOrWithoutStudyRestartsTheWeek() {
        var records = closedDays(7)
        records[3] = day(103, done: 3, goal: 20)
        #expect(days(of: .perfectWeek, in: Achievements.earned(over: records)) == [])
        records = closedDays(4) + [day(104, done: 0, goal: 20)] + (0..<7).map { day(105 + $0) }
        #expect(days(of: .perfectWeek, in: Achievements.earned(over: records)) == [111])
    }

    @Test func aDoubleAndATripleRingAreEarnedOnceOnTheFirstDayTheRingReachesThem() {
        let records = [
            day(100, done: 20, goal: 20), day(101, done: 39, goal: 20), day(102, done: 40, goal: 20), day(103, done: 60, goal: 20),
            day(104, done: 200, goal: 20), day(105, done: 60, goal: 20),
        ]
        let earned = Achievements.earned(over: records)
        // 39 of 20 is not yet two laps, 40 is; 60 is three.
        #expect(days(of: .doubleRing, in: earned) == [102])
        #expect(days(of: .tripleRing, in: earned) == [103])
    }

    @Test func aDayThatReachesThreeLapsEarnsBothMedalsInOrder() {
        let earned = Achievements.earned(over: [day(100, done: 90, goal: 30)])
        #expect(earned.map(\.kind) == [.firstRing, .doubleRing, .tripleRing])
    }

    @Test func theLapsAreTheOnesTheRingIsDrawnWithAndAnOpenRingHasNone() {
        // The same rule as `DayRecord.ringShare`: an open ring never reaches a lap, and a goal of nothing is one lap.
        let open = Achievements.earned(over: [day(100, done: 59, goal: 20, closed: false)])
        #expect(!open.map(\.kind).contains(.doubleRing))
        let noGoal = Achievements.earned(over: [DayRecord(day: 100, done: 50, goal: 0, kept: true, closed: true, streak: 1)])
        #expect(!noGoal.map(\.kind).contains(.doubleRing))
        // Cards of a day far past its goal are three laps and no more.
        #expect(Achievements.earned(over: [day(100, done: 1000, goal: 20)]).map(\.kind) == [.firstRing, .doubleRing, .tripleRing])
    }

    @Test func theCardCountTiersAreGone() {
        // A learner with long days earns the laps of their own goal, whatever the number of cards.
        let kinds = Achievements.earned(over: [day(100, done: 500, goal: 500)]).map(\.kind)
        #expect(kinds == [.firstRing])
    }

    @Test func aWordsLearnedMedalIsEarnedOnceOnTheFirstDayTheCountReachesIt() {
        func counted(_ number: Int, words: Int) -> DayRecord {
            DayRecord(day: number, done: 5, goal: 20, kept: true, closed: false, streak: 1, wordsLearned: words)
        }
        let earned = Achievements.earned(over: [counted(100, words: 9), counted(101, words: 10), counted(102, words: 60), counted(103, words: 1000), counted(104, words: 2100)])
        func words(_ count: Int) -> [Int] { days(of: .wordsLearned(count: count), in: earned) }
        #expect(words(10) == [101])
        #expect(words(50) == [102])
        #expect(words(100) == [103] && words(250) == [103] && words(500) == [103] && words(1000) == [103])
        #expect(words(2000) == [104])
        #expect(words(3000) == [])
    }

    @Test func aComebackIsEarnedEveryTimeTheStreakIsSaved() {
        let records = [day(100), day(101, done: 0, closed: false), day(102, saved: true), day(103), day(104, done: 0, closed: false), day(105, saved: true)]
        #expect(days(of: .comeback, in: Achievements.earned(over: records)) == [102, 105])
    }

    @Test func everythingIsListedOldestFirst() {
        let earned = Achievements.earned(over: closedDays(14) + [day(114, done: 60, goal: 20, streak: 15)])
        #expect(earned.map(\.day) == earned.map(\.day).sorted())
        #expect(earned.first == Achievement(kind: .firstRing, day: 100))
        #expect(earned.last == Achievement(kind: .tripleRing, day: 114))
    }

    @Test func aMonthRecapAddsUpTheDaysOfThatCalendarMonthOnly() throws {
        let calendar = StudyCalendar.testing
        let october = CivilDate(year: 2026, month: 10, day: 30).dayNumber
        // 30 and 31 October, 1 and 2 November.
        let records = [
            day(october, done: 20, streak: 5), day(october + 1, done: 0, closed: false, streak: 5), day(october + 2, done: 60, goal: 20, streak: 7, saved: true),
            day(october + 3, done: 10, goal: 20, closed: false, streak: 8),
        ]
        let november = try #require(Achievements.recap(ofMonthContaining: october + 3, records: records, calendar: calendar))
        #expect(november.year == 2026 && november.month == 11)
        #expect(november.daysStudied == 2)
        #expect(november.ringsClosed == 1)
        #expect(november.cardsDone == 70)
        #expect(november.bestStreak == 8)
        #expect(november.achievements.map(\.day).allSatisfy { $0 >= october + 2 })
        #expect(november.achievements.contains(Achievement(kind: .comeback, day: october + 2)))
        let previous = try #require(Achievements.recap(ofMonthContaining: october, records: records, calendar: calendar))
        #expect(previous.month == 10)
        #expect(previous.daysStudied == 1)
        #expect(previous.ringsClosed == 1)
        #expect(previous.cardsDone == 20)
        #expect(previous.bestStreak == 5)
        #expect(previous.achievements.contains(Achievement(kind: .firstRing, day: october)))
        #expect(!previous.achievements.contains(Achievement(kind: .comeback, day: october + 2)))
    }

    @Test func aMonthWithoutADayInTheRecordsHasNoRecap() {
        let records = closedDays(3)
        let far = records[0].day + 90
        #expect(Achievements.recap(ofMonthContaining: far, records: records, calendar: .testing) == nil)
        #expect(Achievements.recap(ofMonthContaining: 100, records: [], calendar: .testing) == nil)
    }
}

struct StreakWalkTests {
    @Test func theWalkTellsWhichDaySavedTheStreakAndWhatEachDayLeft() {
        let reviews = Dictionary(uniqueKeysWithValues: (100...106).map { ($0, 3) })
        let kept = Set([100, 101, 102, 103, 105, 106])
        let walk = Streak.walk(reviews: reviews, today: 106, planRuleStart: .min, isKept: { kept.contains($0) }, isClosed: { kept.contains($0) }, repairCards: 0)
        #expect(
            walk.steps.map { ($0.key, $0.value.days, $0.value.saved) }.sorted { $0.0 < $1.0 }.map { [$0.0, $0.1, $0.2 ? 1 : 0] } == [
                [100, 1, 0], [101, 2, 0], [102, 3, 0], [103, 4, 0], [104, 4, 0], [105, 6, 1], [106, 7, 0],
            ])
        #expect(walk.streak == Streak(days: 7, repairCards: nil))
    }

    @Test func twoMissedDaysEndTheStreakAndTodayAtRiskKeepsItsRepairCards() {
        let reviews = Dictionary(uniqueKeysWithValues: (100...105).map { ($0, 3) })
        let kept = Set([100, 101, 102])
        let ended = Streak.walk(reviews: reviews, today: 105, planRuleStart: .min, isKept: { kept.contains($0) }, isClosed: { kept.contains($0) }, repairCards: 4)
        #expect(ended.steps[104]?.days == 0)
        #expect(ended.streak == Streak(days: 0, repairCards: nil))
        let risk = Streak.walk(reviews: reviews, today: 104, planRuleStart: .min, isKept: { kept.contains($0) }, isClosed: { kept.contains($0) }, repairCards: 4)
        #expect(risk.streak == Streak(days: 3, repairCards: 4))
        #expect(risk.steps[104] == Streak.Step(days: 3, saved: false, atRisk: true))
    }
}

extension DailyProgressTests {
    @Test func theRecordsRunFromTheFirstStudyDayToTodayAndEndWithTodaysLiveFigures() throws {
        var deck = try Deck(learningOptions: options(), cards: (0..<5).map { due("c\($0)", onDay: today) })
        var progress = evaluate([deck])
        #expect(progress.records.map(\.day) == Array((today - interval)...today))
        #expect(progress.records.last == DayRecord(day: today, done: 0, goal: 5, kept: false, closed: false, streak: interval, savedStreak: false, wordsLearned: progress.records.last?.wordsLearned ?? -1))
        #expect(progress.records.last?.streak == progress.streak.days)
        reviewPlan(of: &deck, at: now)
        progress = evaluate([deck])
        #expect(progress.records.last == DayRecord(day: today, done: 5, goal: 5, kept: true, closed: true, streak: interval + 1, savedStreak: false, wordsLearned: progress.records.last?.wordsLearned ?? -1))
        #expect(progress.records.last?.streak == progress.streak.days)
        #expect(progress.records.last?.done == progress.ring.done)
        // The streak of every day is the streak of that day: one more than the day before, all days kept.
        #expect(progress.records.map(\.streak) == Array(1...(interval + 1)))
        #expect(progress.achievements == Achievements.earned(over: progress.records))
        #expect(progress.achievements.contains { $0.kind == .firstRing && $0.day == today - interval })
    }

    @Test func aDayWithoutReviewsHasOneRecordForToday() {
        let progress = evaluate([Deck()])
        #expect(progress.records.map(\.day) == [today])
        #expect(progress.records.last?.streak == 0)
        #expect(progress.achievements == Achievements.earned(over: progress.records))
    }

    @Test func theRecordsOfACachedEvaluationAreThoseOfTheFullRecount() throws {
        var deck = try Deck(learningOptions: options(), cards: (0..<5).map { due("c\($0)", onDay: today) })
        let history = DeckHistoryCache()
        let cache = DailyProgressCache()
        func cached() -> DailyProgress {
            DailyProgress.evaluate([DeckActivity(deck: deck, calendar: calendar, historyCache: history)], at: now, calendar: calendar, planRuleStart: .min, cache: cache)
        }
        let first = cached()
        reviewPlan(of: &deck, at: now)
        let second = cached()
        #expect(second.records == evaluate([deck]).records)
        #expect(second.records.dropLast() == first.records.dropLast())
        #expect(second.records.last?.done == 5)
    }

    @Test func aDayThatClosesItsRingAfterAMissedDaySavedTheStreakAndEarnsAComeback() throws {
        // Cards due yesterday with nothing done: yesterday was missed, and today's plan repairs it.
        var deck = try Deck(learningOptions: options(), cards: (0..<140).map { due("b\($0)", onDay: today - 1) })
        var progress = evaluate([deck])
        #expect(progress.streak.repairCards != nil)
        #expect(progress.records.last?.savedStreak == false)
        reviewPlan(of: &deck, at: now)
        progress = evaluate([deck])
        let records = progress.records
        #expect(records[records.count - 2].kept == false)
        #expect(records.last?.savedStreak == true)
        #expect(records.last?.closed == true)
        #expect(records.last?.streak == progress.streak.days)
        #expect(progress.achievements.contains(Achievement(kind: .comeback, day: today)))
    }
}
