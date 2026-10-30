import Foundation
import Testing
import UserNotifications
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
        #expect(text?.body == "≈ 2 min")
        #expect(ReminderPlan.content([("B1", 23)], streak: 0)?.title == "Start your streak")
    }

    @Test func theReminderPricesTheStreakStepByThePlanOfItsDay() {
        // Five cards at 10 s are the whole day: less than a minute, not the two minutes of a long plan.
        #expect(ReminderPlan.content([("B1", 5)], streak: 12, secondsPerCard: 10)?.body == "< 1 min")
        #expect(ReminderPlan.content([("B1", 300)], streak: 12, secondsPerCard: 10)?.body == "≈ 2 min")
        // Three cards at 50 s reach the two minutes, as the app's step does: 150 s.
        #expect(ReminderPlan.content([("B1", 100)], streak: 12, secondsPerCard: 50)?.body == "≈ 3 min")
        // Without a price the step is the constant two minutes.
        #expect(ReminderPlan.content([("B1", 5)], streak: 12)?.body == "≈ 2 min")
    }

    @Test func aDailyReminderNamesTheStreakOnlyWhileItStillStandsThatDay() {
        // 09:00 has passed, the first daily reminder is tomorrow and the one after is two study days ahead.
        let now = date(21, 12)
        func named(_ day: Int, kept: Bool) -> Int {
            ReminderPlan.streakNamed(at: date(day, 9), now: now, streak: 12, isKeptToday: kept, studyCalendar: studyCalendar)
        }
        // Today's step is open and the learner stays away: tomorrow still has the streak, the day after has none.
        #expect(named(22, kept: false) == 12)
        #expect(named(23, kept: false) == 0)
        // Today's step is done: one missed day more is held.
        #expect(named(23, kept: true) == 12)
        #expect(named(24, kept: true) == 0)
    }

    @Test func noReminderWhenNothingIsDue() {
        #expect(ReminderPlan.content([("B1", 0), ("A1–A2", 0)], streak: 5) == nil)
        #expect(ReminderPlan.content([], streak: 5) == nil)
    }

    // MARK: The evening reminder

    private var studyCalendar: StudyCalendar { StudyCalendar(timeZone: calendar.timeZone, rolloverHour: 4) }

    /// The evening reminders for `count` days from `now`, each day holding 23 cards.
    private func evenings(now: Date, streak: Int, isKept: Bool, count: Int = 4, cards: Int = 23) -> [Date] {
        let fires = ReminderPlan.streakFireDates(after: now, firstMinutes: 9 * 60, count: count, calendar: calendar)
        let days = Array(repeating: [(name: "B1", total: cards)], count: fires.count)
        return ReminderPlan.streakReminders(at: fires, days: days, now: now, streak: streak, isKeptToday: isKept, studyCalendar: studyCalendar).map(\.fire)
    }

    @Test func theEveningReminderIsAt21AndNeverAfterALateFirstOne() {
        let now = date(21, 12)
        #expect(ReminderPlan.streakFireDates(after: now, firstMinutes: 9 * 60, count: 3, calendar: calendar) == [date(21, 21), date(22, 21), date(23, 21)])
        // Past 21:00 the first one is tomorrow's.
        #expect(ReminderPlan.streakFireDates(after: date(21, 21, 30), firstMinutes: 9 * 60, count: 2, calendar: calendar) == [date(22, 21), date(23, 21)])
        // The first reminder at or after 21:00 leaves no second one; a minute before it, there is one.
        #expect(ReminderPlan.streakFireDates(after: now, firstMinutes: 21 * 60, calendar: calendar).isEmpty)
        #expect(ReminderPlan.streakFireDates(after: now, firstMinutes: 22 * 60 + 30, calendar: calendar).isEmpty)
        #expect(!ReminderPlan.streakFireDates(after: now, firstMinutes: 20 * 60 + 59, calendar: calendar).isEmpty)
    }

    @Test func theEveningReminderSaysWhatTheFirstOneSays() {
        let now = date(21, 12)
        let fires = ReminderPlan.streakFireDates(after: now, firstMinutes: 9 * 60, count: 1, calendar: calendar)
        let reminders = ReminderPlan.streakReminders(
            at: fires, days: [[(name: "B1", total: 23)]], now: now, streak: 12, isKeptToday: false, studyCalendar: studyCalendar)
        #expect(reminders.map(\.fire) == [date(21, 21)])
        #expect(reminders.first?.title == "Keep your 12-day streak")
        #expect(reminders.first?.body == "≈ 2 min")
    }

    @Test func aStreakAtStakeGetsTheEveningReminder() {
        // Today's step not done: tonight and the next days, as far as the streak reaches. It holds through one missed
        // day, so tonight's miss still leaves tomorrow's.
        #expect(evenings(now: date(21, 12), streak: 12, isKept: false) == [date(21, 21), date(22, 21)])
    }

    @Test func noEveningReminderOnceTheStreakStepIsDone() {
        // Done today: tonight's goes; tomorrow's, and the day after's that a missed tomorrow would put at risk, stay.
        #expect(evenings(now: date(21, 12), streak: 12, isKept: true) == [date(22, 21), date(23, 21)])
        // Done today and it is past 21:00 already: nothing for today in any case.
        #expect(evenings(now: date(21, 21, 30), streak: 12, isKept: true, count: 1) == [date(22, 21)])
    }

    @Test func noEveningReminderWithoutAStreakOrCards() {
        #expect(evenings(now: date(21, 12), streak: 0, isKept: false).isEmpty)
        // A day with nothing due asks nothing, and its streak step is done by itself.
        #expect(evenings(now: date(21, 12), streak: 12, isKept: false, cards: 0).isEmpty)
    }

    /// The icon says "1" while the ring is open, never a count of cards.
    @Test func theBadgeIsOneWhileTheRingIsOpen() {
        let open = DailyProgress(ring: DailyRing(done: 10, goal: 30), streak: Streak(days: 3, repairCards: nil), cardsLeft: 480)
        #expect(ReminderPlan.badge(due: 480, progress: open) == 1)
        let closed = DailyProgress(ring: DailyRing(done: 30, goal: 30), streak: Streak(days: 3, repairCards: nil), cardsLeft: 450)
        #expect(ReminderPlan.badge(due: 450, progress: closed) == 0, "a backlog after the ring is no reason for the icon")
        #expect(ReminderPlan.badge(due: 12, progress: nil) == 1)
        #expect(ReminderPlan.badge(due: 0, progress: nil) == 0)
    }
}

/// A tap on a reminder is the widget's tap: Study starts at once.
struct ReminderTapTests {
    @Test func onlyAnOpenedReminderStartsStudy() {
        let info = ReminderTapDelegate.userInfo
        #expect(ReminderTapDelegate.isStudyTap(actionIdentifier: UNNotificationDefaultActionIdentifier, userInfo: info))
        #expect(!ReminderTapDelegate.isStudyTap(actionIdentifier: UNNotificationDismissActionIdentifier, userInfo: info))
        #expect(!ReminderTapDelegate.isStudyTap(actionIdentifier: UNNotificationDefaultActionIdentifier, userInfo: [:]))
    }

    @MainActor @Test func aTapIsCounted() {
        let taps = ReminderTaps()
        taps.tapped()
        taps.tapped()
        #expect(taps.count == 2)
    }
}
