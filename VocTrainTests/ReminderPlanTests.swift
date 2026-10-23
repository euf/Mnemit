import Foundation
import Testing
import VocabCore

@testable import VocTrain

/// When the daily reminder fires and what it says.
struct ReminderPlanTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Nicosia")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test func firesTodayWhileTheTimeIsAhead() {
        let fires = ReminderPlan.fireDates(after: date(21, 8), minutes: 9 * 60, count: 3, calendar: calendar)
        #expect(fires == [date(21, 9), date(22, 9), date(23, 9)])
    }

    @Test func startsTomorrowOnceTheTimeHasPassed() {
        let fires = ReminderPlan.fireDates(after: date(21, 9, 30), minutes: 9 * 60 + 15, count: 2, calendar: calendar)
        #expect(fires == [date(22, 9, 15), date(23, 9, 15)])
    }

    @Test func keepsTheClockTimeWhenDaylightSavingEnds() {
        // Cyprus goes back to winter time on 25 October 2026.
        let fires = ReminderPlan.fireDates(after: date(23, 12), minutes: 9 * 60, count: 4, calendar: calendar)
        #expect(fires.map { calendar.component(.hour, from: $0) } == [9, 9, 9, 9])
        #expect(fires.count == 4)
    }

    @Test func theReminderNamesTheStreakItKeeps() {
        let text = ReminderPlan.content([("B1", 23), ("A1–A2", 60), ("C1", 0)], streak: 12)
        #expect(text?.title == "Keep your 12-day streak")
        #expect(text?.body == "≈ 2 min is enough.")
        #expect(ReminderPlan.content([("B1", 23)], streak: 0)?.title == "Time to study")
    }

    @Test func noReminderWhenNothingIsDue() {
        #expect(ReminderPlan.content([("B1", 0), ("A1–A2", 0)], streak: 5) == nil)
        #expect(ReminderPlan.content([], streak: 5) == nil)
    }

    /// The icon counts what is left to close the ring, never a backlog of hundreds.
    @Test func theBadgeCountsTheCardsLeftToTheRing() {
        let open = DailyProgress(ring: DailyRing(done: 10, goal: 30), streak: Streak(days: 3, repairCards: nil))
        #expect(ReminderPlan.badge(due: 480, progress: open) == 20)
        let closed = DailyProgress(ring: DailyRing(done: 30, goal: 30), streak: Streak(days: 3, repairCards: nil))
        #expect(ReminderPlan.badge(due: 450, progress: closed) == 0)
        #expect(ReminderPlan.badge(due: 7, progress: open) == 7)
        #expect(ReminderPlan.badge(due: 12, progress: nil) == 12)
    }
}
