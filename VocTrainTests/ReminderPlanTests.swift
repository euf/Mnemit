import Foundation
import Testing

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

    @Test func theBodyNamesEachDeckWithCardsDue() {
        let body = ReminderPlan.body([("B1", 23), ("A1–A2", 60), ("C1", 0)])
        #expect(body == "B1: 23 · A1–A2: 60")
    }

    @Test func theBodyIsNilWhenNothingIsDue() {
        #expect(ReminderPlan.body([("B1", 0), ("A1–A2", 0)]) == nil)
        #expect(ReminderPlan.body([]) == nil)
    }
}
